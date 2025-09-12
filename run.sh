#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# ARM64 driver:
#  - docker image build
#  - build llvm-test-suite SingleSource/Benchmarks for aarch64
#  - time/space CSV (QEMU by default)
#
# example usage:
#   ./run.sh                # build image, build tests, run under qemu-aarch64
#   ./run.sh --native       # run natively instead of QEMU (ARM64 host only)
#   ./run.sh --timeout 15   # change per-binary timeout (seconds)
#   ./run.sh --rebuild      # force docker image rebuild (no cache)
# ------------------------------------------------------------------------------

IMAGE="llvm-ts:arm64"
DOCKERFILE="docker/Dockerfile"
OUT_DIR="out"
RUN_UNDER="qemu"         # "qemu" | "native"
TIMEOUT_SEC="10"
REBUILD="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --native) RUN_UNDER="native"; shift ;;
    --timeout) TIMEOUT_SEC="${2:-10}"; shift 2 ;;
    --rebuild) REBUILD="1"; shift ;;
    -h|--help)
      echo "Usage: $0 [--native] [--timeout N] [--rebuild]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "ERROR: $DOCKERFILE not found. Run from repo root." >&2
  exit 1
fi

echo "Building Docker image: ${IMAGE}"
if [[ "$REBUILD" == "1" ]]; then
  docker build --no-cache -t "$IMAGE" -f "$DOCKERFILE" .
else
  docker build -t "$IMAGE" -f "$DOCKERFILE" .
fi

mkdir -p "$OUT_DIR"

echo "Running container (artifacts -> $OUT_DIR)"
docker run --rm -it \
  -e RUN_UNDER="${RUN_UNDER}" \
  -e TIMEOUT_SEC="${TIMEOUT_SEC}" \
  -v "$PWD/$OUT_DIR":/workspace/build \
  "$IMAGE" \
  bash -lc '
set -euo pipefail
echo "Container RUN_UNDER=${RUN_UNDER:-qemu}, TIMEOUT_SEC=${TIMEOUT_SEC:-10}"

# Build suite (ARM64)
./build-arm64.sh

# Run CSV pass (QEMU default)
./run-arm64-bench-csv.sh

# Quick peek
echo
echo "==> Preview (first 10 rows):"
head -n 10 /workspace/build/benchmarks.csv || true

echo "==> Done. Full CSV at /workspace/build/benchmarks.csv"
'

echo
echo "Finished.  CSV is at: ${OUT_DIR}/benchmarks.csv"
echo "if you want native run for comparison ->  ./run.sh --native  (ARM64 host only)"
echo "if you want to adjust timeout (seconds) ->   ./run.sh --timeout 20"
