#!/usr/bin/env bash
# Runs every test suite in tests(vibecoded).
#   Lua tests:  tests(vibecoded)/lua/run.sh
#   C++ tests:  $BUILD_DIR/insane_night_tests  (built by make tests)
set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

fail=0
LUA_BIN="${LUA_BIN:-lua5.4}"
if ! command -v "$LUA_BIN" >/dev/null 2>&1; then
  LUA_BIN="lua"
fi

echo "=== running Lua tests ==="
if ! bash "tests(vibecoded)/lua/run.sh"; then
  fail=1
fi

echo ""
echo "=== running Lua benchmark (RAM + speed) ==="
"$LUA_BIN" "tests(vibecoded)/lua/bench.lua" || fail=1

echo "=== running C++ tests ==="
CPP_BIN="${BUILD_DIR:-.build}/insane_night_tests"
if [ ! -x "$CPP_BIN" ]; then
  CPP_BIN="$ROOT/insane_night_tests"
fi
if [ -x "$CPP_BIN" ]; then
  if ! "$CPP_BIN"; then
    fail=1
  fi
else
  echo "  (skip: insane_night_tests not built — run \`make tests\` to build it)"
fi

if [ "$fail" -eq 0 ]; then
  echo "ALL TEST SUITES PASSED"
else
  echo "SOME TEST SUITES FAILED"
fi
exit "$fail"
