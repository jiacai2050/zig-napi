OUT_DIR = zig-out

.PHONY: build test lint clean

test:
	zig build test

build:
	zig build

lint:
	zig fmt --check .

clean:
	rm -rf $(OUT_DIR)
