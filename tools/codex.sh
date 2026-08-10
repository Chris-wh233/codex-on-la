# 由于是在容器中，所以以最高权限启动codex，不做沙箱限制，避免交互时频繁授权
#!/bin/bash

codex_bin=/opt/codex-bin/codex

"${codex_bin}" resume --all --yolo

echo '=================================================='
echo '执行 "export_session $session_name" 可导出会话'
