#import "IPTVSegmenter.h"

enum { IPTVTSPacket = 188 };
static const uint64_t IPTVPTSMask = (1ULL << 33) - 1;
static const double IPTVPTSRate = 90000.0;
// A stream that never produces an IDR must not grow the buffer without bound (1 GB device).
static const NSUInteger IPTVMaxSegmentBytes = 24 * 1024 * 1024;

@interface IPTVSegment ()
- (instancetype)initWithSequence:(uint64_t)sequence data:(NSData *)data duration:(double)duration discontinuity:(BOOL)discontinuity;
@end

@implementation IPTVSegment
- (instancetype)initWithSequence:(uint64_t)sequence data:(NSData *)data duration:(double)duration discontinuity:(BOOL)discontinuity {
    if ((self = [super init])) {
        _sequence = sequence;
        _data = data;
        _duration = duration;
        _discontinuity = discontinuity;
    }
    return self;
}
@end

static NSString *IPTVVideoCodecName(int streamType) {
    switch (streamType) {
    case 0x24: return @"HEVC (H.265)";
    case 0x01:
    case 0x02: return @"MPEG-2";
    case 0x10: return @"MPEG-4 Part 2";
    case 0x42: return @"AVS";
    case 0xEA: return @"VC-1";
    default: return [NSString stringWithFormat:@"stream type 0x%02X", streamType];
    }
}

@implementation IPTVSegmenter {
    NSMutableData *_carry;
    BOOL _synced;
    // Program tables
    int _pmtPID, _videoPID, _audioPID;
    NSData *_pat, *_pmt;
    // Segment under construction. _current always begins with PAT+PMT once _active.
    NSMutableData *_current;
    BOOL _active;
    uint64_t _segStartPTS;
    // The most recent video access unit (PES): where it starts in _current and whether it is an IDR.
    NSUInteger _auStart;
    uint64_t _auPTS;
    BOOL _scanning;
    int _scanOffset; // where H.264 data starts in the access unit's first packet
    int _zeros;
    BOOL _expectNAL;
    BOOL _nextDiscontinuity;
    // Published window
    NSLock *_lock;
    NSMutableArray<IPTVSegment *> *_window;
    uint64_t _nextSequence, _discontinuitySequence;
}

- (instancetype)init {
    if ((self = [super init])) {
        _targetDuration = 2.0;
        _windowSize = 8;
        _carry = [NSMutableData data];
        _current = [NSMutableData data];
        _lock = [NSLock new];
        _window = [NSMutableArray array];
        _pmtPID = _videoPID = _audioPID = -1;
    }
    return self;
}

#pragma mark - Public

- (NSUInteger)segmentCount {
    [_lock lock];
    NSUInteger n = _window.count;
    [_lock unlock];
    return n;
}

- (uint64_t)producedCount {
    [_lock lock];
    uint64_t n = _nextSequence;
    [_lock unlock];
    return n;
}

- (void)feed:(NSData *)data {
    [_carry appendData:data];
    const uint8_t *buf = _carry.bytes;
    NSUInteger len = _carry.length, pos = 0;
    while (pos + IPTVTSPacket <= len) {
        if (buf[pos] != 0x47) {
            pos++;
            _synced = NO;
            continue;
        }
        // Confirm sync with the next packet's marker so a stray 0x47 inside payload is not taken for a packet.
        if (pos + IPTVTSPacket < len) {
            if (buf[pos + IPTVTSPacket] != 0x47) {
                pos++;
                _synced = NO;
                continue;
            }
        } else if (!_synced) {
            break;
        }
        _synced = YES;
        [self processPacket:buf + pos];
        pos += IPTVTSPacket;
    }
    if (pos) [_carry replaceBytesInRange:NSMakeRange(0, pos) withBytes:NULL length:0];
}

- (void)markDiscontinuity {
    [_carry setLength:0];
    _synced = NO;
    [self resetSegment];
    [_lock lock];
    _nextDiscontinuity = _nextSequence > 0;
    [_lock unlock];
}

- (NSString *)playlist {
    [_lock lock];
    NSArray<IPTVSegment *> *window = [_window copy];
    uint64_t disc = _discontinuitySequence;
    [_lock unlock];
    if (!window.count) return nil;
    double longest = 1;
    for (IPTVSegment *s in window) longest = MAX(longest, s.duration);
    NSMutableString *out = [NSMutableString stringWithString:@"#EXTM3U\n#EXT-X-VERSION:3\n"];
    [out appendFormat:@"#EXT-X-TARGETDURATION:%d\n#EXT-X-MEDIA-SEQUENCE:%llu\n", (int)ceil(longest), window.firstObject.sequence];
    if (disc) [out appendFormat:@"#EXT-X-DISCONTINUITY-SEQUENCE:%llu\n", disc];
    for (IPTVSegment *s in window) {
        if (s.discontinuity) [out appendString:@"#EXT-X-DISCONTINUITY\n"];
        [out appendFormat:@"#EXTINF:%.3f,\nseg/%llu.ts\n", s.duration, s.sequence];
    }
    return out;
}

- (IPTVSegment *)segmentWithSequence:(uint64_t)sequence {
    IPTVSegment *found = nil;
    [_lock lock];
    for (IPTVSegment *s in _window) {
        if (s.sequence == sequence) {
            found = s;
            break;
        }
    }
    [_lock unlock];
    return found;
}

#pragma mark - Packet parsing

- (void)resetSegment {
    [_current setLength:0];
    _active = NO;
    _scanning = NO;
    _auStart = 0;
}

- (void)processPacket:(const uint8_t *)p {
    int pid = ((p[1] & 0x1F) << 8) | p[2];
    BOOL pusi = (p[1] & 0x40) != 0;
    int afc = (p[3] >> 4) & 3;
    int off = (afc & 2) ? 5 + p[4] : 4;
    BOOL hasPayload = (afc & 1) && off < IPTVTSPacket;
    if (pid == 0x1FFF) return;

    if (pid == 0 && pusi && hasPayload) [self parsePAT:p payloadOffset:off];
    else if (pid == _pmtPID && pusi && hasPayload) [self parsePMT:p payloadOffset:off];

    if (pid == _videoPID && pusi && hasPayload) {
        [self beginAccessUnit:p payloadOffset:off];
        [_current appendBytes:p length:IPTVTSPacket];
        if (_scanning) [self scanPayload:p + _scanOffset length:IPTVTSPacket - _scanOffset];
    } else {
        // Before the first segment starts, only video access units are buffered (non-video bytes are dropped at the
        // next access unit), so wait for the PMT to name a video PID.
        if (!_active && _videoPID < 0) return;
        [_current appendBytes:p length:IPTVTSPacket];
        if (pid == _videoPID && _scanning && hasPayload) [self scanPayload:p + off length:IPTVTSPacket - off];
    }
    if (_current.length > IPTVMaxSegmentBytes) {
        [self resetSegment];
        [_lock lock];
        _nextDiscontinuity = _nextSequence > 0;
        [_lock unlock];
    }
}

- (void)parsePAT:(const uint8_t *)p payloadOffset:(int)off {
    int s = off + 1 + p[off];
    if (s + 8 > IPTVTSPacket || p[s] != 0x00) return;
    int sectionLength = ((p[s + 1] & 0x0F) << 8) | p[s + 2];
    if (s + 3 + sectionLength > IPTVTSPacket) return; // multi-packet PAT: not expected for a single program
    for (int i = s + 8; i + 4 <= s + 3 + sectionLength - 4; i += 4) {
        int program = (p[i] << 8) | p[i + 1];
        if (program == 0) continue;
        int pmtPID = ((p[i + 2] & 0x1F) << 8) | p[i + 3];
        if (pmtPID != _pmtPID) {
            _pmtPID = pmtPID;
            _pmt = nil;
            _videoPID = _audioPID = -1;
        }
        _pat = [NSData dataWithBytes:p length:IPTVTSPacket];
        return;
    }
}

- (void)parsePMT:(const uint8_t *)p payloadOffset:(int)off {
    int s = off + 1 + p[off];
    if (s + 12 > IPTVTSPacket || p[s] != 0x02) return;
    int sectionLength = ((p[s + 1] & 0x0F) << 8) | p[s + 2];
    if (s + 3 + sectionLength > IPTVTSPacket) return;
    int infoLength = ((p[s + 10] & 0x0F) << 8) | p[s + 11];
    int end = s + 3 + sectionLength - 4;
    int video = -1, audio = -1, otherVideo = -1;
    for (int i = s + 12 + infoLength; i + 5 <= end;) {
        int type = p[i];
        int pid = ((p[i + 1] & 0x1F) << 8) | p[i + 2];
        int esLength = ((p[i + 3] & 0x0F) << 8) | p[i + 4];
        if (type == 0x1B && video < 0) video = pid;
        else if ((type == 0x01 || type == 0x02 || type == 0x10 || type == 0x24 || type == 0x42 || type == 0xEA) && otherVideo < 0) otherVideo = type;
        else if ((type == 0x0F || type == 0x11 || type == 0x03 || type == 0x04 || type == 0x81) && audio < 0) audio = pid;
        i += 5 + esLength;
    }
    if (video < 0) {
        if (otherVideo >= 0 && !_unsupportedVideo) _unsupportedVideo = IPTVVideoCodecName(otherVideo);
        return;
    }
    _videoPID = video;
    _audioPID = audio;
    _pmt = [NSData dataWithBytes:p length:IPTVTSPacket];
}

#pragma mark - Access units and cutting

- (void)beginAccessUnit:(const uint8_t *)p payloadOffset:(int)off {
    // Anything buffered before the first segment starts is only useful from this access unit on.
    if (!_active) [_current setLength:0];
    _auStart = _current.length;
    _scanning = NO;
    _zeros = 0;
    _expectNAL = NO;
    if (IPTVTSPacket - off < 14 || p[off] || p[off + 1] || p[off + 2] != 1) return;
    if (!(p[off + 7] & 0x80)) return; // no PTS: cannot time this unit
    const uint8_t *t = p + off + 9;
    _auPTS = ((uint64_t)((t[0] >> 1) & 7) << 30) | ((uint64_t)t[1] << 22) | ((uint64_t)(t[2] >> 1) << 15) |
             ((uint64_t)t[3] << 7) | (uint64_t)(t[4] >> 1);
    int start = off + 9 + p[off + 8];
    _scanOffset = MIN(start, IPTVTSPacket);
    _scanning = YES;
}

// Looks for the first slice NAL of the access unit. Start codes can straddle packets, hence the carried state.
- (void)scanPayload:(const uint8_t *)b length:(int)n {
    for (int i = 0; i < n && _scanning; i++) {
        uint8_t c = b[i];
        if (_expectNAL) {
            _expectNAL = NO;
            int type = c & 0x1F;
            if (type == 1 || type == 5) {
                _scanning = NO;
                if (type == 5) [self idrFound];
                return;
            }
            _zeros = 0;
        } else if (c == 0) {
            if (_zeros < 2) _zeros++;
        } else {
            if (c == 1 && _zeros >= 2) _expectNAL = YES;
            _zeros = 0;
        }
    }
}

- (void)idrFound {
    if (_active) {
        double duration = ((_auPTS - _segStartPTS) & IPTVPTSMask) / IPTVPTSRate;
        if (duration < _targetDuration) return;
        if (duration > 60) {
            // Timestamps jumped (source splice): the old segment's length is unknowable, so start over.
            [_lock lock];
            _nextDiscontinuity = YES;
            [_lock unlock];
        } else {
            NSData *finished = [_current subdataWithRange:NSMakeRange(0, _auStart)];
            [self publish:finished duration:duration];
        }
    } else if (!_pat || !_pmt) {
        return;
    }
    NSData *rest = [_current subdataWithRange:NSMakeRange(_auStart, _current.length - _auStart)];
    NSMutableData *next = [NSMutableData dataWithCapacity:rest.length + 2 * IPTVTSPacket];
    [next appendData:_pat];
    [next appendData:_pmt];
    [next appendData:rest];
    _current = next;
    _segStartPTS = _auPTS;
    _active = YES;
}

- (void)publish:(NSData *)data duration:(double)duration {
    IPTVSegment *segment;
    [_lock lock];
    segment = [[IPTVSegment alloc] initWithSequence:_nextSequence++ data:data duration:duration discontinuity:_nextDiscontinuity];
    _nextDiscontinuity = NO;
    [_window addObject:segment];
    while (_window.count > _windowSize) {
        if (_window.firstObject.discontinuity) _discontinuitySequence++;
        [_window removeObjectAtIndex:0];
    }
    [_lock unlock];
    if (_onSegment) _onSegment(segment);
}
@end
