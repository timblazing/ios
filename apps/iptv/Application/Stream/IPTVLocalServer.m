#import "IPTVLocalServer.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

@implementation IPTVLocalServer {
    IPTVSegmenter *_segmenter;
    dispatch_queue_t _queue;
    dispatch_source_t _source;
}

- (instancetype)initWithSegmenter:(IPTVSegmenter *)segmenter {
    if ((self = [super init])) _segmenter = segmenter;
    return self;
}

- (BOOL)start:(NSError **)error {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr;
    socklen_t addrLen = sizeof addr;
    int one = 1;
    if (fd >= 0) {
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
        memset(&addr, 0, sizeof addr);
        addr.sin_len = sizeof addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = 0;
    }
    if (fd < 0 || bind(fd, (struct sockaddr *)&addr, sizeof addr) != 0 || listen(fd, 16) != 0 ||
        getsockname(fd, (struct sockaddr *)&addr, &addrLen) != 0) {
        int code = errno;
        if (fd >= 0) close(fd);
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
        return NO;
    }
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
    _port = ntohs(addr.sin_port);
    _queue = dispatch_queue_create("com.local.iptv.server", DISPATCH_QUEUE_SERIAL);
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, _queue);
    dispatch_source_set_event_handler(_source, ^{
        for (;;) {
            int client = accept(fd, NULL, NULL);
            if (client < 0) break;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [self serve:client]; });
        }
    });
    dispatch_source_set_cancel_handler(_source, ^{ close(fd); });
    dispatch_resume(_source);
    return YES;
}

- (void)stop {
    if (_source) dispatch_source_cancel(_source);
    _source = nil;
}

#pragma mark - Connections

static BOOL IPTVSendAll(int fd, const void *bytes, size_t length) {
    const uint8_t *p = bytes;
    while (length) {
        ssize_t n = send(fd, p, length, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return NO;
        p += n;
        length -= (size_t)n;
    }
    return YES;
}

- (void)serve:(int)fd {
    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one);
    struct timeval rcv = {5, 0}, snd = {15, 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &rcv, sizeof rcv);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &snd, sizeof snd);
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);

    char buf[4096];
    size_t used = 0;
    BOOL complete = NO;
    while (used < sizeof buf - 1) {
        ssize_t n = recv(fd, buf + used, sizeof buf - 1 - used, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) break;
        used += (size_t)n;
        buf[used] = 0;
        if (strstr(buf, "\r\n\r\n")) {
            complete = YES;
            break;
        }
    }
    if (complete) [self respondTo:fd request:[NSString stringWithUTF8String:buf]];
    close(fd);
}

- (void)respondTo:(int)fd request:(NSString *)request {
    NSArray<NSString *> *lines = [request componentsSeparatedByString:@"\r\n"];
    NSArray<NSString *> *parts = [lines.firstObject componentsSeparatedByString:@" "];
    if (parts.count < 2 || !([parts[0] isEqualToString:@"GET"] || [parts[0] isEqualToString:@"HEAD"])) {
        [self sendStatus:@"405 Method Not Allowed" type:@"text/plain" body:nil head:NO to:fd];
        return;
    }
    BOOL head = [parts[0] isEqualToString:@"HEAD"];
    NSString *path = [parts[1] componentsSeparatedByString:@"?"].firstObject;
    NSString *range = nil;
    for (NSString *line in lines) {
        if ([line.lowercaseString hasPrefix:@"range:"]) range = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }

    if ([path isEqualToString:@"/live.m3u8"]) {
        NSString *playlist = [_segmenter playlist];
        NSData *body = [playlist dataUsingEncoding:NSUTF8StringEncoding];
        if (!body) [self sendStatus:@"404 Not Found" type:@"text/plain" body:nil head:head to:fd];
        else [self sendStatus:@"200 OK" type:@"application/vnd.apple.mpegurl" body:body head:head to:fd];
        return;
    }
    if ([path hasPrefix:@"/seg/"] && [path hasSuffix:@".ts"]) {
        NSString *number = [path substringWithRange:NSMakeRange(5, path.length - 8)];
        NSScanner *scanner = [NSScanner scannerWithString:number];
        long long sequence;
        IPTVSegment *segment = ([scanner scanLongLong:&sequence] && scanner.atEnd && sequence >= 0) ? [_segmenter segmentWithSequence:(uint64_t)sequence] : nil;
        if (!segment) {
            [self sendStatus:@"404 Not Found" type:@"text/plain" body:nil head:head to:fd];
            return;
        }
        [self sendSegment:segment.data range:range head:head to:fd];
        return;
    }
    [self sendStatus:@"404 Not Found" type:@"text/plain" body:nil head:head to:fd];
}

- (void)sendStatus:(NSString *)status type:(NSString *)type body:(NSData *)body head:(BOOL)head to:(int)fd {
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\n"
                                                   "Cache-Control: no-cache\r\nConnection: close\r\n\r\n",
                                                  status, type, (unsigned long)body.length];
    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
    if (!IPTVSendAll(fd, headerData.bytes, headerData.length)) return;
    if (!head && body.length) IPTVSendAll(fd, body.bytes, body.length);
}

// Whole-body responses, plus a single "bytes=a-b" range because AVFoundation sometimes probes with one.
- (void)sendSegment:(NSData *)data range:(NSString *)range head:(BOOL)head to:(int)fd {
    NSUInteger length = data.length, first = 0, last = length - 1;
    BOOL partial = NO;
    if ([range hasPrefix:@"bytes="]) {
        NSArray<NSString *> *bounds = [[range substringFromIndex:6] componentsSeparatedByString:@"-"];
        if (bounds.count == 2) {
            if (bounds[0].length) {
                first = (NSUInteger)bounds[0].longLongValue;
                if (bounds[1].length) last = MIN(last, (NSUInteger)bounds[1].longLongValue);
            } else if (bounds[1].length) {
                NSUInteger suffix = (NSUInteger)bounds[1].longLongValue;
                first = suffix >= length ? 0 : length - suffix;
            }
            partial = YES;
        }
    }
    if (partial && first > last) {
        NSString *h = [NSString stringWithFormat:@"HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */%lu\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", (unsigned long)length];
        NSData *hd = [h dataUsingEncoding:NSUTF8StringEncoding];
        IPTVSendAll(fd, hd.bytes, hd.length);
        return;
    }
    NSMutableString *header = [NSMutableString stringWithString:partial ? @"HTTP/1.1 206 Partial Content\r\n" : @"HTTP/1.1 200 OK\r\n"];
    [header appendString:@"Content-Type: video/mp2t\r\nAccept-Ranges: bytes\r\nCache-Control: no-cache\r\nConnection: close\r\n"];
    if (partial) [header appendFormat:@"Content-Range: bytes %lu-%lu/%lu\r\n", (unsigned long)first, (unsigned long)last, (unsigned long)length];
    [header appendFormat:@"Content-Length: %lu\r\n\r\n", (unsigned long)(last - first + 1)];
    NSData *hd = [header dataUsingEncoding:NSUTF8StringEncoding];
    if (!IPTVSendAll(fd, hd.bytes, hd.length) || head) return;
    IPTVSendAll(fd, (const uint8_t *)data.bytes + first, last - first + 1);
}
@end
