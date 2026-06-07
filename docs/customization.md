# カスタマイズガイド

## ロール構成の変更

### 対話式で変更（推奨）

```bash
/path/to/koumei-ai-team-framework/setup.sh --roles
```

現在のロール構成が表示され、各ロールの説明を見ながら ON/OFF を選択できます。

### 手動で変更

`koumei.config.yaml` の `roles` セクションを編集:

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
  - analyst         # 追加
  - ux-designer     # 追加
```

変更後に再セットアップ:
```bash
/path/to/koumei-ai-team-framework/setup.sh --update
```

### コア構成のみ（最小構成）

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
```

ワークフロー: `request → start → design-tech → review → implement → review → status`

### フル構成

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
  - analyst
  - ux-designer
```

ワークフロー: `request → start → analyze → design(並列) → review → implement → review → status`

## コマンドプレフィックスの変更

```yaml
skill_prefix: "km"
```

再セットアップ後、`/km-request`, `/km-start`, `/km-review` 等で利用可能。

**注意**: プレフィックス変更前のスキルディレクトリは自動削除されません。必要に応じて手動削除するか、`--clean` 後に再セットアップしてください。

## 成果物の出力先変更

```yaml
output:
  dir: "docs-confidential"
  format: "md"
  instructions: |
    - 同フォルダ内の既存 .md ファイルの書き方を参考にすること
```

### プロジェクト既存の指示との共存

プロジェクトの `AGENTS.md` や `CLAUDE.md` に成果物出力先の指示が既にある場合、**そちらが優先**されます。`koumei.config.yaml` の設定はフォールバックとして機能します。

## カスタム指示の追加

各ロールにプロジェクト固有の指示を追加できます:

```yaml
custom_instructions:
  tech-lead: |
    ## プロジェクト固有ルール
    - Server Components をデフォルトにする
    - Firestore Timestamp は必ず ISO 文字列に変換
    - any 型の使用禁止
  reviewer: |
    ## 追加レビュー観点
    - Firestore セキュリティルールの確認
    - Server Actions のバリデーション漏れチェック
```

## 移行プロジェクトでの利用

既存システムからの移行を行う場合:

```yaml
migration:
  enabled: true
  source_path: "../old-project"
  source_framework: "Nuxt 2"
  target_framework: "Next.js 15"
```

これにより:
- TEAM.md に移行元/先プロジェクト情報が追記
- commander の指示ファイルに移行元プロジェクトへの参照が追加
- analyst の指示ファイルに分析対象パスが追加

## 設定の再作成

設定ファイルを最初から作り直したい場合:

```bash
/path/to/koumei-ai-team-framework/setup.sh --init
```

対話式ウィザードが起動し、`koumei.config.yaml` を再生成します。

## テンプレートの直接編集

展開後のファイル（`.agents/*/AGENTS.md`, `.codex/skills/*/SKILL.md`）を直接編集することも可能です。
`target_cli: "claude"` の場合は `.agents/*/CLAUDE.md`, `.claude/skills/*/SKILL.md` が対象です。

**注意**: `setup.sh --update` を実行すると上書きされるため、カスタマイズは `custom_instructions` 経由で行うことを推奨します。
