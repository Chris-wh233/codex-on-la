#!/bin/bash
# Shared build paths and the verified openEuler LLVM 21 configuration.
TARGET="loongarch64-unknown-linux-gnu"
CODEX_TAG="rust-v${CODEX_VER}"
RUSTY_V8_URL="https://github.com/Chris-wh233/rusty_v8"
SECCOMPILER_URL="https://github.com/Chris-wh233/seccompiler-loongarch64"

configure_build_environment()
{
    export RUSTC_BOOTSTRAP=1
    export CLANG_BASE_PATH=/opt/openEuler/llvm-toolset-21/root/usr
    export LIBCLANG_PATH=/opt/openEuler/llvm-toolset-21/root/usr/lib64
    export EXTRA_GN_ARGS='rust_bindgen_root="/root/.cargo" clang_version="21"'
}
