const addon = require('../zig-out/lib/array.node');
const assert = require('node:assert/strict');

const msg = 'Hello from Zig ArrayBuffer!';
const expected = writeAsciiStringToArrayBuffer(msg);
assert.deepStrictEqual(expected, addon.arraybuffer_demo(msg));

function writeAsciiStringToArrayBuffer(str) {
  const buffer = new ArrayBuffer(str.length);
  const view = new Uint8Array(buffer);
  for (let i = 0; i < str.length; i++) {
    view[i] = str.charCodeAt(i);
  }

  return buffer;
}
