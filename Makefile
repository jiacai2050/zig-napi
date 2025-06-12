OUT_DIR = zig-out

.PHONY: build test clean

build:
	zig build

test: build
	node index.js

lint:
	zig fmt --check .

clean:
	rm -rf $(OUT_DIR)
