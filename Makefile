OUT_DIR = zig-out

.PHONY: build test example lint fix deps docs clean

test: build
	npm test

example: build
	node examples/hello.js

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

docs:
	zig build docs

deps:
	npm install

clean:
	rm -rf $(OUT_DIR)
