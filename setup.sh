#!/bin/bash

# 目前的 codex-cli 基于 glibc2.38 构建，暂不支持旧世界和新世界的 alpine
# codex 家目录使用默认的 ~/.codex，勿自定义 CODEX_HOME

set -euo pipefail

# ---------- 日志样式 ----------
info()  { printf '[ .. ] %s\n' "$*"; }
ok()    { printf '[ OK ] %s\n' "$*"; }
error() { printf '[ X ] %s\n' "$*" >&2; }
ask()   { printf '[ ?? ] %s' "$*"; }

stage() {
    local title="$1"
    printf '\n'
    printf '%s\n' '============================================================'
    printf '  %s\n' "${title}"
    printf '%s\n' '============================================================'
}

codex_home="${HOME}/.codex"
codex_bin_dir=/opt/codex-bin
codex_bin_path="${codex_bin_dir}/codex"

# ---------- 第 1 步：准备运行环境 ----------
stage '[1/6] 准备运行环境'

mkdir -p "${codex_bin_dir}"
info "codex 安装目录: ${codex_bin_dir}"

if ! command -v curl > /dev/null 2>&1; then
    info '安装 curl...'
    if command -v apt > /dev/null 2>&1; then
        pkg_cmd=apt
        "${pkg_cmd}" update
    elif command -v dnf >/dev/null 2>&1; then
        pkg_cmd=dnf
    else
        error '未找到支持的包管理器'
        exit 1
    fi
    "${pkg_cmd}" install -y curl
    ok 'curl 安装完成'
fi

# ---------- 第 2 步：获取 codex ----------
stage '[2/6] 获取 codex-cli'

while :; do
    ask 'codex 是否已经下载到本地？[y/n]: '
    read -r answer

    case "${answer}" in
        y|Y)
            ask '请输入 codex 的本地存放路径: '
            read -r codex_path

            if [ ! -e "${codex_path}" ]; then
                error "路径不存在：${codex_path}"
                exit 1
            fi

            if [ "${codex_path}" == "${codex_bin_path}" ]; then
                ok 'codex 已在期望路径'
            else
                mv "${codex_path}" "${codex_bin_path}"
                ok "codex 已移动至: ${codex_bin_path}"
            fi
            break
            ;;
        n|N)
            info '开始下载 codex ...'
            codex_ver=0.144.6
            codex_url="https://github.com/Chris-wh233/codex-on-la/releases/download/${codex_ver}/codex-${codex_ver}"
            curl -fL -o "${codex_bin_path}" "${codex_url}"
            ok "codex 已下载至: ${codex_bin_path}"
            break
            ;;
        *)
            error '请输入 y 或 n'
            ;;
    esac
done

# ---------- 第 3 步：初始化 codex ----------
stage '[3/6] 初始化 codex'

chmod +x "${codex_bin_path}"
info '启动 codex 以生成配置目录...'
"${codex_bin_path}" & pid=$!
sleep 1
kill "$pid"
wait "$pid" 2>/dev/null || true

if [ ! -d "${codex_home}" ]; then
    error "初始化失败，未能生成 ${codex_home}"
    error "请确认 ${codex_bin_path} 是否可用"
    exit 1
fi
ok '初始化完成'

# ---------- 第 4 步：配置 deepseek 模型 ----------
stage '[4/6] 配置 deepseek 模型'

info '下载并执行 deepseek 官方配置脚本（以下为官方脚本输出）...'
old_path="${PATH}"
export PATH="/opt/codex-bin:$PATH"
if ! curl -fsSL \
    https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh \
    | bash -Eeuo pipefail
then
    error '配置 deepseek 模型失败'
    exit 1
fi
export PATH="$old_path"
ok 'deepseek 模型配置完成'

# ---------- 第 5 步：安装自定义 skill ----------
stage '[5/6] 安装自定义 skill'

while :; do
    ask '是否安装自定义的 skill？[y/n]: '
    read -r answer

    case "${answer}" in
        y|Y)
            codex_skills_dir="${codex_home}/skills"
            custom_skills_dir="./skills"

            # codex 的 skills 目录
            [ ! -d "${codex_skills_dir}" ] && mkdir -p "${codex_skills_dir}"

            # 安装自定义 skills
            find "${custom_skills_dir}" -mindepth 1 -maxdepth 1 -type d \
                -exec cp -a -t "${codex_skills_dir}" -- {} +
            ok '自定义 skill 安装完成'
            break
            ;;
        n|N)
            info '跳过自定义 skill 安装'
            break
            ;;
        *)
            error '请输入 y 或 n'
            ;;
    esac
done

# ---------- 第 6 步：安装辅助命令 ----------
stage '[6/6] 安装辅助命令'

info '安装 codex 启动脚本，以及会话导入/导出脚本...'
chmod +x ./tools/*.sh
cp tools/codex.sh /usr/bin/codex

archive_name=codex_sessions
sed -i "s/__ARCHIVE_NAME__/$archive_name/" tools/import_session.sh tools/export_session.sh
cp tools/import_session.sh /usr/bin/import_session
cp tools/export_session.sh /usr/bin/export_session
ok '安装完成'

# ---------- 完成 ----------
printf '\n'
printf '%s\n' '============================================================'
printf '  codex 安装完成!\n'
printf '%s\n' '============================================================'
printf '\n'
printf '  可用指令:\n'
printf '    codex           -- 启动 codex(以最高权限运行)\n'
printf '    import_session  -- 导入会话\n'
printf '    export_session  -- 导出会话\n'
printf '\n'
