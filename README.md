# agent-config

個人用の [APM (Agent Package Manager)](https://github.com/microsoft/apm) パッケージ。
Claude Code / Codex / Cursor 向けのエージェント設定をまとめて配布する。

## 中身

| ファイル | 内容 |
|---|---|
| `apm.yml` | マニフェスト（対象: `claude`, `codex`, `cursor`） |
| `.apm/instructions/japanese-response.instructions.md` | 日本語で返答するルール |

## 使い方

使いたいプロジェクトで:

```bash
apm init                               # apm.yml がまだ無ければ
apm install hirakawaxxx/agent-config
apm compile                            # Claude / Codex / Cursor 向けファイルを生成
```

Copilot 以外のツールは `apm compile` を実行しないとルールを読み込まない。
リポジトリが非公開の場合は、環境変数 `GITHUB_APM_PAT` に GitHub トークンを設定する。

生成されるファイル:

- Claude Code: `.claude/rules/japanese-response.md`（`paths` 指定なしなので常に読み込まれる）
- Codex: `AGENTS.md`
- Cursor: `.cursor/rules/japanese-response.mdc` と `AGENTS.md`（Cursor は `AGENTS.md` も常に読む）

ルールは全体に効かせたいので `applyTo` を付けていない。`applyTo: "**"` を付けると、
Claude Code / Cursor では「ファイルを扱うときだけ読み込む」ルールになってしまう。

## CI

`.github/workflows/verify-install.yml` が、空のプロジェクトにこのパッケージを
`apm install` → `apm compile` して、上の3ファイルが生成されることを確認する。
非公開リポジトリから取得するため、リポジトリシークレット `APM_PAT`（agent-config を
読める fine-grained PAT）を `GITHUB_APM_PAT` として渡している。
