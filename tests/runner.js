#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Check Node.js version - require 18+ for built-in test runner
const nodeVersion = process.version;
const majorVersion = parseInt(nodeVersion.slice(1).split('.')[0]);

console.log(`Running tests with Node.js ${nodeVersion}`);

if (majorVersion < 18) {
  console.error(`❌ Error: Node.js ${nodeVersion} is not supported.`);
  console.error(
    'This project requires Node.js 18+ for the built-in test runner.',
  );
  process.exit(1);
}

// Find all test files in test/ directory
const testDir = path.join(__dirname);
const testFiles = fs
  .readdirSync(testDir)
  .filter((file) => file.endsWith('_test.js'))
  .map((file) => path.join(testDir, file));

if (testFiles.length === 0) {
  console.log(
    '⚠️  No test files found, make sure your test files ending with "_test.js"',
  );
  process.exit(0);
}

console.log(`Found ${testFiles.length} test file(s):`);
testFiles.forEach((file) => console.log(`  - ${file}`));

// Use Node.js built-in test runner
console.log('Using Node.js built-in test runner...');
const testProcess = spawn('node', ['--test', ...testFiles], {
  stdio: 'inherit',
  cwd: path.join(testDir, '..'),
});

testProcess.on('close', (code) => {
  if (code === 0) {
    console.log('✅ All Node.js tests passed!');
  } else {
    console.error('❌ Some Node.js tests failed!');
    process.exit(code);
  }
});

testProcess.on('error', (err) => {
  console.error('Failed to start test process:', err);
  process.exit(1);
});
