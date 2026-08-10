#!/bin/bash

# 使用 export_session.sh 导出的会话记录。

if [ "$#" -ne 1 ]; then
    echo "用法: $0 <包含 tar.gz 会话包的目录>"
    exit 1
fi

archive_dir=$1
if [ ! -d "$archive_dir" ]; then
    echo "[ X ] 不是有效目录：$archive_dir"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "[ X ] 未找到 jq，无法检查会话索引"
    exit 1
fi

archive_name=__ARCHIVE_NAME__
codex_home="$HOME/.codex"
import_dir="/tmp/$archive_name"

cleanup()
{
    rm -rf -- "$import_dir"
}
trap cleanup EXIT

# 检查会话包结构（需要符合 export_seesion 的导出结构）
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
    echo "会话记录需要打包为tar.gz"
    exit 1
fi

for archive in "${archives[@]}"; do
    cleanup

    if ! valid_archive "$archive"; then
        echo "[ X ] 无效会话包，跳过：$archive"
        continue
    fi

    echo "[ OK ] 找到有效会话包：$archive"

    mkdir -p "$import_dir"
    if ! tar -xzf "$archive" --strip-components=1 -C "$import_dir"; then
        echo "[ X ] 解压失败，跳过：$archive"
        cleanup
        continue
    fi

    incoming_index="$import_dir/session_index.jsonl"
    existing_index="$codex_home/session_index.jsonl"

    if [ ! -f "$existing_index" ]; then
        cp -a "$incoming_index" "$existing_index"
    else
        if ! conflicting_ids=$(check_id_conflicts "$incoming_index" "$existing_index"); then
            echo "[ X ] 未能检测是否存在会话 ID 冲突，跳过：$archive"
            cleanup
            continue
        fi

        if [ -n "$conflicting_ids" ]; then
            echo "[ X ] 会话 ID 冲突，跳过：$archive"
            while IFS= read -r session_id; do
                echo "      冲突 session_id: $session_id"
            done <<EOF
$conflicting_ids
EOF
            cleanup
            continue
        fi

        cat "$incoming_index" >> "$existing_index"
    fi

    cp -ai "$import_dir/sessions" "$codex_home/"
    echo "[ OK ] 会话包已导入：$archive"
    cleanup
done
