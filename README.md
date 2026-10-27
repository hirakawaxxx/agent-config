# agent-config

個人用の [APM (Agent Package Manager)](https://github.com/microsoft/apm) パッケージ。
Claude Code / Codex / Cursor 向けのエージェント設定をまとめて配布する。

## 中身

| ファイル | 内容 |
|---|---|
| `apm.yml` | マニフェスト（対象: `claude`, `codex`, `cursor`） |
| `.apm/instructions/japanese-response.instructions.md` | 日本語で返答するルール |

## 取り込んでいる外部スキル

`apm.yml` の `dependencies.apm` で、バージョンを固定して取り込んでいる。
Claude Code には `.claude/skills/`、Codex / Cursor には `.agents/skills/` に配置される。

| スキル | 取得元 | ライセンス |
|---|---|---|
| `pdf` / `pptx` / `xlsx` | [anthropics/skills](https://github.com/anthropics/skills)（コミット固定） | ソース公開（非オープンソース）。個人利用 |
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
