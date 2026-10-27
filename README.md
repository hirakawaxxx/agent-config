# agent-config

個人用の [APM (Agent Package Manager)](https://github.com/microsoft/apm) パッケージ。
Claude Code / Codex / Cursor 向けのエージェント設定をまとめて配布する。

## 中身

| ファイル | 内容 |
|---|---|
| `apm.yml` | マニフェスト（対象: `claude`, `codex`, `cursor`） |
| `.apm/instructions/japanese-response.instructions.md` | 日本語で返答するルール |

## フック

| ファイル | 内容 |
|---|---|
| `.apm/hooks/notify-on-stop-claude-codex-hooks.json` | エージェントの応答完了時（`Stop`）に通知音を鳴らす |
| `.apm/hooks/scripts/notify-on-stop.sh` | 再生スクリプト。macOS は Glass.aiff、Windows（Git Bash / WSL）は PowerShell、Linux は aplay / paplay / play で wav を鳴らす。音を出せない環境では何もしない |
| `.apm/hooks/scripts/on-agent-complete.wav` | 通知音 |
| `.apm/hooks/guard-claude-codex-hooks.json` / `.apm/hooks/scripts/guard.sh` | 危険な操作と秘密ファイルへのアクセスを止めるガードレール（下記） |
| `.apm/hooks/verify-on-stop-claude-hooks.json` / `.apm/hooks/scripts/verify-on-stop.sh` | 終了前にプロジェクトの検証を走らせ、失敗なら差し戻す（下記） |

- 配置先: Claude Code は `.claude/settings.json`、Codex は `.codex/hooks.json`。
  Cursor は `.claude/settings.json` のフックを読み込むので、二重に鳴らないよう Cursor には配らない
  （ファイル名末尾の `-claude-codex-hooks` で配布先を指定している）。
- 再生方法と音源は [pascalporedda/awesome-claude-code](https://github.com/pascalporedda/awesome-claude-code)
  （MIT License, Copyright (c) 2024 Pascal Weinberger）を元にしている。元のフックにある会話ログの保存、
  `npx tsx` での実行、権限設定は取り込んでいない。

### ガードレール（`guard.sh`）

`.apm/hooks/guard-claude-codex-hooks.json` から、ツール実行前（`PreToolUse`）に `.apm/hooks/scripts/guard.sh` を呼ぶ。
止めるときは理由を出して終了コード 2 で終わり、エージェントは操作を中止する。

| 種類 | 止める操作 |
|---|---|
| ファイル削除 | `rm -rf` でルート・ホーム・カレント・親ディレクトリ・`*`・`.git` を消す |
| Git | `reset --hard`、`push --force` / `-f` / `+ref` / `--delete` / `--mirror`、`clean -f`、`checkout --` / `-f`、`switch --discard-changes` / `-f`、`restore`（`--staged` のみは可）、`branch -D`、`stash drop` / `clear` |
| 外部スクリプト | `curl ... \| sh` / `wget ... \| bash` |
| 秘密情報 | `.env` / `.env.*`（`.env.example` などのひな形は可）、SSH 秘密鍵、`.git-credentials`、`.netrc`、`.npmrc`、`.pypirc`、`~/.aws/credentials` の読み書き |

- ルールは [kenryu42/claude-code-safety-net](https://github.com/kenryu42/claude-code-safety-net)
  （MIT License, Copyright (c) 2026 J Liew）のルール一覧から、よく起きる事故に関わるものを選んだ。
- 判定は文字列パターンなので、`bash -c` の入れ子や変数を使った書き方はすり抜けうる。最後の砦ではなく、うっかり防止として使う。
- `git push --force-with-lease` は通す。
- テスト: `sh tests/guard-test.sh`（CI でも実行）

### 検証フック（`verify-on-stop.sh`）

エージェントが応答を終えようとしたとき（`Stop`）に、プロジェクトの `.agent/verify.sh` を実行する。
失敗したら終了コード 2 で止まるのを差し戻し、失敗内容を渡して修正を続けさせる（ループの「完了条件」）。

- **使うプロジェクトだけで有効**: `.agent/verify.sh` が無いプロジェクトでは何もしない
- **変更があるときだけ検証**: 未コミットか未 push の変更があるときだけ実行する。質問に答えただけのときは走らせない
- **差し戻しの上限**: 1 回の依頼の中で 5 回まで（環境変数 `AGENT_VERIFY_MAX` で変更可）。超えたら止めずに人に任せる。
  Claude Code 自体にも、連続 8 回で打ち切る上限がある
- **配布先は Claude Code のみ**。Codex / Cursor で Stop の差し戻しが同じように効くかは未確認
- 通知音フックは Stop のたびに鳴るので、差し戻しが起きると複数回鳴る

`.agent/verify.sh` の例（プロジェクトに合わせて書く）:

```sh
#!/bin/sh
set -e
npm run lint
npm test
```

テスト: `sh tests/verify-on-stop-test.sh`（CI でも実行）

## 取り込んでいる外部スキル

`apm.yml` の `dependencies.apm` で、バージョンを固定して取り込んでいる。
Claude Code には `.claude/skills/`、Codex / Cursor には `.agents/skills/` に配置される。

| スキル | 取得元 | ライセンス |
|---|---|---|
| `pdf` / `pptx` / `xlsx` | [anthropics/skills](https://github.com/anthropics/skills)（コミット固定） | ソース公開（非オープンソース）。個人利用 |
| `skill-creator` / `mcp-builder` / `webapp-testing` | [anthropics/skills](https://github.com/anthropics/skills)（コミット固定） | Apache 2.0 |
| `ponytail` ほか5種（review / audit / debt / gain / help） | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) `v5.3.2` | MIT |

ponytail はスキルだけを取り込んでいる。本体のフック（セッション開始時に Node スクリプトを
実行するもの）は Claude Code のプラグインとして入れたとき前提の作りなので含めていない。

## 使い方

使いたいプロジェクトで:

```bash
apm init                               # apm.yml がまだ無ければ
apm install hirakawaxxx/agent-config
apm compile                            # Claude / Codex / Cursor 向けファイルを生成
```

Copilot 以外のツールは `apm compile` を実行しないとルールを読み込まない。

生成されるファイル:

- Claude Code: `.claude/rules/japanese-response.md`（`paths` 指定なしなので常に読み込まれる）
- Codex: `AGENTS.md`
- Cursor: `.cursor/rules/japanese-response.mdc` と `AGENTS.md`（Cursor は `AGENTS.md` も常に読む）

ルールは全体に効かせたいので `applyTo` を付けていない。`applyTo: "**"` を付けると、
Claude Code / Cursor では「ファイルを扱うときだけ読み込む」ルールになってしまう。

## CI

`.github/workflows/verify-install.yml` が、空のプロジェクトにこのパッケージを
`apm install` → `apm compile` して、上の3ファイルが生成されることを確認する。
公開リポジトリなのでトークンは不要。
