#!/bin/sh
# エージェントが応答を終えようとしたとき（Stop）に、プロジェクトの検証スクリプトを実行する。
# 検証が失敗したら終了コード 2 で止まるのを差し戻し、失敗内容を渡して修正を続けさせる。
#
# - プロジェクトに .agent/verify.sh があるときだけ動く。無ければ何もしない
# - 未コミットか未 push の変更があるときだけ検証する（質問に答えただけのときは走らせない）
# - 1 回の依頼の中で AGENT_VERIFY_MAX 回（既定 5 回）差し戻したら、それ以上は止めずに人に任せる

input=$(cat | tr -d '\n')

field() {
  printf '%s' "$input" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p'
}

root=${CLAUDE_PROJECT_DIR:-$(field cwd)}
root=${root:-$PWD}
verify="$root/.agent/verify.sh"
[ -f "$verify" ] || exit 0
cd "$root" || exit 0

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  dirty=$(git status --porcelain 2>/dev/null)
  unpushed=$(git rev-list '@{u}..HEAD' 2>/dev/null)
  [ -n "$dirty" ] || [ -n "$unpushed" ] || exit 0
fi

session=$(field session_id | tr -cd 'A-Za-z0-9_-')
counter="${TMPDIR:-/tmp}/agent-verify-${session:-default}"
max=${AGENT_VERIFY_MAX:-5}
count=$(cat "$counter" 2>/dev/null || echo 0)
# stop_hook_active が true でなければ、新しい依頼の最初の停止なので数え直す
printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' || count=0

if output=$(sh "$verify" 2>&1); then
  rm -f "$counter"
  exit 0
fi

count=$((count + 1))
if [ "$count" -gt "$max" ]; then
  # 上限に達したので差し戻さない
  rm -f "$counter"
  exit 0
fi
echo "$count" >"$counter"

{
  echo "検証（.agent/verify.sh）が失敗しました（差し戻し ${count}/${max} 回目）。"
  echo "原因を直して、検証が通ってから作業を終えてください。直せない場合は理由をユーザーに説明してください。"
  echo "--- 出力（末尾 40 行）---"
  printf '%s\n' "$output" | tail -n 40
} >&2
exit 2
