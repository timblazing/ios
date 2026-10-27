'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const ui = require('../Resources/chat.js');

test('Markdown never interprets remote HTML, JavaScript URLs, or fence labels', () => {
    const result=ui.markdown('# <img src=x onerror=alert(1)>\n\n[open](javascript:alert)\n\n```<script>\n</code><script>alert(1)</script>\n```\n`<svg onload=evil>`');
    assert.ok(!/<(?:script|img|svg|a)\b/.test(result));
    assert.ok(result.includes('&lt;img'));
    assert.ok(result.includes('&lt;/code&gt;&lt;script&gt;'));
    assert.ok(result.includes('<span class="link">open (javascript:alert)</span>'));
});
test('Markdown reads headings, lists, quotations and incomplete streaming code fences', () => {
    const result=ui.markdown('# Heading\n\n**Bold** and `x`\n\n- One\n- Two\n\n> Quote\n\n```js\nconst a = 1;');
    assert.ok(result.includes('<h2>Heading</h2>'));
    assert.ok(result.includes('<strong>Bold</strong>'));
    assert.ok(result.includes('<ul><li>One</li><li>Two</li></ul>'));
    assert.ok(result.includes('<blockquote>Quote</blockquote>'));
    assert.ok(result.endsWith('<code>const a = 1;</code></pre>'));
    assert.ok(ui.markdown('x'.repeat(40000)).length < 30100);
});
test('Duplicate sends remain blocked by both sending and uncertain commands', () => {
    const pending={abc:{state:'sending',command:{threadId:'one',commandId:'abc',text:'Hello'}}};
    assert.equal(ui.hasPending(pending,'one'),true);
    pending.abc.state='uncertain';
    assert.equal(ui.hasPending(pending,'one'),true);
    assert.equal(ui.hasPending(pending,'two'),false);
    assert.equal(pending.abc.command.commandId,'abc');
});
test('Late snapshots cannot replace the newly selected conversation', () => {
    assert.equal(ui.acceptsSnapshot('old','new'),false);
    assert.equal(ui.acceptsSnapshot('new','new'),true);
    assert.equal(ui.acceptsSnapshot(null,null),false);
});
test('Live updates follow the bottom without stealing a reader scroll position', () => {
    assert.equal(ui.followsLatest(2000,1400,500),false);
    assert.equal(ui.followsLatest(2000,1450,500),true);
    assert.equal(ui.followsLatest(300,0,500),true);
});
test('Acknowledgement clears only the sent draft and preserves newer edits', () => {
    assert.equal(ui.draftAfterConfirmation(' Hello ','Hello'),'');
    assert.equal(ui.draftAfterConfirmation('Hello again','Hello'),'Hello again');
});
test('Only pending resumable requests expose responses', () => {
    const approval={type:'approval_request'}, question={type:'user_input_request'};
    const request={status:'pending',responseCapability:{type:'live'}};
    assert.equal(ui.responseAllowed(request,approval),true);
    request.responseCapability={type:'message'};
    assert.equal(ui.responseAllowed(request,approval),false);
    assert.equal(ui.responseAllowed(request,question),true);
    request.responseCapability={type:'not_resumable'};
    assert.equal(ui.responseAllowed(request,question),false);
    request.status='resolved';request.responseCapability={type:'live'};
    assert.equal(ui.responseAllowed(request,approval),false);
});
test('Active runs and streamed replies choose queued dispatch behavior', () => {
    assert.equal(ui.active({activeRunId:'run'},[]),true);
    assert.equal(ui.active({status:'waiting'},[]),true);
    assert.equal(ui.active({},[{streaming:true}]),true);
    assert.equal(ui.active({activeRunId:null,status:'idle'},[]),false);
});
test('Command IDs are independent UUIDs', () => {
    const one=ui.uuid(),two=ui.uuid();
    assert.match(one,/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    assert.notEqual(one,two);
});
