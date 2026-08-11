#!/bin/bash

# 导入符合 export_session.sh 导出格式的会话包

set -euo pipefail

info()  { printf '[ .. ] %s\n' "$*"; }
ok()    { printf '[ OK ] %s\n' "$*"; }
error() { printf '[ X ] %s\n' "$*" >&2; }
ask()   { printf '[ ?? ] %s' "$*"; }

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

archive_name=__ARCHIVE_NAME__
codex_home="$HOME/.codex"
import_dir="/tmp/$archive_name"

cleanup()
{
    rm -rf -- "$import_dir"
}
trap cleanup EXIT

# 检查会话包结构
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

# 列出 codex 家目录下 rollout 文件名中包含的 id 字段
existing_rollout_ids()
{
    find "$codex_home/sessions" -type f -name 'rollout-*.jsonl' -printf '%f\n' 2>/dev/null \
        | sed -nE 's/^rollout-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-([0-9a-fA-F-]+)\.jsonl$/\1/p'
}

# 检测导入包与 codex 家目录下 rollout 文件的冲突
check_file_conflicts()
{
    local existing
    existing=$(existing_rollout_ids || true)
    local session_id
    while IFS= read -r session_id; do
        if printf '%s\n' "$existing" | grep -qxF "$session_id"; then
            printf '%s\n' "$session_id"
        fi
    done < <(jq -r '.id' "$1")
}

# 将导入包的索引与已有索引按 id 合并（覆盖冲突行，避免重复）
merge_index()
{
    local incoming_index="$1"
    local existing_index="$2"
    local tmp_index="${existing_index}.tmp.$$"

    if ! jq -c -n --slurpfile existing "$existing_index" --slurpfile incoming "$incoming_index" '
            ( [ $incoming[] | .id ] | unique ) as $incoming_ids
            | ( $existing[] | .id as $id | select( any($incoming_ids[]; . == $id) | not ) ),
              $incoming[]
        ' > "$tmp_index"
    then
        rm -f -- "$tmp_index"
        return 1
    fi

    mv -f "$tmp_index" "$existing_index"
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

    # 冲突检测：同时检查已有索引和 sessions 目录中的 rollout 文件名
    conflicting_ids=""
    if [ -f "$existing_index" ]; then
        conflicting_ids=$(check_id_conflicts "$incoming_index" "$existing_index" || true)
    fi
    file_conflicts=$(check_file_conflicts "$incoming_index" || true)
    conflicting_ids=$(printf '%s\n%s\n' "$conflicting_ids" "$file_conflicts" | sed '/^$/d' | sort -u)

    if [ -n "$conflicting_ids" ]; then
        echo '检测到会话 ID 冲突：'
        while IFS= read -r session_id; do
            echo "      - ${session_id}"
        done <<< "$conflicting_ids"
        ask '是否覆盖这些已存在的会话？[y/N]: '
        read -r answer

        case "$answer" in
            y|Y)
                ok '将覆盖已存在的会话文件'
                ;;
            *)
                error "用户拒绝覆盖，跳过会话包（未修改任何内容）：${archive}"
                cleanup
                continue
                ;;
        esac
    fi

    # 拷贝 rollout 文件
    mkdir -p "$codex_home/sessions"
    if ! cp -a "$import_dir/sessions" "$codex_home/"; then
        error "拷贝会话文件失败，跳过（未写入索引）：${archive}"
        cleanup
        continue
    fi

    # 校验每个文件是否都已就位，全部成功后再写入索引
    copy_failed=0
    while IFS= read -r rel; do
        if [ ! -f "$codex_home/sessions/$rel" ]; then
            error "拷贝校验失败：sessions/${rel}"
            copy_failed=1
        fi
    done < <(cd "$import_dir" && find sessions -type f -printf '%P\n')

    if [ "${copy_failed}" -ne 0 ]; then
        error "会话文件未完整拷贝，跳过（未写入索引）：${archive}"
        cleanup
        continue
    fi

    # 更新索引
    if [ ! -f "$existing_index" ]; then
        cp -a "$incoming_index" "$existing_index"
    elif [ -z "$conflicting_ids" ]; then
        cat "$incoming_index" >> "$existing_index"
    else
        if ! merge_index "$incoming_index" "$existing_index"; then
            error "合并索引失败，跳过：${archive}"
            cleanup
            continue
        fi
    fi

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
