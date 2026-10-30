#!/bin/bash

build_codex()
{
    echo "🔨 [Build] codex..."

    pushd "${ROOT_DIR}/codex/codex-rs"

    configure_build_environment

    export STABLE_GIT_COMMIT
    STABLE_GIT_COMMIT="$(git rev-parse HEAD)"
    cargo build --release \
        -p codex-bwrap --bin bwrap \
        -p codex-cli --bin codex \
        -p codex-code-mode-host --bin codex-code-mode-host

    strip --strip-debug --strip-unneeded target/release/bwrap
    strip --strip-unneeded target/release/codex
    strip --strip-unneeded target/release/codex-code-mode-host

    popd
    echo "🔨 [Build] got codex"
}
