#!/bin/bash
set -e

WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"

echo " Running ARM64 tests with QEMU emulation"

echo "Check QEMU (hello world under qemu-aarch64)"
cat >/tmp/test_qemu.c <<'C'
#include <stdio.h>
int main(void){ printf("QEMU aarch64 working\n"); return 42; }
C
aarch64-linux-gnu-gcc -O2 /tmp/test_qemu.c -o /tmp/test_qemu
echo "native execution on container arch (likely x86_64):"
./tmp/test_qemu 2>/dev/null || echo "(not executable natively on non-ARM host)"
echo "QEMU execution:"
env QEMU_LD_PREFIX=/usr/aarch64-linux-gnu qemu-aarch64 /tmp/test_qemu; echo "Exit code: $?"
rm /tmp/test_qemu /tmp/test_qemu.c

echo
echo "test a few built binaries manually"
cd "$BUILD_DIR/SingleSource"

test_binaries=(
  "Benchmarks/Misc/mandel"
  "Benchmarks/McGill/chomp"
  "Benchmarks/McGill/misr"
)

for binary_path in "${test_binaries[@]}"; do
  if [ -x "$binary_path" ]; then
    echo "Testing: $binary_path"
    echo "  File info: $(file "$binary_path")"
    echo "  QEMU execution:"
    timeout 5s env QEMU_LD_PREFIX=/usr/aarch64-linux-gnu qemu-aarch64 "./$binary_path" 2>&1 | head -3 || echo "  (completed/timed out)"
    echo
  fi
done

echo "config lit for QEMU execution"
cat > lit.local.cfg << 'EOF'
# Force shell tests to run externally and add a %run substitution.
import lit.formats
config.test_format = lit.formats.ShTest(execute_external=True)
config.substitutions.append(('%run', 'qemu-aarch64'))
print("INFO: Using QEMU aarch64 emulation for test execution")
EOF
echo "Created lit.local.cfg with QEMU configuration"

echo
echo "--- Running lit tests (sample) ---"
if [ -f "Benchmarks/Misc/mandel.test" ]; then
  echo "Testing single benchmark with verbose output:"
  lit -v Benchmarks/Misc/mandel.test || echo "Single test completed"
fi

echo
echo "--- Running all benchmarks ---"
lit --time-tests -i . --json-output "$BUILD_DIR/lit-results.json" || echo "Tests completed with some failures"

echo
echo "Test run completed"
echo "Results saved to: $BUILD_DIR/lit-results.json"

if [ -f "$BUILD_DIR/lit-results.json" ]; then
  python3 << 'EOF'
import json
with open('/workspace/build/lit-results.json','r') as f:
    data = json.load(f)

tests = data.get('tests', [])
total = len(tests)
passed = sum(1 for t in tests if t.get('code') == 'PASS')
failed = total - passed

print("\n=== SUMMARY ===")
print(f"Total tests: {total}")
print(f"Passed: {passed}")
print(f"Failed: {failed}")
print("Success rate: {:.1f}%".format((passed/total*100) if total else 0))

if failed:
    print("\nFirst 5 failures:")
    for t in (x for x in tests if x.get('code') != 'PASS')[:5]:
        print(f"  - {t.get('name','unknown')}: {t.get('code','unknown')}")
EOF
else
  echo "No results file found"
fi
