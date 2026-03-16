# 設定ファイル詳細

`koumei.config.yaml` の全設定項目の説明。

## project（必須）

| キー | 型 | 必須 | 説明 |
|------|-----|------|------|
| `name` | string | yes | プロジェクト名 |
| `description` | string | yes | プロジェクトの概要 |
| `path` | string | yes | プロジェクトのルートパス（通常 `.`） |

## migration（任意）

既存システムからの移行プロジェクトの場合に設定。

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `enabled` | boolean | `false` | 移行モードを有効にする |
| `source_path` | string | `""` | 移行元プロジェクトのパス |
| `source_framework` | string | `""` | 移行元のフレームワーク名 |
| `target_framework` | string | `""` | 移行先のフレームワーク名 |

`enabled: true` にすると、テンプレートに移行元プロジェクトへの参照が追加されます。

## roles（必須）

有効にするロール一覧。コアロール3つは必須。

```yaml
roles:
  - commander      # 必須: 指揮者
  - tech-lead      # 必須: 技術リード
  - reviewer        # 必須: レビュアー
  - analyst         # 任意: 分析担当
  - ux-designer     # 任意: UXデザイナー
```

### ロール別の影響

| ロール | 有効時に展開されるスキル | 無効時の影響 |
|--------|----------------------|-------------|
| `analyst` | `analyze` | 分析フェーズをスキップ |
| `ux-designer` | `design-ux`, `design`(並列オーケストレーター) | UX設計フェーズをスキップ、並列実行なし |

## skill_prefix

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `skill_prefix` | string | `"koumei"` | スキルコマンドの接頭辞 |

例:
- `"koumei"` → `/koumei-start`, `/koumei-review`
- `"km"` → `/km-start`, `/km-review`
- `"dev"` → `/dev-start`, `/dev-review`

## commander

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `name` | string | `"Commander"` | 指揮者のコードネーム |

## models

各ロールで使用するAIモデル。

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `commander` | string | `"sonnet"` | 指揮者のモデル |
| `tech-lead` | string | `"opus"` | 技術リードのモデル |
| `reviewer` | string | `"opus"` | レビュアーのモデル |
| `analyst` | string | `"sonnet"` | 分析担当のモデル |
| `ux-designer` | string | `"sonnet"` | UXデザイナーのモデル |

## tech_stack

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `language` | string | `""` | プログラミング言語 |
| `framework` | string | `""` | フレームワーク |
| `ui_library` | string | `""` | UIライブラリ |
| `styling` | string | `""` | スタイリング手法 |
| `database` | string | `""` | データベース |
| `testing` | string | `""` | テストフレームワーク |
| `build_command` | string | `"npm run build"` | ビルドコマンド |
| `test_command` | string | `"npm run test"` | テストコマンド |
| `dev_command` | string | `"npm run dev"` | 開発サーバーコマンド |

## git

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `main_branch` | string | `"main"` | メインブランチ名 |
| `develop_branch` | string | `""` | 開発ブランチ名（空なら直接mainへ） |
| `feature_prefix` | string | `"feature/"` | featureブランチの接頭辞 |
| `branch_pattern` | string | `"feature/task-{number}-{summary}"` | ブランチ命名パターン |

## custom_instructions

各ロールのCLAUDE.mdに追記されるカスタム指示。YAML複数行記法（`|`）を使用。

```yaml
custom_instructions:
  tech-lead: |
    - RSC ファースト
    - DTO シリアライゼーション必須
```

## reference_docs

各ロールが参照すべきドキュメントのリスト。

```yaml
reference_docs:
  - path: "docs/architecture.md"
    description: "アーキテクチャ設計書"
```
