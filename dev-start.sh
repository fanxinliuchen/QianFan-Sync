#!/usr/bin/env bash
# ============================================================
# 二次开发启动入口（Linux / macOS）
#
# 作用：等价于 start.sh，但跳过「是否更新到最新代码」的询问。
# 原因：按 Y 会 git checkout -f master + git reset --hard origin/master，
#       抹掉 dev 分支上的改动。
# 要更新上游，请用 ./sync-upstream.sh。
# ============================================================
set -uo pipefail
export SAU_JUST_UPDATED=1
exec "$(cd "$(dirname "$0")" && pwd)/start.sh" "$@"
