---
name: loop-state
description: Keep a single compact state file (.agent/state.json) so long or looped coding work can resume where it left off across sessions and context resets. Use when the user asks to work in a loop, run long or multi-step work autonomously, continue or resume previous work, or when .agent/state.json already exists in the project.
---

# ループ用の状態ファイル（.agent/state.json）

ループで動くと、毎回の作業で会話の記憶は引き継がれない。引き継ぐことはすべて `.agent/state.json` に書き、毎回の最初に読む。
このファイルは「今の目標のための作業メモ」であり、記録の保管場所ではない。過去の詳細は Git の履歴に任せ、ファイルは常に小さく保つ。

## 毎回の手順

1. **読む**: `.agent/state.json`、`git log --oneline -20`、`git status` を読み、どこまで進んだかを把握する。
   ファイルが無ければ、ユーザーの依頼から下の形式で作る。
2. **一つだけ進める**: `tasks` の中から `in_progress`、無ければ最初の `todo` を一つ選び、それだけを進める。複数を同時に進めない。
3. **確かめる**: `done_when` を満たしたか確かめる（`.agent/verify.sh` があれば実行する）。テストを消したり弱めたりして通してはいけない。
4. **書く**: `state.json` を更新し、作業内容と一緒にコミットする。
5. 目標を達成したら、下の「目標を達成したとき」に従って片付ける。

## 形式

```json
{
  "goal": "ログイン機能を作る",
  "done_when": ".agent/verify.sh が通り、ログイン画面からログインできる",
  "tasks": [
    { "id": 1, "title": "ログイン画面を作る", "status": "done" },
    { "id": 2, "title": "パスワードを検証する", "status": "in_progress" },
    { "id": 3, "title": "ログイン失敗時のエラー表示", "status": "todo" }
  ],
  "recent": [
    "2026-10-27 ログイン画面を作成。次はパスワード検証"
  ],
  "lessons": [
    "bcrypt はネイティブビルドが必要で失敗するため bcryptjs を使う"
  ]
}
```

| キー | 内容 |
|---|---|
| `goal` | 今の目標を一文で |
| `done_when` | 機械で確かめられる完了条件。「いい感じに」のような曖昧な条件にしない |
| `tasks` | やること。`status` は `todo` / `in_progress` / `done` / `blocked` のどれか。`blocked` のときは `note` に理由を書く |
| `recent` | 直近の作業記録。一件一行で「日付 したこと。次にやること」 |
| `lessons` | うまくいかなかったことと、その回避策。次の回に同じ失敗をしないためのもの |

上の5つ以外のキーは足さない。書いたあとは JSON として正しいか確かめる（例: `python3 -m json.tool .agent/state.json` や `node -e "JSON.parse(require('fs').readFileSync('.agent/state.json','utf8'))"`）。

## 大きさの上限（必ず守る）

- `recent` は **5 件まで**。追加して超えたら、古いものから消す。消した内容は Git の履歴で追える
- `lessons` は **10 件まで**。超えそうなら、似たものを一つにまとめるか、もう当てはまらないものを消す
- `tasks` は **15 件まで**。超えるなら目標が大きすぎるので、目標を分けることをユーザーに提案する
- 一件は一行・一文で書く。ログやエラー出力を貼り付けない
- `.agent/` に他のメモやドキュメントのファイルを増やさない。必要なことは `state.json` に書く

## 長く残すべきことは移す

プロジェクトの決まりごとや、この目標が終わっても役立つ知見（例:「このリポジトリではテストを `npm test` で実行する」）は、`state.json` に溜めずに、CLAUDE.md / AGENTS.md などのルールファイルへの追記をユーザーに提案する。

## 目標を達成したとき

`done_when` を満たし、全ての `tasks` が `done` になったら、`.agent/state.json` を削除してコミットする（`.agent/verify.sh` は残す）。経緯は Git の履歴に残る。
次の目標は、新しい `state.json` から始める。
