#!/bin/sh
# .apm/hooks/scripts/verify-on-stop.sh の動作を、使い捨ての Git リポジトリで確認する。
# 使い方: sh tests/verify-on-stop-test.sh [verify-on-stop.sh のパス]

hook=$(cd "$(dirname "${1:-.apm/hooks/scripts/verify-on-stop.sh}")" && pwd)/$(basename "${1:-verify-on-stop.sh}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"
failed=0

stop() { # 期待する終了コード, stop_hook_active, 説明
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"Stop","stop_hook_active":%s}' "$repo" "$2" |
    CLAUDE_PROJECT_DIR="$repo" sh "$hook" >"$work/out" 2>&1
  rc=$?
  if [ "$rc" != "$1" ]; then
    echo "FAIL (exit $rc, want $1): $3"
    sed 's/^/    /' "$work/out"
    failed=1
  fi
}

repo="$work/repo"
git init -q "$repo"
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
echo a >"$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" commit -qm init

stop 0 false ".agent/verify.sh が無ければ何もしない"

mkdir -p "$repo/.agent"
cat >"$repo/.agent/verify.sh" <<'EOF'
touch "$TMPDIR/ran"
[ -f ok ] || { echo "ok がありません"; exit 1; }
EOF
git -C "$repo" add .agent/verify.sh
git -C "$repo" commit -qm verify
rm -f "$TMPDIR/ran"

stop 0 false "変更が無ければ検証しない"
[ -f "$TMPDIR/ran" ] && { echo "FAIL: 変更が無いのに検証が走った"; failed=1; }

echo b >"$repo/b.txt"
stop 2 false "未コミットの変更があり検証が失敗したら差し戻す"
grep -q "1/5" "$work/out" || { echo "FAIL: 1 回目の表示が無い"; failed=1; }
grep -q "ok がありません" "$work/out" || { echo "FAIL: 検証の出力が渡されていない"; failed=1; }

for n in 2 3 4 5; do
  stop 2 true "続けて失敗したら差し戻す（$n 回目）"
done
grep -q "5/5" "$work/out" || { echo "FAIL: 5 回目の表示が無い"; failed=1; }
stop 0 true "上限を超えたら差し戻さない"

stop 2 false "新しい依頼では数え直す"
grep -q "1/5" "$work/out" || { echo "FAIL: 数え直されていない"; failed=1; }

touch "$repo/ok"
stop 0 true "検証が通れば止まってよい"

git -C "$repo" add -A
git -C "$repo" commit -qm work
git clone -q --bare "$repo" "$work/remote.git"
git -C "$repo" remote add origin "$work/remote.git"
git -C "$repo" fetch -q origin
git -C "$repo" branch -q -u origin/"$(git -C "$repo" branch --show-current)"
rm -f "$TMPDIR/ran"
stop 0 false "push 済みで変更が無ければ検証しない"
[ -f "$TMPDIR/ran" ] && { echo "FAIL: push 済みなのに検証が走った"; failed=1; }

rm "$repo/ok"
echo c >"$repo/c.txt"
git -C "$repo" add -A
git -C "$repo" commit -qm unpushed
stop 2 false "未 push のコミットがあれば検証する"

[ "$failed" = 0 ] && echo "verify-on-stop tests passed"
exit "$failed"
