'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {place} = require('../Resources/picker.js');
function inside(bounds, viewport) {
    assert.ok(bounds.left >= 8);
    assert.ok(bounds.top >= 8);
    assert.ok(bounds.left + bounds.width <= viewport.width - 8);
    assert.ok(bounds.top + bounds.maxHeight <= viewport.height - 8);
}
test('Phone model menu opens upward from the composer and stays within viewport', () => {
    const viewport={width:393,height:852};
    const bounds=place({left:130,top:730,bottom:774,width:90},viewport,300,20);
    inside(bounds,viewport);
    assert.equal(bounds.width,300);
    assert.ok(bounds.top<730);
    assert.equal(bounds.maxHeight,332);
});
test('iPad project filter menu opens below its trigger', () => {
    const viewport={width:1024,height:768};
    const bounds=place({left:12,top:190,bottom:234,width:304},viewport,260,6);
    inside(bounds,viewport);
    assert.equal(bounds.left,12);
    assert.equal(bounds.top,240);
    assert.equal(bounds.width,304);
});
test('Keyboard-reduced height clips the menu to the available space above', () => {
    const viewport={width:1024,height:400};
    const bounds=place({left:500,top:320,bottom:364,width:180},viewport,300,20);
    inside(bounds,viewport);
    assert.equal(bounds.maxHeight,306);
    assert.equal(bounds.top,8);
});
test('Menus near the right edge shift left without horizontal overflow', () => {
    const viewport={width:393,height:852};
    const bounds=place({left:325,top:90,bottom:134,width:60},viewport,300,4);
    inside(bounds,viewport);
    assert.equal(bounds.left,85);
});
test('Tiny viewports constrain even wide requested menus', () => {
    const viewport={width:250,height:260};
    const bounds=place({left:10,top:40,bottom:84,width:300},viewport,300,10);
    inside(bounds,viewport);
    assert.equal(bounds.width,234);
});
