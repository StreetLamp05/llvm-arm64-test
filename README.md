# LLVM Test-Suite Runner (arm64 + QEMU)
This repo provides a script to:
- Build LLVM’s `SingleSource/Benchmarks`
- Run them under **QEMU (arm64)** or natively
- Collect **time + space metrics** into a CSV


## Environment Setup
This repo and script has been tested on:
- [x] Ubuntu 24.04.3 LTS (Noble)
- [x] Ubuntu 24.04 LTS (Noble Numbat) (Ubuntu Server)

requries docker

## Quick Start

```bash
git clone https://github.com/StreetLamp05/llvm-arm64-test.git
cd llvm-x86-test
chmod +x *.sh
./run.sh          # default: build + run benchmarks under QEMU
./run.sh --timeout <timeout in seconds (default is 10s) # change timeout settings



