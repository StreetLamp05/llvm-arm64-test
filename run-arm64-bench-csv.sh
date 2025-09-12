#!/bin/bash
# Times SingleSource/Benchmarks ARM64 executables and writes a CSV.
# Runs each binary under qemu-aarch64 by default.
# CSV columns:
# name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out

set -u

WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"
OUT_CSV="${BUILD_DIR}/benchmarks.csv"
ROOT="${BUILD_DIR}/SingleSource"
RUN_UNDER="${RUN_UNDER:-qemu}"          # "qemu" or "native"
TIMEOUT_SEC="${TIMEOUT_SEC:-10}"

if [ ! -d "$ROOT" ]; then
  echo "Error: $ROOT not found, build first." >&2
  exit 1
fi

echo "name,path,file_size_bytes,text_bytes,data_bytes,bss_bytes,elapsed_sec,user_sec,sys_sec,max_rss_kb,exit_code,timed_out" > "$OUT_CSV"

mapfile -t tests < <(cd "$ROOT" && find Benchmarks -type f -name "*.test" | sort)

for t in "${tests[@]}"; do
  test_path="${ROOT}/${t}"
  bin_path="${test_path%.test}"
  name="$(basename "$bin_path")"

  if [ ! -x "$bin_path" ]; then
    echo "${name},${bin_path},,,,,,,,,," >> "$OUT_CSV"
    continue
  fi

  file_size="$(stat -c %s "$bin_path" 2>/dev/null || echo "")"

  text_bytes="" ; data_bytes="" ; bss_bytes=""
  if size_line="$(size -B "$bin_path" 2>/dev/null | awk 'NR==2{print $1" "$2" "$3}')"; then
    read -r text_bytes data_bytes bss_bytes <<<"$size_line"
  fi

  if [ "$RUN_UNDER" = "native" ]; then
    runner=( "$bin_path" )
    # native runs only work on an ARM64 host
  else
    # Use ARM64 sysroot from the cross toolchain so dynamic linking works
    runner=( env QEMU_LD_PREFIX=/usr/aarch64-linux-gnu qemu-aarch64 "$bin_path" )
    # Alternative form:
    # runner=( qemu-aarch64 -L /usr/aarch64-linux-gnu "$bin_path" )
  fi

  elapsed="" ; user="" ; sys="" ; maxrss="" ; exit_code="" ; timed_out=""
  /usr/bin/timeout "${TIMEOUT_SEC}s" /usr/bin/time -f '%e,%U,%S,%M' -o /tmp/time.$$ "${runner[@]}" >/dev/null 2>&1
  ec=$?
  exit_code="$ec"

  if [ -f /tmp/time.$$ ]; then
    IFS=, read -r elapsed user sys maxrss < /tmp/time.$$
    rm -f /tmp/time.$$
  fi

  if [ "$ec" -eq 124 ]; then
    timed_out="1"
  else
    timed_out="0"
  fi

  echo "${name},${bin_path},${file_size},${text_bytes},${data_bytes},${bss_bytes},${elapsed},${user},${sys},${maxrss},${exit_code},${timed_out}" >> "$OUT_CSV"
done

echo "CSV written: $OUT_CSV"
[ "$RUN_UNDER" = "native" ] || echo "Note: timings include qemu-aarch64 overhead."
