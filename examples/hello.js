const addon = require('../zig-out/lib/hello.node');
const assert = require('node:assert/strict');

assert.strictEqual('Hello Tom', addon.hello('Tom'));
assert.strictEqual('Hello Jack', addon.hello('Jack'));
