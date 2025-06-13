
const addon = require('./zig-out/lib/hello.node');
const assert = require('node:assert/strict');

const msg = addon.hello();
assert.strictEqual(msg, 'Hello from Zig!');
console.log(msg);
addon.greeting("John");
