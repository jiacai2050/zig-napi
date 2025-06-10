OUT_DIR = zig-out

.PHONY: build test clean

build:
	zig build

test: build
	node index.js

clean:
	rm -rf $(OUT_DIR)
