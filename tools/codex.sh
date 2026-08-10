#!/bin/bash

# 由于是在容器中，所以以最高权限启动 codex，不做沙箱限制，避免交互时频繁授权

codex_bin=/opt/codex-bin/codex

echo '============================================================'
echo '  启动 codex（最高权限模式）'
echo '============================================================'
echo

"${codex_bin}" resume --all --yolo

echo
echo '  提示：执行 "export_session <会话名>" 可导出会话'
