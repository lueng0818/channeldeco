#!/bin/bash
# ChannelDeco Deployment Evidence Gate（2026-09-06）
#
# 目的：把「本機完成」與「發布完成」分開。
# 依 EXECUTION-BOUNDARY-STANDARD.md：
#   Rule ③ Completion Rule —— 未經遠端驗證不得回報「發布完成」
#   Rule ④ Evidence Rule   —— git push 的 exit code 只代表「推送這個動作的結果」，
#                              不代表 GitHub 上的內容真的等於本機內容。本腳本驗的是後者。
#
# 本腳本不做認證、不推送，只用匿名讀取比對。
# 也因此不宣稱任何關於 write 權限的結論（匿名讀取成功 ≠ 有推送能力）。
#
# 輸出四項 evidence：
#   [1] local artifact hash
#   [2] local HEAD
#   [3] remote HEAD
#   [4] target file hash comparison
#
# 退出碼：
#   0 = DEPLOY_VERIFIED   遠端＝本機
#   1 = NOT VERIFIED      遠端落後本機（DEPLOY_WAITING / DEPLOY_BLOCKED）
#   2 = UNKNOWN           讀不到遠端，狀態無法判定（不得記成「已發布」也不得記成 0）
#
# 用法：bash tools/deploy_verify.sh
set -u

DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="https://github.com/lueng0818/channeldeco.git"
BRANCH="main"
FILES="index.html"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

hash_of() { sha256sum "$1" 2>/dev/null | cut -c1-16; }

echo "── ChannelDeco Deployment Evidence ──────────────────────"

# ── Evidence 1：local artifact hash ──────────────────────
echo "[1] local artifact hash"
for f in $FILES; do
  if [ -f "$DIR/$f" ]; then
    printf '    %-24s %s  %s bytes\n' "$f" "$(hash_of "$DIR/$f")" "$(wc -c <"$DIR/$f")"
  else
    printf '    %-24s MISSING\n' "$f"
  fi
done

# ── Evidence 2：local HEAD ───────────────────────────────
echo "[2] local HEAD"
if [ -d "$DIR/.git" ]; then
  LOCAL_HEAD=$(cd "$DIR" && git log -1 --pretty='%h %ad %s' --date=short 2>/dev/null)
  echo "    ${LOCAL_HEAD:-（讀不到，可能 lock 檔卡住）}"
  # 未推送的 commit-tree 物件不會出現在 git log，另外提示工作區與 HEAD 的差異
  if ! (cd "$DIR" && git diff --quiet HEAD -- $FILES 2>/dev/null); then
    echo "    ⚠ 工作區檔案與 local HEAD 不同（本機有尚未 commit 的變更）"
  fi
else
  echo "    n/a（此資料夾不是 git repo）"
fi

# ── Evidence 3：remote HEAD ──────────────────────────────
echo "[3] remote HEAD"
if ! timeout 180 git clone --quiet --depth 1 --branch "$BRANCH" "$REPO" "$WORK/r" 2>/dev/null; then
  echo "    讀取失敗"
  echo "─────────────────────────────────────────────────────────"
  echo "UNKNOWN: 無法讀取遠端 repo，部署狀態無法驗證"
  echo "  → 不得據此回報「已發布」，也不得記成 0；請重跑或改由 Windows 端確認"
  exit 2
fi
REMOTE_HEAD=$(cd "$WORK/r" && git log -1 --pretty='%h %ad %s' --date=short)
REMOTE_DATE=$(cd "$WORK/r" && git log -1 --pretty='%ad' --date=short)
echo "    $REMOTE_HEAD"

# ── Evidence 4：target file hash comparison ──────────────
echo "[4] target file hash comparison"
STALE=0
for f in $FILES; do
  if [ ! -f "$WORK/r/$f" ]; then
    printf '    ✗ %-22s 遠端不存在\n' "$f"
    STALE=1
  elif cmp -s "$DIR/$f" "$WORK/r/$f"; then
    printf '    ✓ %-22s %s == %s\n' "$f" "$(hash_of "$DIR/$f")" "$(hash_of "$WORK/r/$f")"
  else
    printf '    ✗ %-22s %s != %s\n' "$f" "$(hash_of "$DIR/$f")" "$(hash_of "$WORK/r/$f")"
    STALE=1
  fi
done

echo "─────────────────────────────────────────────────────────"
if [ "$STALE" -eq 0 ]; then
  echo "DEPLOY_VERIFIED: GitHub 上的內容等於本機內容"
  exit 0
fi
echo "NOT VERIFIED: 本機已更新但尚未發布，遠端仍停在 $REMOTE_DATE"
echo "  → 需由 Windows Deployment Pipeline 執行 push 後重跑本 gate"
echo "  → 容器端最多只能宣告 CONTENT_COMPLETE（Rule ③）"
exit 1
