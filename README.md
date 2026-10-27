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

- 配置先: Claude Code は `.claude/settings.json`、Codex は `.codex/hooks.json`。
  Cursor は `.claude/settings.json` のフックを読み込むので、二重に鳴らないよう Cursor には配らない
  （ファイル名末尾の `-claude-codex-hooks` で配布先を指定している）。
- 再生方法と音源は [pascalporedda/awesome-claude-code](https://github.com/pascalporedda/awesome-claude-code)
  （MIT License, Copyright (c) 2024 Pascal Weinberger）を元にしている。元のフックにある会話ログの保存、
  `npx tsx` での実行、権限設定は取り込んでいない。

## 取り込んでいる外部スキル

`apm.yml` の `dependencies.apm` で、バージョンを固定して取り込んでいる。
Claude Code には `.claude/skills/`、Codex / Cursor には `.agents/skills/` に配置される。

| スキル | 取得元 | ライセンス |
|---|---|---|
| `pdf` / `pptx` / `xlsx` | [anthropics/skills](https://github.com/anthropics/skills)（コミット固定） | ソース公開（非オープンソース）。個人利用 |
| `skill-creator` / `mcp-builder` | [anthropics/skills](https://github.com/anthropics/skills)（コミット固定） | Apache 2.0 |
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
