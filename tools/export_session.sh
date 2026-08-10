#!/bin/bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "至少选择一个会话进行导出(需确保已通过/rename命名)"
    echo "用法: $0 <会话1> <会话2> ..."
    exit 1
fi

codex_home="$HOME/.codex"
codex_session_index="$codex_home/session_index.jsonl"

if [ ! -f "$codex_session_index" ]; then
    echo "无已命名的会话，请在会话中执行/rename来命名(若有多个会话，勿重名)"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "[ X ] 未找到 jq，无法检查会话索引"
    exit 1
fi

# 导出会话
archive_name=__ARCHIVE_NAME__
export_dir="/tmp/$archive_name"
mkdir -p "$export_dir"

process()
{
    local session_index="$1"
    local session_id=$(printf '%s\n' "$session_index" | jq -r '.id')
    local rollout=$(find "$codex_home/sessions" -name *$session_id*)
    local rollout_base=$(dirname "$rollout")
    local rollout_base=${rollout_base#$codex_home/sessions/}

    # rollout 文件（保留原相对路径）
    mkdir -p "$export_dir/sessions/$rollout_base"
    cp -a "$rollout" "$export_dir/sessions/$rollout_base"

    # 索引，用于保留会话名称
    echo "$session_index" >> "$export_dir/session_index.jsonl"
}

for session in "$@"; do
    session_index=
    match_count=0

    while IFS= read -r line || [ -n "$line" ]; do
        if printf '%s\n' "$line" |
            jq -e --arg name "$session" '.thread_name == $name' >/dev/null
        then
            match_count=$((match_count + 1))
            session_index=$line
        fi
    done < "$codex_session_index"

    case "$match_count" in
        0)
            echo "[ X ] 未找到名为 $session 的会话"
            exit 1
            ;;
        1)
            process "$session_index"
            echo "会话 $session 已导出"
            ;;
        *)
            echo "[ X ] 发现 $match_count 个同名会话：$session 。无法确定目标，请使用不同名称"
            exit 1
            ;;
    esac
done

tar -czf "$export_dir.tar.gz" -C /tmp "$archive_name"
rm -rf "$export_dir"
echo "====================================="
echo "导出完成：$export_dir.tar.gz"

