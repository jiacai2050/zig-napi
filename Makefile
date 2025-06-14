OUT_DIR = zig-out

.PHONY: build test example lint fix deps clean

test: build
	npm test

example: build
	npm run basic

build:
	zig build

lint:
	zig fmt --check .
	npm run lint
	npm run format

fix:
	zig fmt .
	npm run lint:fix
	npm run format:fix

deps:
	npm install

clean:
	rm -rf $(OUT_DIR)
