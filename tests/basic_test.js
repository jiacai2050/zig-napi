const assert = require('node:assert/strict');
const { describe, it, before } = require('node:test');
const path = require('node:path');
const fs = require('node:fs');

describe('Basic tests...', () => {
  let addon;

  before(() => {
    // Check if the compiled addon exists
    const addonPath = path.join(
      __dirname,
      '..',
      'zig-out',
      'lib',
      'basic.node',
    );
    if (!fs.existsSync(addonPath)) {
      throw new Error(
        `Addon not found at ${addonPath}. Please run 'make build' first.`,
      );
    }

    // Load the addon
    addon = require(addonPath);
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
      assert.strictEqual(result, undefined);
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
