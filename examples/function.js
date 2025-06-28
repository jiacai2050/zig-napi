const addon = require('../zig-out/lib/function.node');
const assert = require('node:assert/strict');

function AddTwo(num) {
  return num + 2;
}
global.AddTwo = AddTwo;

assert.strictEqual(3, addon.callAddTwoNumbers(1));
assert.strictEqual(103, addon.callAddTwoNumbers(101));
