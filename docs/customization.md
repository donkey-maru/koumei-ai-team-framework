# カスタマイズガイド

## ロール構成の変更

### オプションロールの追加

`koumei.config.yaml` の `roles` セクションでコメントを解除:

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
/path/to/koumei-system/setup.sh --update
```

### コア構成のみ（最小構成）

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
```

ワークフロー: `start → design-tech → review → implement → review → status`

### フル構成

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
  - analyst
  - ux-designer
```

ワークフロー: `start → analyze → design(並列) → review → implement → review → status`

## コマンドプレフィックスの変更

```yaml
skill_prefix: "km"
```

再セットアップ後、`/km-start`, `/km-review` 等で利用可能。

**注意**: プレフィックス変更前のスキルディレクトリは自動削除されません。必要に応じて手動削除するか、`--clean` 後に再セットアップしてください。

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
- commander の CLAUDE.md に移行元プロジェクトへの参照が追加
- analyst の CLAUDE.md に分析対象パスが追加

## テンプレートの直接編集

展開後のファイル（`.agents/*/CLAUDE.md`, `.claude/skills/*/SKILL.md`）を直接編集することも可能です。

**注意**: `setup.sh --update` を実行すると上書きされるため、カスタマイズは `custom_instructions` 経由で行うことを推奨します。
