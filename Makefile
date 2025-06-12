OUT_DIR = zig-out

.PHONY: build test lint clean

test: build
	node index.js

build:
	zig build

lint:
	zig fmt --check .

clean:
	rm -rf $(OUT_DIR)
