/* Packaging controller only. The pinned upstream exploit is supplied separately. */
(function () {
    var attempted = false;
    var ready = false;
    var stopped = false;
    var payload;
    var result = document.getElementById('result');
    var button = document.getElementById('run');
    function stop(message) {
        stopped = true;
        ready = false;
        button.disabled = true;
        result.textContent = 'STOPPED: ' + message + '\nNo automatic retry. Keep the original TNS icon available.';
    }
    function crc32(bytes) {
        var crc = -1;
        for (var i = 0; i < bytes.length; i++) {
            crc ^= bytes[i];
            for (var bit = 0; bit < 8; bit++) {
                crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
            }
        }
        return (crc ^ -1) >>> 0;
    }
    window.addEventListener('error', function (event) { stop(event.message || 'JavaScript error'); });
    button.onclick = function () {
        if (!ready || attempted || TNS_CONFIG.checkOnly) { return; }
        attempted = true;
        ready = false;
        button.disabled = true;
        result.textContent = 'Running one TNS attempt. Wait for the original TNS prompt or a userspace restart.';
        window.setTimeout(function () {
            if (stopped) { return; }
            try { pwn(payload); }
            catch (error) { stop(String(error)); }
        }, 100);
    };
    window.addEventListener('load', function () {
        try {
            var decoded = atob(TNS_CONFIG.payload);
            payload = new Uint8Array(decoded.length);
            for (var i = 0; i < decoded.length; i++) { payload[i] = decoded.charCodeAt(i); }
            decoded = null;
            if (payload.length !== TNS_CONFIG.bytes || b2u32(payload.slice(0, 4)) !== 0xfeedfacf ||
                crc32(payload) !== TNS_CONFIG.crc32) { throw new Error('Embedded payload integrity check failed'); }
            if (typeof pwn !== 'function' || typeof spyware !== 'function' || typeof Int64 !== 'function') {
                throw new Error('Pinned TNS scripts did not parse');
            }
            var canvas = document.createElement('canvas');
            var gl = canvas.getContext('experimental-webgl');
            var info = gl && gl.getExtension('WEBGL_debug_renderer_info');
            var renderer = info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : 'unavailable';
            var target = /iPad;.*OS 10_3_3(?: | like)/.test(navigator.userAgent) && renderer.indexOf('A7') !== -1;
            result.textContent = 'Payload verified: ' + payload.length + ' bytes.\nTNS scripts parsed.\n' +
                'Renderer: ' + renderer + '\nTarget iPad / iOS 10.3.3 / A7: ' + target + '\n' +
                'Opened: ' + new Date().toISOString() + '\n' +
                (TNS_CONFIG.checkOnly ? 'CHECK ONLY: no exploit can be started here.' :
                    'Run only after a normal reboot, while unjailbroken.');
            if (!TNS_CONFIG.checkOnly && !target) { throw new Error('Target check did not match this iPad'); }
            ready = target && !TNS_CONFIG.checkOnly;
            button.disabled = !ready;
            button.hidden = TNS_CONFIG.checkOnly;
        } catch (error) { stop(String(error)); }
    });
}());
