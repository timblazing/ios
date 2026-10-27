import importlib.util
from pathlib import Path
import unittest
from urllib.parse import urlencode
import base64
import contextlib
import hashlib
import http.client
import json
import struct
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit



spec = importlib.util.spec_from_file_location('gateway', Path(__file__).resolve().parents[1] / 'lan-gateway.py')
gateway = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gateway)


class Routes(unittest.TestCase):
    def test_only_read_endpoints(self):
        for path in ['/.well-known/t3/environment', '/api/orchestration/shell', '/api/orchestration/threads/abc-123/bounded']:
            self.assertTrue(gateway.allowed('GET', path))
        for path in ['/api/orchestration/command', '/oauth/token', '/api/orchestration/threads/../bounded', '/api/orchestration/shell?token=abc']:
            self.assertFalse(gateway.allowed('GET', path))
        self.assertFalse(gateway.allowed('POST', '/api/orchestration/shell'))

    def test_pairing_scope_cannot_escalate(self):
        form = dict(grant_type='urn:ietf:params:oauth:grant-type:token-exchange', subject_token='test-code',
                    subject_token_type='urn:t3:params:oauth:token-type:environment-bootstrap',
                    requested_token_type='urn:ietf:params:oauth:token-type:access_token', scope='orchestration:read')
        self.assertTrue(gateway.allowed('POST', '/oauth/token', urlencode(form).encode()))
        form['scope'] = 'orchestration:operate'
        self.assertFalse(gateway.allowed('POST', '/oauth/token', urlencode(form).encode()))
        form['scope'] = 'orchestration:read'
        self.assertFalse(gateway.allowed('POST', '/oauth/token', urlencode(form).encode() + b'&scope=access%3Awrite'))
        self.assertFalse(gateway.allowed('POST', '/oauth/token', b'\xff'))

@contextlib.contextmanager
def serving(handler, **attributes):
    server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
    server.daemon_threads = True
    for key, value in attributes.items():
        setattr(server, key, value)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(2)


def frame(payload, opcode=1, fin=True):
    data = json.dumps(payload).encode() if not isinstance(payload, bytes) else payload
    first = (128 if fin else 0) | opcode
    if len(data) < 126:
        return bytes([first, len(data)]) + data
    return bytes([first, 126]) + struct.pack('!H', len(data)) + data


def client_frame(stream):
    first, second = gateway.read_exact(stream, 2)
    if not second & 128:
        raise AssertionError('Client frames must be masked')
    length = second & 127
    if length == 126:
        length = struct.unpack('!H', gateway.read_exact(stream, 2))[0]
    elif length == 127:
        length = struct.unpack('!Q', gateway.read_exact(stream, 8))[0]
    mask = gateway.read_exact(stream, 4)
    data = gateway.read_exact(stream, length)
    return first & 15, bytes(value ^ mask[i % 4] for i, value in enumerate(data))


class MockHost(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def do_GET(self):
        self.connection.settimeout(2)
        if self.path == '/api/projects':
            self.send_response(200)
            payload = b'{"projects":[]}'
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.headers.get('Authorization') != 'Bearer test-session':
            self.send_response(401)
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        key = self.headers.get('Sec-WebSocket-Key')
        self.send_response(101)
        self.send_header('Upgrade', 'websocket')
        self.send_header('Connection', 'Upgrade')
        accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        self.send_header('Sec-WebSocket-Accept', accept)
        self.end_headers()
        _, data = client_frame(self.rfile)
        message = json.loads(data)
        self.server.messages.append((self.path, message))
        mode = getattr(self.server, 'mode', '')
        if mode == 'close':
            self.close_connection = True
            return
        if mode == 'oversize':
            self.wfile.write(bytes([129, 127]) + struct.pack('!Q', gateway.MAX_RESPONSE + 1))
            self.wfile.flush()
            self.close_connection = True
            return
        if mode == 'reject':
            response = {'_tag': 'Exit', 'requestId': '1', 'exit': {'_tag': 'Failure', 'cause': [
                {'_tag': 'Fail', 'error': {'_tag': 'EnvironmentAuthorizationError', 'message': 'private-secret'}}]}}
        else:
            value = self.server.value
            response = {'_tag': 'Exit', 'requestId': '1', 'exit': {'_tag': 'Success', 'value': value}}
        # Ping between fragmented data messages is legal and must not damage the data.
        encoded = json.dumps([response]).encode()
        half = len(encoded) // 2
        self.wfile.write(frame(encoded[:half], fin=False) + frame(b'ping', 9) + frame(encoded[half:], 0))
        self.wfile.flush()
        _, pong = client_frame(self.rfile)
        self.server.pong = pong
        self.close_connection = True


class Bridge(unittest.TestCase):
    def command(self):
        return {'type': 'thread.stop', 'commandId': 'cmd-123', 'threadId': 'thread-123'}

    def test_chat_opt_in_and_command_allowlist(self):
        encoded = json.dumps(self.command()).encode()
        self.assertFalse(gateway.allowed('POST', '/t3-chat/command', encoded))
        self.assertTrue(gateway.allowed('POST', '/t3-chat/command', encoded, True))
        self.assertFalse(gateway.allowed('POST', '/t3-chat/command', b'[]', True))
        for kind in ['thread.delete', 'thread.archive', 'project.mutate', 'terminal.write']:
            command = dict(self.command(), type=kind)
            self.assertFalse(gateway.allowed('POST', '/t3-chat/command', json.dumps(command).encode(), True))
        self.assertFalse(gateway.valid_command(dict(self.command(), unexpected='value')))
        self.assertFalse(gateway.valid_command(dict(self.command(), threadId='../secret')))

    def test_pairing_chat_scopes_only(self):
        form = dict(grant_type='urn:ietf:params:oauth:grant-type:token-exchange', subject_token='test-code',
                    subject_token_type='urn:t3:params:oauth:token-type:environment-bootstrap',
                    requested_token_type='urn:ietf:params:oauth:token-type:access_token',
                    scope='orchestration:read orchestration:operate')
        self.assertTrue(gateway.allowed('POST', '/oauth/token', urlencode(form).encode(), True))
        self.assertFalse(gateway.allowed('POST', '/oauth/token', urlencode(form).encode()))
        for scope in ['orchestration:read access:write', 'orchestration:operate', 'orchestration:read orchestration:read']:
            self.assertFalse(gateway.allowed('POST', '/oauth/token', urlencode(dict(form, scope=scope)).encode(), True))

    def test_websocket_roundtrip_and_fragmentation(self):
        with serving(MockHost, messages=[], value={'accepted': True}) as host:
            result = gateway.websocket_rpc(urlsplit('http://127.0.0.1:%d' % host.server_port),
                                           'Bearer test-session', 'orchestration.dispatchCommand', self.command())
            self.assertEqual(result, {'accepted': True})
            path, message = host.messages[0]
            self.assertEqual(path, '/ws?orchestrationProtocol=2')
            self.assertEqual(message, {'_tag': 'Request', 'id': '1', 'tag': 'orchestration.dispatchCommand',
                                       'payload': self.command(), 'headers': []})

    def test_auth_and_uncertain_delivery_never_retried(self):
        for mode, expected in [('reject', 403), ('close', 409), ('oversize', 409)]:
            with serving(MockHost, messages=[], value={}, mode=mode) as host:
                with self.assertRaises(gateway.BridgeError) as error:
                    gateway.websocket_rpc(urlsplit('http://127.0.0.1:%d' % host.server_port),
                                          'Bearer test-session', 'orchestration.dispatchCommand', self.command())
                self.assertEqual(error.exception.status, expected)
                self.assertNotIn('private-secret', error.exception.message)
                self.assertEqual(len(host.messages), 1)
        with serving(MockHost, messages=[], value={}) as host:
            with self.assertRaises(gateway.BridgeError) as error:
                gateway.websocket_rpc(urlsplit('http://127.0.0.1:%d' % host.server_port),
                                      'Bearer invalid', 'orchestration.dispatchCommand', self.command())
            self.assertEqual(error.exception.status, 401)
            self.assertEqual(host.messages, [])

    def request(self, server, method, path, body=None, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', server.server_port, timeout=3)
        connection.request(method, path, body, headers or {})
        response = connection.getresponse()
        result = response.status, response.read()
        connection.close()
        return result

    def test_http_gateway_and_catalog_privacy(self):
        value = {'cwd': '/private/path', 'auth': {'token': 'secret'}, 'providers': [
            {'instanceId': 'codex', 'driver': 'codex', 'enabled': True, 'installed': True, 'status': 'ready',
             'auth': {'email': 'private@example.com'}, 'models': [{'slug': 'model-a', 'name': 'Model A'}]}]}
        with serving(MockHost, messages=[], value=value) as host:
            upstream = urlsplit('http://127.0.0.1:%d' % host.server_port)
            with serving(gateway.Gateway, upstream=upstream, allow_chat=True) as proxy:
                headers = {'Authorization': 'Bearer test-session', 'x-t3-orchestration-protocol': '2',
                           'Content-Type': 'application/json'}
                status, data = self.request(proxy, 'GET', '/t3-chat/config', headers=headers)
                self.assertEqual(status, 200)
                catalog = json.loads(data)
                self.assertEqual(catalog['providers'][0]['models'][0]['id'], 'model-a')
                for private in ['secret', 'private/path', 'private@example.com']:
                    self.assertNotIn(private, data.decode())
                self.assertEqual(self.request(proxy, 'GET', '/api/projects')[0], 200)
                self.assertEqual(self.request(proxy, 'GET', '/t3-chat/config')[0], 401)
                self.assertEqual(self.request(proxy, 'GET', '/t3-chat/config', headers={'Authorization': 'Bearer test-session'})[0], 426)
                self.assertEqual(self.request(proxy, 'POST', '/t3-chat/command', json.dumps(self.command()), dict(headers, **{'Content-Type': 'text/plain'}))[0], 415)
                self.assertEqual(self.request(proxy, 'POST', '/t3-chat/command', json.dumps(self.command()), headers)[0], 200)
                self.assertEqual(self.request(proxy, 'GET', '/api/projects?token=secret')[0], 403)
                self.assertEqual(self.request(proxy, 'POST', '/t3-chat/command', b'x' * (gateway.MAX_REQUEST + 1), headers)[0], 413)
                self.assertEqual(len(host.messages), 2)


if __name__ == '__main__':
    unittest.main()
