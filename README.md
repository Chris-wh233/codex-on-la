### (LoongArch64) 安装 codex 并接入 deepseek
执行 set.sh

!!! 建议在容器内部署，避免模型破坏生产环境。会话记录可以通过 tools/ 中的脚本进行迁移 !!!

skills/ 内放置自定义 skill 可一并安装

安装完成后，执行：
1. codex  -->  启动codex。默认最高权限
2. import_session  -->  导入会话记录
3. export_session  -->  导出指定会话

