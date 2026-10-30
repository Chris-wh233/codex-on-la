#!/bin/bash

set -euo pipefail
if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 0.163.0" >&2
    exit 1
fi
VERSION="$1"
CODEX_VER="rust-v${VERSION}"
if ! git ls-remote --exit-code --tags "https://github.com/openai/codex" "$CODEX_VER" > /dev/null 2>&1; then
    echo "[x] 没有这个 codex 版本：${CODEX_VER}"
    exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE=codex-builder
DOCKERFILE="${ROOT_DIR}/Dockerfile"
BUILD_PARAM=()
RUN_PARAM=(
    --rm
    -v "${ROOT_DIR}:/src:z"
    -w /src
    -e HOST_UID="$(id -u)"
    -e HOST_GID="$(id -g)"
)
if [[ -n "${http_proxy:-}" ]]; then
    BUILD_PARAM+=(--build-arg "http_proxy=${http_proxy}" --build-arg "HTTP_PROXY=${http_proxy}")
    RUN_PARAM+=(-e HTTP_PROXY="${http_proxy}")
fi

if [[ -n "${https_proxy:-}" ]]; then
    BUILD_PARAM+=(--build-arg "https_proxy=${https_proxy}" --build-arg "HTTPS_PROXY=${https_proxy}")
    RUN_PARAM+=(-e HTTPS_PROXY="${https_proxy}")
fi

if [[ -n "${no_proxy:-}" ]]; then
    BUILD_PARAM+=(--build-arg "no_proxy=${no_proxy}" --build-arg "NO_PROXY=${no_proxy}")
    RUN_PARAM+=(-e NO_PROXY="${no_proxy}")
fi

echo "🚀 Starting build process..."

docker build "${BUILD_PARAM[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${ROOT_DIR}"

docker run "${RUN_PARAM[@]}" \
    "${IMAGE}" \
    /bin/bash /src/scripts/build.sh "${VERSION}"


echo "✅ Build completed successfully!"
