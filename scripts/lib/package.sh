#!/bin/bash

package_codex()
{
    local dist_dir="${ROOT_DIR}/dists"
    local package_name="codex-${CODEX_VER}-${TARGET}"
    local package_dir="${dist_dir}/${package_name}"
    local archive="${dist_dir}/${package_name}.tar.gz"

    rm -rf "${package_dir}" "${archive}"
    install -Dm755 "${ROOT_DIR}/codex/codex-rs/target/release/codex" \
        "${package_dir}/bin/codex"
    install -Dm755 "${ROOT_DIR}/codex/codex-rs/target/release/codex-code-mode-host" \
        "${package_dir}/bin/codex-code-mode-host"
    install -Dm755 "${ROOT_DIR}/codex/codex-rs/target/release/bwrap" \
        "${package_dir}/codex-resources/bwrap"
    install -Dm755 "$(command -v rg)" "${package_dir}/codex-path/rg"

    python3 - "${package_dir}/codex-package.json" "${CODEX_VER}" "${TARGET}" <<'PY'
import json
import sys

manifest_path, version, target = sys.argv[1:]
manifest = {
    "layoutVersion": 1,
    "version": version,
    "target": target,
    "variant": "codex",
    "entrypoint": "bin/codex",
    "resourcesDir": "codex-resources",
    "pathDir": "codex-path",
}
with open(manifest_path, "w", encoding="utf-8") as output:
    json.dump(manifest, output, indent=2)
    output.write("\n")
PY

    for executable in \
        "${package_dir}/bin/codex" \
        "${package_dir}/bin/codex-code-mode-host" \
        "${package_dir}/codex-resources/bwrap" \
        "${package_dir}/codex-path/rg"
    do
        test -x "${executable}"
    done
    "${package_dir}/bin/codex" --version | grep -F "${CODEX_VER}"
    "${package_dir}/codex-path/rg" --version
    "${package_dir}/codex-resources/bwrap" --version

    mkdir -p "${dist_dir}"
    tar -C "${dist_dir}" -czf "${archive}" "${package_name}"

    if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
        chown -R "${HOST_UID}:${HOST_GID}" "${dist_dir}"
    fi
    echo "Package directory: ${package_dir}"
    echo "Package archive:   ${archive}"
}
