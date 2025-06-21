const assert = require('node:assert/strict');
const { describe, it, before } = require('node:test');
const path = require('node:path');
const fs = require('node:fs');

// Check if the compiled addon exists
const addonPath = path.join(__dirname, '..', 'zig-out', 'lib', 'main.node');
if (!fs.existsSync(addonPath)) {
  throw new Error(
    `Addon not found at ${addonPath}. Please run 'make build' first.`,
  );
}

console.log(`Addon path: ${addonPath}`);
const addon = require(addonPath);

describe('Basic tests...', () => {
  before(() => {
    console.log('Run basic tests...');
  });

  describe('Module Structure', () => {
    it('should export hello function', () => {
      assert.strictEqual(typeof addon.hello, 'function');
    });
  });

  it('hello()', () => {
    const result = addon.hello();
    assert.strictEqual(result, 'Hello from Zig!');
  });

  it('greeting()', () => {
    assert.doesNotThrow(() => {
      const result = addon.greeting('Jack');
      assert.strictEqual(result, 'Hello Jack');
    });

    assert.throws(
      () => {
        addon.greeting();
      },
      { message: 'Incorrect number of arguments, expected 1' },
    );
  });

  it('add()', () => {
    assert.strictEqual(30, addon.add(10, 20));
  });
});

describe('Array tests...', () => {
  it('visit array in scope', () => {
    const numbers = Array.from({ length: 100 }, (_, i) => i + 1);
    const sum = addon.visitArrayInScope(numbers);
    assert.strictEqual(5050, sum);
  });

  function writeAsciiStringToArrayBuffer(str) {
    const buffer = new ArrayBuffer(str.length);
    const view = new Uint8Array(buffer);
    for (let i = 0; i < str.length; i++) {
      view[i] = str.charCodeAt(i);
    }

    return buffer;
  }

  it('arrayBuffer', () => {
    const msg = 'Hello from Zig ArrayBuffer!';
    const expected = writeAsciiStringToArrayBuffer(msg);
    assert.deepStrictEqual(expected, addon.makeArrayBuffer(msg));
  });
});

describe('Object tests...', () => {
  assert.deepStrictEqual(
    {
      'str-key': 'string prop',
      'i64-key': 100,
      'u64-key': 101,
      'i32-key': 200,
      'u32-key': 201,
      'f64-key': 300,
    },
    addon.makeObject(),
  );
});

describe('Value coerce...', () => {
  assert.strictEqual(123, addon.coerceStrToNumber('123'));
  assert.strictEqual(0.123, addon.coerceStrToNumber('.123'));
  assert.strictEqual(-0.123, addon.coerceStrToNumber('-.123'));

  assert.strictEqual('123', addon.coerceNumberToStr(123));
  assert.strictEqual('NaN', addon.coerceNumberToStr(NaN));
  assert.strictEqual('20000000000', addon.coerceNumberToStr(2e10));
});
