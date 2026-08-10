# 目前的codex-cli基于glibc2.38构建，暂不支持旧世界和新世界的alpine
# codex 家目录使用默认的 ~/.codex，勿自定义CODEX_HOME
#!/bin/bash

set -euo pipefail

codex_home="${HOME}/.codex"
codex_bin_dir=/opt/codex-bin
codex_bin_path="${codex_bin_dir}/codex"
mkdir -p "${codex_bin_dir}"

if ! command -v curl > /dev/null 2>&1; then
    if command -v apt > /dev/null 2>&1; then
        pkg_cmd=apt
        "${pkg_cmd}" update
    elif command -v dnf >/dev/null 2>&1; then
        pkg_cmd=dnf
    else
        echo "未找到支持的包管理器"
        exit 1
    fi
    "${pkg_cmd}" install -y curl
fi

while :; do
    printf 'codex 是否已经下载到本地？[y/n]: '
    read -r answer

    case "${answer}" in
        y|Y)
            printf '请输入 codex 的本地存放路径: '
            read -r codex_path

            if [ ! -e "${codex_path}" ]; then
                printf '路径不存在：%s\n' "${codex_path}" >&2
                exit 1
            fi

            if [ "${codex_path}" == "${codex_bin_path}" ]; then
                printf 'codex 已在期望路径\n'
            else
                mv "${codex_path}" "${codex_bin_path}"
                printf 'codex 已移动至期望路径: %s\n' "${codex_bin_path}"
            fi
            break
            ;;
        n|N)
            printf '下载 codex ...\n'
            codex_ver=0.144.6
            codex_url="https://github.com/Chris-wh233/codex-on-la/releases/download/${codex_ver}/codex-${codex_ver}"
            curl -fL -o "${codex_bin_path}" "${codex_url}"
            printf 'codex 已下载至 /opt/codex-bin/codex\n'

            break
            ;;
        *)
            printf '请输入 y 或 n\n' >&2
            ;;
    esac
done

# 确保 codex 家目录存在
printf '\n==============================\n'
printf '初始化...\n'
chmod +x "${codex_bin_path}"
"${codex_bin_path}" & pid=$!
sleep 1
kill "$pid"
wait "$pid" 2>/dev/null || true

if [ ! -d "${codex_home}" ]; then
    printf '\n初始化失败，未能生成 %s\n' "${codex_home}"
    printf '请确认 %s 是否可用\n' "${codex_bin_path}"
    exit 1
else
    printf '\n初始化完成!\n'
fi

# 配置 deepseek
printf '\n==============================\n'
printf '\n配置 deepseek...\n'
old_path="${PATH}"
export PATH="/opt/codex-bin:$PATH"
if ! curl -fsSL \
    https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh \
    | bash -Eeuo pipefail
then
    printf '配置 deepseek 模型失败\n'
    exit 1
else
    printf '配置完成!\n'
fi
export PATH="$old_path"

# 安装自定义 skill
printf '\n==============================\n'
while :; do
    printf '是否安装自定义的 skill？[y/n]: '
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
            break
            ;;
        n|N)
            break
            ;;
        *)
            printf '请输入 y 或 n\n' >&2
            ;;
    esac
done

# 安装 codex 启动脚本，会话导入和导出脚本
chmod +x ./tools/*.sh
cp tools/codex.sh /usr/bin/codex

archive_name=codex_sessions
sed -i "s/__ARCHIVE_NAME__/$archive_name/" tools/import_session.sh tools/export_session.sh
cp tools/import_session.sh /usr/bin/import_session
cp tools/export_session.sh /usr/bin/export_session

printf '\n==============================\n'
printf 'codex 安装完成!\n'
printf '\n可用指令:\n'
printf 'codex           -- 启动codex\n'
printf 'import_session  -- 导入会话\n'
printf 'export_session  -- 导出会话\n\n'
