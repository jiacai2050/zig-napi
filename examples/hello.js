const addon = require('../zig-out/lib/hello.node');
const assert = require('node:assert/strict');

assert.strictEqual('Hello John', addon.hello('John'));
