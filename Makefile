OUT_DIR = zig-out

.PHONY: build test lint clean

test: build
	node tests/runner.js

build:
	zig build

lint:
	zig fmt --check .
	cd tests && make lint

clean:
	rm -rf $(OUT_DIR)
