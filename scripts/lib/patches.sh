#!/bin/bash
# Keep architecture and toolchain patches together for review.

patch_gn()
{
    sed -i "/cflags.extend(\[/,/'-std=c++23'/ {/'-std=c++23'/i\\
        '-Wno-error=deprecated-declarations',
}" build/gen.py
}

patch_rusty_v8()
{
    # 去掉 llvm21 不支持的子模块构建参数
    sed -i '/-fdiagnostics-show-inlining-chain/d' ./build/config/compiler/BUILD.gn
    sed -i '/-fno-lifetime-dse/d' ./build/config/compiler/BUILD.gn
    sed -i '/-fsanitize-ignore-for-ubsan-feature/d' ./build/config/sanitizers/sanitizers.gni

    # 处理启用 V8 sandbox 时因 euler llvm 21 不支持 -fsanitize-ignore-for-ubsan-feature 带来的问题
    sed -i '/compiler:sanitize_c_array_bounds/d' ./build/config/BUILDCONFIG.gn
    sed -i '/compiler:sanitize_return/d' ./build/config/BUILDCONFIG.gn

    # 修复找不到 libclang 的问题
    sed -i 's#_libclang_path += "/lib"#_libclang_path = clang_base_path + "/lib64"#' ./build/rust/rust_bindgen_generator.gni
}

patch_codex()
{
    # 更换 v8 和 seccompiler 来源
    sed -i '/^[[:space:]]*\[patch\.crates-io\][[:space:]]*$/,/^[[:space:]]*\[/ {
        /^[[:space:]]*v8[[:space:]]*=/d
    }' "${ROOT_DIR}/codex/codex-rs/Cargo.toml"

    sed -i '/\[patch.crates-io\]/a\
v8 = { path = "'"${ROOT_DIR}/rusty_v8"'" }\
seccompiler = { git = "'"${SECCOMPILER_URL}"'", branch = "v'"${SECCOMPILER_VER}"'" }' "${ROOT_DIR}/codex/codex-rs/Cargo.toml"

    # codex-rs/code-mode-protocol/build.rs:8 使用的 protoc-bin-vendored 不支持
    # loongarch64。这里保留现有补丁，让 tonic-prost 在 vendored 查询失败后使用 PATH
    # 中由 protobuf-compiler 提供的 protoc。
    sed -i '/config\.protoc_executable.*/c\
    if let Ok(protoc) = protoc_bin_vendored::protoc_bin_path() {\
        config.protoc_executable(protoc);\
    }' "${ROOT_DIR}/codex/codex-rs/code-mode-protocol/build.rs"

    # 补充 GNU LoongArch package target 映射
    sed -i '/unsupported packaged daemon platform/i \
        ("linux", "loongarch64") if cfg!(target_env = "gnu") => Ok("loongarch64-unknown-linux-gnu"),' "${ROOT_DIR}/codex/codex-rs/app-server-daemon/src/prepare_install.rs"
}
