#!/usr/bin/env bash
# ============================================================
# 千帆云递 · 上游同步脚本（二次开发专用）
#
# 用途：把官方仓库的最新提交合并进你的 dev 分支，同时保留你的改动。
# 用法：
#   ./sync-upstream.sh            # 同步并变基（默认）
#   ./sync-upstream.sh --check    # 只看上游有什么新东西 + 冲突预警，不动代码
#   ./sync-upstream.sh --merge    # 用 merge 代替 rebase（保留完整历史）
#   ./sync-upstream.sh --abort    # 变基卡住时放弃，回到同步前的状态
# ============================================================
set -uo pipefail

# ---------- 可调参数 ----------
DEV_BRANCH="dev"                  # 你的开发分支
UPSTREAM_BRANCH="master"          # 官方主线
UPSTREAM_REMOTE="upstream"

# 下载源，按顺序探测，第一个可用的胜出。
# 镜像放前面：国内直连 GitHub 基本不通，放最后只作兜底。
# 若设置了环境变量 SYNC_SRC，则跳过探测直接用它，例如：
#   SYNC_SRC=https://kkgithub.com/DevilJie/QianFan-Sync.git ./sync-upstream.sh
CANDIDATES=(
  "https://ghproxy.net/https://github.com/DevilJie/QianFan-Sync.git"
  "https://ghfast.top/https://github.com/DevilJie/QianFan-Sync.git"
  "https://github.com/DevilJie/QianFan-Sync.git"
)
PROBE_TIMEOUT=12                  # 单个源探测超时（秒）

# ---------- 颜色 ----------
if [ -t 1 ]; then
  G=$'\033[0;32m'; Y=$'\033[0;33m'; R=$'\033[0;31m'; C=$'\033[0;36m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=''; Y=''; R=''; C=''; B=''; N=''
fi
ok()   { echo "${G}✓${N} $*"; }
warn() { echo "${Y}!${N} $*"; }
err()  { echo "${R}✗${N} $*" >&2; }
step() { echo; echo "${C}▸ $*${N}"; }

MODE="rebase"
case "${1:-}" in
  --check) MODE="check" ;;
  --merge) MODE="merge" ;;
  --abort)
    ROOT="$(git rev-parse --show-toplevel)" && cd "$ROOT"
    if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
      git rebase --abort && ok "已放弃本次变基，回到同步前状态"
    else
      warn "当前没有进行中的变基"
    fi
    exit 0 ;;
  --help|-h)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) err "未知参数：$1（用 --help 查看用法）"; exit 2 ;;
esac

# ---------- 定位仓库 ----------
if ! ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  err "当前目录不是 git 仓库"; exit 1
fi
cd "$ROOT"

# ---------- 前置检查 ----------
CUR_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CUR_BRANCH" != "$DEV_BRANCH" ]; then
  if [ "$MODE" = "check" ]; then
    warn "当前在 $CUR_BRANCH 分支，检查结果以该分支为准"
  else
    err "请在 $DEV_BRANCH 分支上执行同步（当前：$CUR_BRANCH）"
    echo "  切换命令：git checkout $DEV_BRANCH"
    exit 1
  fi
fi

if [ -n "$(git status --porcelain)" ]; then
  if [ "$MODE" = "check" ]; then
    warn "工作区有未提交改动（检查模式不影响任何东西）"
  elif [ "$MODE" = "merge" ]; then
    err "工作区有未提交改动，请先提交或 stash"
    echo "  git stash push -u -m 'sync前暂存'"
    exit 1
  else
    warn "工作区有未提交改动，变基时会自动 stash，结束后自动恢复"
  fi
fi

# ---------- 挑选可用下载源 ----------
step "探测可用的上游源"
PICKED=""
if [ -n "${SYNC_SRC:-}" ]; then
  echo "  使用指定源：$SYNC_SRC"
  PICKED="$SYNC_SRC"
else
  for url in "${CANDIDATES[@]}"; do
    printf "  %-66s" "$(echo "$url" | sed 's#https://##; s#\.git$##')"
    if GIT_TERMINAL_PROMPT=0 timeout "$PROBE_TIMEOUT" \
         git ls-remote --heads "$url" "$UPSTREAM_BRANCH" >/dev/null 2>&1; then
      echo "${G}可用${N}"
      PICKED="$url"
      break
    else
      echo "${R}不可用${N}"
    fi
  done
fi

if [ -z "$PICKED" ]; then
  err "所有源都连不上。请检查网络/代理，或手动修改脚本顶部的 CANDIDATES"
  exit 1
fi

# 把选中的源写进 remote（只改 fetch 地址，push 地址保持禁用）
git remote set-url "$UPSTREAM_REMOTE" "$PICKED" 2>/dev/null \
  || git remote add "$UPSTREAM_REMOTE" "$PICKED"
git config "remote.$UPSTREAM_REMOTE.pushurl" "NO_PUSH_ALLOWED"

# ---------- 拉取 ----------
step "拉取上游 $UPSTREAM_BRANCH"
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH" --tags --prune 2>&1 | sed 's/^/  /'
BASE="$(git rev-parse "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")"

AHEAD="$(git rev-list --count "$BASE..HEAD")"
BEHIND="$(git rev-list --count "HEAD..$BASE")"

echo
echo "  你的独有提交：${B}${AHEAD}${N} 个"
echo "  上游新增提交：${B}${BEHIND}${N} 个"

if [ "$BEHIND" -eq 0 ]; then
  ok "已经是最新，无需同步"
  exit 0
fi

# ---------- 冲突预警：双方都改过的文件 ----------
MINE="$(git diff --name-only "$BASE...HEAD" 2>/dev/null | sort || true)"
THEIRS="$(git diff --name-only "HEAD...$BASE" 2>/dev/null | sort || true)"
OVERLAP="$(comm -12 <(echo "$MINE") <(echo "$THEIRS") 2>/dev/null || true)"

if [ -n "$OVERLAP" ]; then
  echo
  warn "下列文件你和上游都改过，同步时可能冲突："
  echo "$OVERLAP" | sed 's/^/    /'
else
  echo
  ok "双方没有改动同一个文件，同步应该零冲突"
fi

# ---------- 检查模式到此为止 ----------
if [ "$MODE" = "check" ]; then
  step "上游新增的提交"
  git log --oneline --no-decorate "HEAD..$BASE" | sed 's/^/  /'
  echo
  echo "  确认没问题后执行：${B}./sync-upstream.sh${N}"
  exit 0
fi

# ---------- 备份当前位置 ----------
OLD_HEAD="$(git rev-parse HEAD)"
git tag -f "sync-backup-$(date +%Y%m%d-%H%M%S)" "$OLD_HEAD" >/dev/null 2>&1 || true
echo
echo "  同步前位置已打标签，回滚用：git reset --hard $OLD_HEAD"

# ---------- 执行同步 ----------
if [ "$MODE" = "merge" ]; then
  step "合并上游（merge）"
  if git merge --no-edit "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"; then
    ok "合并完成"
  else
    err "合并有冲突，请手动解决："
    echo "  1) git status 查看冲突文件"
    echo "  2) 编辑文件，搜索 <<<<<<< 标记"
    echo "  3) git add <文件> && git commit"
    echo "  放弃本次合并：git merge --abort"
    exit 1
  fi
else
  step "变基到上游最新（rebase）"
  if git rebase "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"; then
    ok "变基完成，你的改动已叠加在最新上游之上"
  else
    echo
    err "变基遇到冲突，请按下面步骤处理："
    echo "  1) git status            查看哪些文件冲突"
    echo "  2) 编辑文件，搜索 <<<<<<< 标记，保留你要的逻辑"
    echo "     提示：优先接受上游的新写法，再把你的改动重新加回去"
    echo "  3) git add <冲突文件>"
    echo "  4) git rebase --continue   （会逐个提交继续）"
    echo "  想全部放弃：./sync-upstream.sh --abort"
    echo
    echo "  冲突文件列表："
    git diff --name-only --diff-filter=U | sed 's/^/    /'
    exit 1
  fi
fi

# ---------- 结果 ----------
step "同步结果"
echo "  当前 HEAD：$(git log --oneline -1)"
echo "  相对上游的独有改动：$(git rev-list --count "$BASE..HEAD") 个提交"
echo "  改动文件清单："
git diff --stat "$BASE..HEAD" | tail -20 | sed 's/^/    /'

echo
ok "完成。建议先跑一遍回归：cd backend && python -m pytest tests/"
echo "  推送自己的远程（变基过需要强推）：git push --force-with-lease origin $DEV_BRANCH"
