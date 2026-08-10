#!/bin/bash

# 使用 export_session.sh 导出的会话记录。

set -euo pipefail

info()  { printf '[ .. ] %s\n' "$*"; }
ok()    { printf '[ OK ] %s\n' "$*"; }
error() { printf '[ X ] %s\n' "$*" >&2; }

echo '============================================================'
echo '  导入会话'
echo '============================================================'
echo

if [ "$#" -ne 1 ]; then
    error "用法: $0 <包含 tar.gz 会话包的目录>"
    exit 1
fi

archive_dir=$1
if [ ! -d "$archive_dir" ]; then
    error "不是有效目录：${archive_dir}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    error '未找到 jq，无法检查会话索引'
    exit 1
fi

archive_name=codex_sessions
codex_home="$HOME/.codex"
import_dir="/tmp/$archive_name"

cleanup()
{
    rm -rf -- "$import_dir"
}
trap cleanup EXIT

# 检查会话包结构（需要符合 export_session 的导出结构）
valid_archive()
{
    tar -tzf "$1" 2>/dev/null | awk -v root="$archive_name" '
        $0 == root "/session_index.jsonl" { has_index = 1 }
        $0 == root "/sessions/" { has_sessions = 1 }
        $0 != root "/" && index($0, root "/") != 1 { invalid = 1 }
        END { exit !(has_index && has_sessions && !invalid) }
    '
}

check_id_conflicts()
{
    jq -n --slurpfile incoming "$1" --slurpfile existing "$2" -r '
        [ $incoming[]
            | .id as $id
            | select(any($existing[]; .id == $id))
            | $id
          ]
        | unique[]
    ' "$1" "$2"
}

shopt -s nullglob
archives=("$archive_dir"/*.tar.gz)

if [ "${#archives[@]}" -eq 0 ]; then
    error '会话记录需要打包为 tar.gz'
    exit 1
fi

imported=0

for archive in "${archives[@]}"; do
    cleanup

    if ! valid_archive "$archive"; then
        error "无效会话包，跳过：${archive}"
        continue
    fi

    ok "找到有效会话包：${archive}"

    mkdir -p "$import_dir"
    if ! tar -xzf "$archive" --strip-components=1 -C "$import_dir"; then
        error "解压失败，跳过：${archive}"
        cleanup
        continue
    fi

    info "正在导入会话包: ${archive}"
    incoming_index="$import_dir/session_index.jsonl"
    existing_index="$codex_home/session_index.jsonl"

    if [ ! -f "$existing_index" ]; then
        cp -a "$incoming_index" "$existing_index"
    else
        if ! conflicting_ids=$(check_id_conflicts "$incoming_index" "$existing_index"); then
            error "未能检测是否存在会话 ID 冲突，跳过：${archive}"
            cleanup
            continue
        fi

        if [ -n "$conflicting_ids" ]; then
            error "会话 ID 冲突，跳过：${archive}"
            while IFS= read -r session_id; do
                echo "      - 冲突 session_id: ${session_id}"
            done <<EOF
$conflicting_ids
EOF
            cleanup
            continue
        fi

        cat "$incoming_index" >> "$existing_index"
    fi

    cp -ai "$import_dir/sessions" "$codex_home/"
    ok "会话包已导入：${archive}"
    imported=$((imported + 1))
    cleanup
done

if [ "${imported}" -gt 0 ]; then
    echo
    echo '============================================================'
    ok "导入完成：共 ${imported} 个会话包"
    echo '============================================================'
fi
