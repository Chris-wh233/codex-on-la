#!/bin/bash

resolve_dependencies()
{
    local lock_file
    lock_file="$(mktemp)"
    curl -fsSL -o "${lock_file}" \
        "https://raw.githubusercontent.com/openai/codex/${CODEX_TAG}/codex-rs/Cargo.lock"

    local versions
    versions="$(python3 - "${lock_file}" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    packages = tomllib.load(source)["package"]
for name in ("v8", "seccompiler"):
    versions = {package["version"] for package in packages if package["name"] == name}
    if len(versions) != 1:
        raise SystemExit(f"Expected one {name} version in Cargo.lock, found {sorted(versions)}")
    print(versions.pop())
PY
)"
    rm -f "${lock_file}"
    local -a dependency_versions
    mapfile -t dependency_versions <<< "${versions}"
    RUSTY_V8_VER="${dependency_versions[0]}"
    SECCOMPILER_VER="${dependency_versions[1]}"

    require_branch "${RUSTY_V8_URL}" "${RUSTY_V8_VER}"
    require_branch "${SECCOMPILER_URL}" "v${SECCOMPILER_VER}"
}

require_branch()
{
    local repository="$1"
    local branch="$2"
    if ! git ls-remote --exit-code --heads "${repository}" "${branch}" > /dev/null 2>&1; then
        echo "[x] 依赖缺少分支: ${repository} (${branch})" >&2
        exit 1
    fi
}

prepare_gn()
{
    echo "✅ [Prepare] gn..."

    local GN_VER="${1}"

    rm -rf "${ROOT_DIR}/gn"
    git clone https://gn.googlesource.com/gn "${ROOT_DIR}/gn"
    pushd "${ROOT_DIR}/gn"
    git checkout "${GN_VER}"

    patch_gn

    python3 build/gen.py
    ninja -C out
    cp out/gn /usr/bin
    popd

    echo "✅ [Prepare] gn ready"
}

prepare_rusty_v8()
{
    echo "📦 [Prepare] rusty_v8..."

    rm -rf "${ROOT_DIR}/rusty_v8"
    git clone -b "${RUSTY_V8_VER}" --depth 1 "${RUSTY_V8_URL}" "${ROOT_DIR}/rusty_v8"
    pushd "${ROOT_DIR}/rusty_v8"
    cargo --version

    # 补全子模块
    git submodule update --init --recursive --depth 1

    # 准备 gn
    local V8_DEPS="${ROOT_DIR}/rusty_v8/v8/DEPS"
    local GN_VER
    GN_VER=$(sed -nE "/'gn_version'/s/.*'git_revision:([0-9a-fA-F]+)'.*/\1/p" "${V8_DEPS}")
    prepare_gn "${GN_VER}"

    patch_rusty_v8

    # 满足路径硬编码需求
    mkdir -p third_party/rust-toolchain/bin
    cp /root/.cargo/bin/rustc third_party/rust-toolchain/bin

    mkdir -p /opt/openEuler/llvm-toolset-21/root/usr/lib/clang/21/lib/loongarch64-unknown-linux-gnu
    local libclang_rt_builtins_a
    libclang_rt_builtins_a="$(find /opt/openEuler/llvm-toolset-21 -type f -name libclang_rt.builtins.a -print -quit)"
    if [[ -z "${libclang_rt_builtins_a}" ]]; then
        echo "Could not find libclang_rt.builtins.a" >&2
        exit 1
    fi
    ln -sf "${libclang_rt_builtins_a}" /opt/openEuler/llvm-toolset-21/root/usr/lib/clang/21/lib/loongarch64-unknown-linux-gnu/libclang_rt.builtins.a

    popd

    echo "✅ [Prepare] rusty_v8 ready"
}

prepare_codex()
{
    echo "📦 [Prepare] codex..."

    rm -rf "${ROOT_DIR}/codex"
    git clone -b "${CODEX_TAG}" --depth 1 https://github.com/openai/codex.git "${ROOT_DIR}/codex"

    patch_codex

    echo "📦 [Prepare] codex ready"
}

check_build_tools()
{
    echo "📦 [Prepare] checking build tools..."

    pushd "${ROOT_DIR}/codex/codex-rs"
    rustc --version
    protoc --version
    bindgen --version
    rg --version
    popd

    echo "📦 [Prepare] build tools ready"
}

cleanup_sources()
{
    rm -rf "${ROOT_DIR}/rusty_v8"
    rm -rf "${ROOT_DIR}/gn"
    rm -rf "${ROOT_DIR}/codex"

}
