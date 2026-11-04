// Exercises dispatch and failure guards with a mock pwn(). Never loads upstream exploit code.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const controller = fs.readFileSync(__dirname + '/offline-tns-controller.js', 'utf8');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
function harness(overrides = {}, throws = false, renderer = 'Apple A7 GPU') {
    const handlers = {}, timers = [];
    const button = {disabled: true}, result = {};
    let attempts = 0;
    const context = {
        TNS_CONFIG: {...config, ...overrides}, Uint8Array, Date,
        atob: value => Buffer.from(value, 'base64').toString('latin1'),
        navigator: {userAgent: 'Mozilla/5.0 (iPad; CPU OS 10_3_3 like Mac OS X)'},
        pwn(bytes) { attempts++; assert.equal(bytes.length, config.bytes); if (throws) throw Error('mock failure'); },
        spyware() {}, Int64() {},
        b2u32: bytes => (bytes[0] | bytes[1] << 8 | bytes[2] << 16 | bytes[3] << 24) >>> 0,
        document: {
            getElementById: id => id === 'run' ? button : result,
            createElement: () => ({getContext: () => ({getExtension: () => ({UNMASKED_RENDERER_WEBGL: 1}),
                                                       getParameter: () => renderer})})
        },
        window: {addEventListener(name, callback) { handlers[name] = callback; }, setTimeout(callback) { timers.push(callback); }}
    };
    vm.runInNewContext(controller, context);
    return {button, result, attempts: () => attempts, load: () => handlers.load(),
            error: () => handlers.error({message: 'mock script error'}), drain: () => { while(timers.length) timers.shift()(); }};
}
let h = harness({checkOnly: true});
h.load(); h.button.onclick(); h.drain(); assert.equal(h.attempts(), 0); assert(h.button.disabled);
assert.match(h.result.textContent, /CHECK ONLY/);
h = harness({checkOnly: false});
h.button.onclick(); h.drain(); assert.equal(h.attempts(), 0);
h.load(); h.drain(); assert.equal(h.attempts(), 0); assert.equal(h.button.disabled, false);
h.button.onclick(); h.button.onclick(); h.drain(); h.button.onclick(); h.drain(); assert.equal(h.attempts(), 1);
h = harness({checkOnly: false}, true); h.load(); h.button.onclick(); h.drain();
assert.equal(h.attempts(), 1); assert.match(h.result.textContent, /STOPPED: Error: mock failure/);
h.button.onclick(); h.drain(); assert.equal(h.attempts(), 1);
h = harness({checkOnly: false, crc32: 0}); h.load(); h.button.onclick(); h.drain();
assert.equal(h.attempts(), 0); assert.match(h.result.textContent, /integrity/);
h = harness({checkOnly: false}, false, 'Apple A9 GPU'); h.load(); h.button.onclick(); h.drain();
assert.equal(h.attempts(), 0); assert.match(h.result.textContent, /Target check did not match/);
h = harness({checkOnly: false}); h.load(); h.error(); h.button.onclick(); h.drain();
assert.equal(h.attempts(), 0); assert.match(h.result.textContent, /mock script error/);
h = harness({checkOnly: false}); h.load(); h.button.onclick(); h.error(); h.drain();
assert.equal(h.attempts(), 0);
console.log('PASS: exact embedded payload CRC, check-only mode, explicit click requirement, target gate, single attempt and error stops.');
