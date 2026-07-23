# カスタマイズガイド

## 基本原則

このフレームワークの生成物（TEAM.md・ロール定義・スキル）は `koumei.config.yaml` からの生成物。カスタマイズは原則 **config 経由**で行い、`setup.sh --update` で反映する。

- 生成された `.agents/{ロール}/CLAUDE.md`（codex/antigravity では `AGENTS.md`）や `SKILL.md` を直接編集した場合、Git にコミットしておけば `--update` で上書きされない（Git 管理下スキップ）
- **例外: `.agents/TEAM.md` は常に強制再生成される**（上書き前のバックアップは `.agents/.backup/` へ）。TEAM.md への手動カスタマイズは維持されないため、必ず config 経由で変更すること

## ロール構成の変更

```bash
setup.sh --roles     # analyst / ux-designer の有効・無効を対話式で変更
```

無効化したロールのスキル・ワークスペース・TEAM.md 記載は生成されず、ワークフロー上も該当フェーズがスキップされる。

## ロール別カスタム指示（custom_instructions）

プロジェクト固有の指示を各ロールの役割定義に注入する。もっとも使用頻度の高いカスタマイズ。

```yaml
custom_instructions:
  tech-lead: |
    - RSC ファースト: Server Components をデフォルト
    - DTO シリアライゼーション: Server→Client 境界で必ず DTO 化
  devils-advocate: |
    - OWASP Top 10 を重点レビュー
    - Firestore のセキュリティルール確認
```

## カスタムロールの追加

api-designer / data-engineer / infra-architect のテンプレートが `.agents/custom-roles/` に展開される。有効化手順:

1. `cp -r .agents/custom-roles/{ロール名} .agents/{ロール名}`（または新規に役割定義を作成）
2. `mkdir -p .agents/{ロール名}/instructions .agents/{ロール名}/deliverables`
3. TEAM.md「チーム構成」テーブルへの行追加は config 化されていないため、`.agents/custom-roles/README.md` の手順を参照

`/koumei-start` は TEAM.md のチーム構成テーブルにある標準5ロール以外のロールをカスタムロールとして自動検出し、指示書を作成する。

> ⚠️ **既知の制約**: TEAM.md は `--update` のたびに強制再生成されるため、手動で追加したカスタムロール行は消える（直前の内容は `.agents/.backup/` に保存される）。`--update` 後は行を再追記すること。チーム構成テーブルの config 化（恒久解）は今後のフェーズで対応予定。

## レビューのカスタマイズ

```yaml
review:
  mode: "economy"    # codex → lmstudio → claude の節約3段構成
  timeout: 900
```

- セキュリティ監査: `/koumei-review --security`（OWASP Top10 + STRIDE、スコア8/10未満で強制差し戻し）
- セカンドオピニオン: `/koumei-review --second-opinion`（TEAM.md「セカンドオピニオン設定」テーブルの有効化が必要）
- 一時モデル切替: `/koumei-review --model grok` 等

## 外部CLIモデル・モデル委譲（上級）

外部CLIモデル定義・モデル委譲設定・セカンドオピニオン設定は、現状 TEAM.md 内のテーブル（デフォルトはコメントアウト）で管理される。

**既知の制約**: TEAM.md は `--update` で強制再生成されるため、これらのテーブルを直接編集しても再生成時に失われる（バックアップは `.agents/.backup/` に残る）。恒久的に有効化したい場合は、フレームワーク側の `templates/agents/TEAM.md.tmpl` を編集するか、config 化（今後のフェーズで対応予定）を待つこと。

## PR前 lint ゲート（check_command）

```yaml
tech_stack:
  check_command: "npm run check"   # Biome の例。ESLint なら "npm run lint"
```

設定すると `/koumei-implement` の完了条件に「チェックが通ること」が追加され、実装フェーズはチェックが通るまで完了報告に進めない。lint 未導入プロジェクトでは空のままにすればゲートごとスキップされる。

## Hooks のカスタマイズ（claude ターゲット限定）

`hooks/` に配布される4スクリプトは Git にコミットすれば `--update` で上書きされない（自作フックの追加も自由。`--clean` はフレームワーク由来の4本だけを削除する）。

| Hook | 役割 |
|------|------|
| quality-gate.sh | TEAM.md の直接編集をブロック |
| log-operation.sh | 全ツール操作を `.agents/logs/YYYY-MM-DD.jsonl` に記録 |
| auto-format.sh | 保存時 prettier 自動実行（.md は除外） |
| notify-phase.sh | 成果物/レビュー/報告の書き込みを macOS 通知 |

## スキルプレフィックスの変更

```yaml
skill_prefix: "km"    # /km-start, /km-review ...
```

スキルディレクトリ名・frontmatter の name・スキル間相互参照・手順書内パスのすべてが追従する。

## 移行プロジェクト設定

```yaml
migration:
  enabled: true
  source_path: "~/projects/legacy-app"
  source_framework: "Nuxt 2"
  target_framework: "Next.js 15"
```

> ⚠️ **現バージョンでは未配線**: 記録されるのみで生成テンプレートはまだ参照しない（今後のフェーズで配線予定）。
