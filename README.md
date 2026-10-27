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

- Claude Code: `.claude/rules/japanese-response.md`
- Codex: `AGENTS.md`
- Cursor: `.cursor/rules/japanese-response.mdc`
