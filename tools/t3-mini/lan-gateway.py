#!/usr/bin/env python3
"""Trusted-LAN adapter for a loopback T3 Code host; chat is opt-in."""
import argparse
import base64
import hashlib
import http.client
import ipaddress
import json
import os
import re
import socket
import struct
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

MAX_RESPONSE = 8 * 1024 * 1024
MAX_REQUEST = 128 * 1024
TIMEOUT = 20
COMMAND_FIELDS = {
    'thread.create': {'type', 'commandId', 'threadId', 'projectId', 'title', 'modelSelection',
                      'runtimeMode', 'interactionMode', 'branch', 'worktreePath', 'createdBy', 'creationSource'},
    'message.dispatch': {'type', 'commandId', 'threadId', 'messageId', 'text', 'attachments',
                         'modelSelection', 'dispatchMode', 'createdBy', 'creationSource'},
    'thread.stop': {'type', 'commandId', 'threadId', 'reason', 'stopDelegatedTasks'},
    'runtime-request.respond': {'type', 'commandId', 'threadId', 'requestId', 'decision', 'feedback', 'answers'},
    'thread.model-selection.set': {'type', 'commandId', 'threadId', 'modelSelection'},
}


def valid_command(command):
    if not isinstance(command, dict) or command.get('type') not in COMMAND_FIELDS:
        return False
    if set(command) - COMMAND_FIELDS[command['type']]:
        return False
    return all(isinstance(command.get(key), str) and 0 < len(command[key]) <= 200
               and re.fullmatch(r'[A-Za-z0-9_-]+', command[key]) for key in ('commandId', 'threadId'))


def allowed(method, path, body=b'', allow_chat=False):
    if method == 'GET':
        return (path in ('/.well-known/t3/environment', '/api/orchestration/shell')
                or (allow_chat and path in ('/api/projects', '/t3-chat/config'))
                or bool(re.fullmatch(r'/api/orchestration/threads/[A-Za-z0-9_-]+/bounded', path)))
    if method != 'POST':
        return False
    if path == '/t3-chat/command' and allow_chat:
        try:
            return valid_command(json.loads(body))
        except (ValueError, UnicodeDecodeError, TypeError):
            return False
    if path != '/oauth/token':
        return False
    try:
        form = parse_qs(body.decode('utf-8'), strict_parsing=True)
    except (ValueError, UnicodeDecodeError):
        return False
    expected = {
        'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
        'subject_token_type': 'urn:t3:params:oauth:token-type:environment-bootstrap',
        'requested_token_type': 'urn:ietf:params:oauth:token-type:access_token',
    }
    keys = set(expected) | {'scope', 'subject_token', 'client_label', 'client_device_type', 'client_os'}
    scopes = form.get('scope', [''])[0].split()
    permitted = {'orchestration:read', 'orchestration:operate'} if allow_chat else {'orchestration:read'}
    return (set(form) <= keys and all(len(v) == 1 for v in form.values())
            and all(form.get(k) == [v] for k, v in expected.items())
            and bool(scopes) and len(scopes) == len(set(scopes)) and set(scopes) <= permitted
            and 'orchestration:read' in scopes and bool(form.get('subject_token', [''])[0]))


class BridgeError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def read_exact(stream, count):
    data = stream.read(count)
    if len(data) != count:
        raise OSError('WebSocket ended')
    return data


def send_frame(sock, payload, opcode=1):
    mask = os.urandom(4)
    length = len(payload)
    header = bytes([0x80 | opcode])
    if length < 126:
        header += bytes([0x80 | length])
    elif length <= 65535:
        header += bytes([0xfe]) + struct.pack('!H', length)
    else:
        header += bytes([0xff]) + struct.pack('!Q', length)
    sock.sendall(header + mask + bytes(value ^ mask[i % 4] for i, value in enumerate(payload)))


def websocket_rpc(upstream, authorization, tag, payload):
    """One bounded Effect JSON RPC per socket. Never replay an uncertain write."""
    command = tag == 'orchestration.dispatchCommand'
    sent = False
    sock = None
    response = None
    deadline = time.monotonic() + TIMEOUT
    try:
        sock = socket.create_connection((upstream.hostname, upstream.port or 80), TIMEOUT)
        key = base64.b64encode(os.urandom(16)).decode('ascii')
        host = upstream.netloc
        handshake = ('GET /ws?orchestrationProtocol=2 HTTP/1.1\r\nHost: %s\r\n'
                     'Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\n'
                     'Sec-WebSocket-Version: 13\r\nAuthorization: %s\r\n\r\n') % (host, key, authorization)
        sock.sendall(handshake.encode('ascii'))
        response = http.client.HTTPResponse(sock)
        response.begin()
        if response.status in (401, 403):
            raise BridgeError(response.status, 'Access denied. Pair with conversation read and operate access.')
        accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        if (response.status != 101 or response.getheader('Sec-WebSocket-Accept') != accept
                or response.getheader('Upgrade', '').lower() != 'websocket'
                or 'upgrade' not in response.getheader('Connection', '').lower()):
            raise BridgeError(502, 'Host WebSocket protocol is unavailable.')
        envelope = {'_tag': 'Request', 'id': '1', 'tag': tag, 'payload': payload, 'headers': []}
        # Mark uncertain before sending: even sendall failure may have delivered bytes.
        sent = True
        send_frame(sock, json.dumps(envelope, separators=(',', ':')).encode())
        fragments = bytearray()
        fragmented = False
        received = 0
        for _ in range(1024):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError()
            sock.settimeout(remaining)
            first, second = read_exact(response.fp, 2)
            fin, opcode = bool(first & 0x80), first & 15
            if first & 0x70 or second & 0x80:
                raise OSError('Unsupported WebSocket frame')
            length = second & 127
            if length == 126:
                length = struct.unpack('!H', read_exact(response.fp, 2))[0]
            elif length == 127:
                length = struct.unpack('!Q', read_exact(response.fp, 8))[0]
            received += length
            if length > MAX_RESPONSE or received > MAX_RESPONSE:
                raise OSError('WebSocket response too large')
            if opcode >= 8 and (not fin or length > 125):
                raise OSError('Invalid WebSocket control frame')
            frame = read_exact(response.fp, length)
            if opcode == 8:
                raise OSError('WebSocket closed')
            if opcode == 9:
                send_frame(sock, frame, 10)
                continue
            if opcode == 10:
                continue
            if opcode == 1 and not fragmented:
                fragments = bytearray(frame)
            elif opcode == 0 and fragmented:
                fragments.extend(frame)
            else:
                raise OSError('Unsupported WebSocket message')
            fragmented = not fin
            if fragmented:
                continue
            decoded = json.loads(fragments.decode('utf-8'))
            for message in decoded if isinstance(decoded, list) else [decoded]:
                if not isinstance(message, dict):
                    continue
                if message.get('_tag') == 'Ping':
                    send_frame(sock, b'{"_tag":"Pong"}')
                if message.get('_tag') != 'Exit' or str(message.get('requestId')) != '1':
                    continue
                exit_value = message.get('exit', {})
                if exit_value.get('_tag') == 'Success':
                    return exit_value.get('value')
                # Never pass remote errors, commands, paths, or credentials back to the web UI.
                cause = exit_value.get('cause', [])
                if any(isinstance(c, dict) and isinstance(c.get('error'), dict)
                       and c['error'].get('_tag') == 'EnvironmentAuthorizationError' for c in cause):
                    raise BridgeError(403, 'Access denied. Pair with conversation read and operate access.')
                raise BridgeError(422, 'Host rejected the operation. Refresh and check the conversation and model.')
        raise OSError('WebSocket frame limit')
    except BridgeError:
        raise
    except (OSError, ValueError, UnicodeError, http.client.HTTPException, TypeError, AttributeError):
        if command and sent:
            raise BridgeError(409, 'Delivery uncertain. Refresh first; retry only the same operation ID.') from None
        raise BridgeError(502, 'T3 host unavailable or incompatible.') from None
    finally:
        if response:
            response.close()
        if sock:
            sock.close()


def provider_catalog(config):
    """Expose only routing/model metadata, never config paths, identities, or auth."""
    providers = []
    for provider in config.get('providers', [])[:100]:
        if not isinstance(provider, dict):
            continue
        models = []
        for model in provider.get('models', [])[:500]:
            if isinstance(model, dict) and isinstance(model.get('slug'), str):
                models.append({'id': model['slug'], 'label': model.get('name', model['slug']),
                               'isDefault': bool(model.get('isDefault'))})
        providers.append({'instanceId': provider.get('instanceId'), 'driver': provider.get('driver'),
                          'title': provider.get('displayName', provider.get('driver', 'Provider')),
                          'state': provider.get('status'), 'enabled': bool(provider.get('enabled')),
                          'installed': bool(provider.get('installed')), 'models': models,
                          'requiresNewThreadForModelChange': bool(provider.get('requiresNewThreadForModelChange')),
                          'supportedRuntimeModes': provider.get('supportedRuntimeModes', ['approval-required'])})
    return {'providers': providers}


class Gateway(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_args):
        pass  # Pairing credentials and conversation URLs must not enter access logs.

    def do_GET(self):
        self.forward()

    def do_POST(self):
        self.forward()

    def reply(self, code, payload):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def forward(self):
        self.connection.settimeout(TIMEOUT)
        try:
            lengths = self.headers.get_all('Content-Length', [])
            length = int(lengths[0]) if lengths else 0
        except ValueError:
            return self.reply(400, b'{"error":"invalid request"}')
        if len(lengths) > 1 or length < 0 or length > MAX_REQUEST or self.headers.get('Transfer-Encoding'):
            self.close_connection = True
            return self.reply(413, b'{"error":"unsupported request body"}')
        if self.command == 'GET' and length:
            self.close_connection = True
            return self.reply(400, b'{"error":"unexpected request body"}')
        try:
            body = read_exact(self.rfile, length)
        except OSError:
            self.close_connection = True
            return
        chat = getattr(self.server, 'allow_chat', False)
        if not allowed(self.command, self.path, body, chat):
            return self.reply(403, b'{"error":"endpoint or operation is not allowed"}')
        if self.path.startswith('/t3-chat/'):
            authorization = self.headers.get('Authorization', '')
            if (not authorization.startswith('Bearer ') or len(authorization) > 8192
                    or re.search(r'[^\x20-\x7e]', authorization)):
                return self.reply(401, b'{"error":"bearer session required"}')
            if self.headers.get('x-t3-orchestration-protocol') != '2':
                return self.reply(426, b'{"error":"orchestration protocol 2 required"}')
            try:
                if self.path == '/t3-chat/config':
                    result = provider_catalog(websocket_rpc(self.server.upstream, authorization, 'server.getConfig', {}))
                else:
                    if self.headers.get_content_type() != 'application/json':
                        return self.reply(415, b'{"error":"JSON body required"}')
                    result = {'result': websocket_rpc(self.server.upstream, authorization,
                                                     'orchestration.dispatchCommand', json.loads(body))}
                encoded = json.dumps(result).encode()
                if len(encoded) > MAX_RESPONSE:
                    raise BridgeError(502, 'Host response too large.')
                return self.reply(200, encoded)
            except BridgeError as error:
                return self.reply(error.status, json.dumps({'error': error.message}).encode())
            except (ValueError, TypeError, AttributeError):
                return self.reply(502, b'{"error":"unsupported host response"}')
        headers = {key: self.headers[key] for key in
                   ('Authorization', 'Content-Type', 'x-t3-orchestration-protocol') if key in self.headers}
        upstream = http.client.HTTPConnection(self.server.upstream.hostname,
                                              self.server.upstream.port or 80, timeout=TIMEOUT)
        try:
            upstream.request(self.command, self.path, body=body or None, headers=headers)
            response = upstream.getresponse()
            payload = response.read(MAX_RESPONSE + 1)
            if len(payload) > MAX_RESPONSE:
                return self.reply(502, b'{"error":"host response too large"}')
            self.reply(response.status, payload)
        except (OSError, http.client.HTTPException):
            self.reply(502, b'{"error":"T3 host unavailable"}')
        finally:
            upstream.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--listen', required=True, help='This Mac\'s private LAN IPv4 address')
    parser.add_argument('--port', type=int, default=3774)
    parser.add_argument('--upstream', default='http://127.0.0.1:3773')
    parser.add_argument('--allow-chat', action='store_true', help='Enable narrow chat RPC and read/operate pairing')
    args = parser.parse_args()
    listen = ipaddress.ip_address(args.listen)
    upstream = urlsplit(args.upstream)
    if listen.version != 4 or not listen.is_private or listen.is_unspecified:
        parser.error('--listen must be an explicit private IPv4 address')
    if (upstream.scheme != 'http' or upstream.hostname not in ('127.0.0.1', 'localhost', '::1')
            or upstream.path not in ('', '/') or upstream.username or upstream.password
            or upstream.query or upstream.fragment):
        parser.error('--upstream must be a loopback HTTP origin')
    server = ThreadingHTTPServer((args.listen, args.port), Gateway)
    server.daemon_threads = True
    server.upstream = upstream
    server.allow_chat = args.allow_chat
    print('T3 LAN adapter (%s) listening on http://%s:%s' %
          ('chat enabled' if args.allow_chat else 'read only', args.listen, args.port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
