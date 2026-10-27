#!/bin/sh
# ツール実行前（PreToolUse）に呼ばれ、取り返しのつかない操作と秘密ファイルへのアクセスを止める。
# 止めるときは理由を標準エラーに出して終了コード 2 で終わる。それ以外は何もせず 0 で終わる。
# 対象とするルールは kenryu42/claude-code-safety-net (MIT License, Copyright (c) 2026 J Liew) の
# ルール一覧から選んだ。判定は文字列パターンで行うため、書き方を変えたコマンドはすり抜けうる。

input=$(cat | tr -d '\n')

# JSON から文字列フィールドの値を取り出し、エスケープを戻す
field() {
  printf '%s' "$input" |
    sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    awk '{ gsub(/\\n/, "\n"); gsub(/\\t/, " "); gsub(/\\"/, "\""); gsub(/\\\\/, "\\"); print }'
}

block() {
  echo "ガードレールで止めました: $1" >&2
  echo "本当に必要なら、ユーザーに確認してから手動で実行してもらってください。" >&2
  exit 2
}

has() {
  printf '%s\n' "$1" | grep -Eq -- "$2"
}

# 秘密ファイル（.env.example などのひな形は除く）
SECRET='(^|[/[:space:]"'"'"'=<])(\.env(\.[A-Za-z0-9_-]+)?|\.git-credentials|\.netrc|\.npmrc|\.pypirc|id_rsa|id_ed25519|id_ecdsa|id_dsa|\.aws/credentials)([[:space:]"'"'"'>;|&)]|$)'
TEMPLATE='\.env\.(example|sample|template|dist)([[:space:]"'"'"'>;|&)]|$)'

check_secret() {
  # ひな形だけを指している場合は通す
  stripped=$(printf '%s\n' "$1" | sed -E 's/\.env\.(example|sample|template|dist)//g')
  if has "$stripped" "$SECRET"; then
    block "秘密情報を含むファイル（.env、SSH 鍵、認証情報など）へのアクセス"
  fi
}

check_command() {
  cmd=$1
  check_secret "$cmd"

  if has "$cmd" '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|k)?sh([[:space:]]|$)'; then
    block "ネットから取得したスクリプトをそのまま実行する操作（curl ... | sh）"
  fi

  # ; && || | で区切った各コマンドごとに判定する
  printf '%s\n' "$cmd" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }' | while IFS= read -r seg; do
    seg=" $seg "
    if has "$seg" '[[:space:]]rm[[:space:]]' && has "$seg" '[[:space:]](-[a-zA-Z]*[rR]|--recursive)' &&
      has "$seg" '[[:space:]]["'"'"']?(/|/\*|~|~/|~/\*|\$HOME|\$\{HOME\}|\$HOME/|\.|\./|\.\.|\.\./|\*|\.git|\.git/)["'"'"']?[[:space:]]'; then
      block "ルート・ホーム・カレントディレクトリ・.git を丸ごと消す rm"
    fi
    has "$seg" '[[:space:]]git[[:space:]]' || continue
    if has "$seg" '[[:space:]]reset([[:space:]].*)?[[:space:]]--(hard|merge)[[:space:]]'; then
      block "未コミットの変更を捨てる git reset --hard"
    fi
    if has "$seg" '[[:space:]]push[[:space:]]' &&
      has "$seg" '[[:space:]](--force|--mirror|--delete|-[a-zA-Z]*[fd][a-zA-Z]*|\+[^[:space:]]+)[[:space:]]'; then
      block "リモートの履歴を書き換える・消す git push（--force-with-lease は使える）"
    fi
    if has "$seg" '[[:space:]]clean[[:space:]]' && has "$seg" '[[:space:]](-[a-zA-Z]*f|--force)'; then
      block "未追跡ファイルを消す git clean -f"
    fi
    if has "$seg" '[[:space:]]checkout([[:space:]].*)?[[:space:]](--|-f|--force)[[:space:]]' ||
      has "$seg" '[[:space:]]switch([[:space:]].*)?[[:space:]](--discard-changes|-f|--force)[[:space:]]'; then
      block "作業中の変更を捨てる git checkout / switch"
    fi
    if has "$seg" '[[:space:]]restore[[:space:]]' &&
      { ! has "$seg" '[[:space:]](--staged|-S)[[:space:]]' || has "$seg" '[[:space:]](--worktree|-W)[[:space:]]'; }; then
      block "作業中の変更を捨てる git restore（--staged だけなら使える）"
    fi
    if has "$seg" '[[:space:]]branch([[:space:]].*)?[[:space:]](-D|--delete[[:space:]].*--force)[[:space:]]'; then
      block "マージされていないブランチも消す git branch -D"
    fi
    if has "$seg" '[[:space:]]stash[[:space:]]+(drop|clear)[[:space:]]'; then
      block "退避した変更を消す git stash drop / clear"
    fi
  done || exit 2
}

command=$(field command)
[ -n "$command" ] && check_command "$command"

for key in file_path path; do
  value=$(field "$key")
  [ -n "$value" ] && check_secret "$value"
done

exit 0
