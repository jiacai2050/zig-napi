# Tests for zig-napi

This directory contains tests for the zig-napi project.

## Running Tests

### All Tests
```zig
zig build test
```

## Adding New Tests

### Zig Tests
Add test functions to the relevant `.zig` files using the `test` keyword:

```zig
test "my test description" {
    // Test implementation
    try testing.expect(condition);
}
```

### Node.js Tests
Add test cases following the existing structure:

```javascript
describe('Feature Name', () => {
    it('should do something', () => {
        // Test implementation
        assert.strictEqual(actual, expected);
    });
});
```
