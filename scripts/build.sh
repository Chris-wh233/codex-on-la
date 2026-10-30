#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 0.163.0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
CODEX_VER="$1"

source "${SCRIPT_DIR}/lib/environment.sh"
source "${SCRIPT_DIR}/lib/patches.sh"
source "${SCRIPT_DIR}/lib/dependencies.sh"
source "${SCRIPT_DIR}/lib/compile.sh"
source "${SCRIPT_DIR}/lib/package.sh"

main()
{
    resolve_dependencies
    prepare_rusty_v8
    prepare_codex
    check_build_tools
    build_codex
    package_codex
    cleanup_sources
}

main
