const addon = require('../zig-out/lib/basic.node');
const assert = require('node:assert/strict');

assert.strictEqual('Hello from Zig!', addon.hello());
assert.strictEqual('Hello John', addon.greeting('John'));
assert.strictEqual(30, addon.add(10, 20));
assert.strictEqual(undefined, addon.scope_demo());
