#!/usr/bin/env bash
# Runs all Lua tests in this directory against the real scripts/ (read-only).
set -u
cd "$(dirname "$0")/../.."

LUA_BIN="${LUA_BIN:-lua5.4}"
if ! command -v "$LUA_BIN" >/dev/null 2>&1; then
  LUA_BIN="lua"
fi

total_passed=0
total_failed=0
failed_files=0

for t in "tests(vibecoded)"/lua/test_*.lua; do
  echo ""
  echo "### $(basename "$t")"
  out=$("$LUA_BIN" "$t" 2>&1)
  code=$?
  passed=$(echo "$out" | grep -c '\[ok\]' || true)
  failed=$(echo "$out" | grep -c '\[FAIL\]' || true)
  xfailed=$(echo "$out" | grep -c '\[XF\]' || true)
  total_passed=$((total_passed + passed))
  total_failed=$((total_failed + failed))
  if [ "$code" -ne 0 ]; then failed_files=$((failed_files + 1)); fi
  echo "$out" | grep -E '\[FAIL\]' || true
done

echo ""
echo "=========================================="
echo "LUA TESTS: $total_passed passed, $total_failed failed ($failed_files files failing)"
if [ "$total_failed" -gt 0 ]; then exit 1; fi
exit 0