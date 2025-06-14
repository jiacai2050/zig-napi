OUT_DIR = zig-out

.PHONY: build test example lint deps clean

test: build
	node tests/runner.js

example: build
	node examples/basic.js

build:
	zig build

lint:
	zig fmt --check .
	cd tests && make lint

deps:
	cd tests && make deps

clean:
	rm -rf $(OUT_DIR)
