const assert = require('node:assert/strict');
const { describe, it, before } = require('node:test');
const path = require('node:path');
const fs = require('node:fs');

describe('Hello Zig N-API Module', () => {
    let addon;

    before(() => {
        // Check if the compiled addon exists
        const addonPath = path.join(__dirname, '..', 'zig-out', 'lib', 'hello.node');
        if (!fs.existsSync(addonPath)) {
            throw new Error(`Addon not found at ${addonPath}. Please run 'make build' first.`);
        }
        
        // Load the addon
        addon = require(addonPath);
    });

    describe('Module Structure', () => {
        it('should export hello function', () => {
            assert.strictEqual(typeof addon.hello, 'function');
        });

        it('should have expected exports', () => {
            const exports = Object.keys(addon);
            assert.ok(exports.includes('hello'));
        });
    });

    describe('hello() function', () => {
        it('should return expected greeting message', () => {
            const result = addon.hello();
            assert.strictEqual(result, 'Hello from Zig!');
        });

        it('should return a string', () => {
            const result = addon.hello();
            assert.strictEqual(typeof result, 'string');
        });

        it('should return same result on multiple calls', () => {
            const result1 = addon.hello();
            const result2 = addon.hello();
            assert.strictEqual(result1, result2);
        });

        it('should not throw errors', () => {
            assert.doesNotThrow(() => {
                addon.hello();
            });
        });

        it('should handle multiple concurrent calls', () => {
            const promises = Array.from({ length: 10 }, () => 
                Promise.resolve(addon.hello())
            );
            
            return Promise.all(promises).then(results => {
                results.forEach(result => {
                    assert.strictEqual(result, 'Hello from Zig!');
                });
            });
        });
    });

    describe('Performance', () => {
        it('should execute quickly', () => {
            const start = process.hrtime.bigint();
            addon.hello();
            const end = process.hrtime.bigint();
            
            // Should complete in less than 1ms (1,000,000 nanoseconds)
            const duration = Number(end - start);
            assert.ok(duration < 1_000_000, `Function took ${duration}ns, expected < 1ms`);
        });

        it('should handle many calls efficiently', () => {
            const iterations = 1000;
            const start = process.hrtime.bigint();
            
            for (let i = 0; i < iterations; i++) {
                addon.hello();
            }
            
            const end = process.hrtime.bigint();
            const duration = Number(end - start);
            const avgDuration = duration / iterations;
            
            // Average should be less than 10,000 nanoseconds (0.01ms) per call
            assert.ok(avgDuration < 10_000, 
                `Average duration ${avgDuration}ns per call, expected < 10μs`);
        });
    });
});
