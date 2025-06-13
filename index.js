
const addon = require('./zig-out/lib/hello.node');
const assert = require('node:assert/strict');

addon.greeting("John");

const msg = addon.hello();
assert.strictEqual(msg, 'Hello from Zig!');

assert.strictEqual(30, addon.add(10,20));
