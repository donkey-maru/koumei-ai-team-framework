# 設定ファイル詳細

`koumei.config.yaml` の全設定項目の説明。

対話式ウィザード（`setup.sh --init`）で自動生成することもできます。

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

`setup.sh --roles` で対話式にロール構成を変更できます。

### ロール別の影響

| ロール | 有効時に展開されるスキル | 無効時の影響 |
|--------|----------------------|-------------|
| `analyst` | `analyze` | 分析フェーズをスキップ |
| `ux-designer` | `design-ux`, `design`(並列オーケストレーター) | UX設計フェーズをスキップ、並列実行なし |

## target_cli

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `target_cli` | string | `"claude"` | 生成先CLI。`"claude"` は `.claude/skills` + `CLAUDE.md`、`"codex"` は `.codex/skills` + `AGENTS.md`、`"antigravity"` は `.agents/skills` + `AGENTS.md` を生成 |

### 例

```yaml
target_cli: "codex"
```

Claude Code 向けに従来形式で使う場合:

```yaml
target_cli: "claude"
```

Antigravity CLI 向けに使う場合:

```yaml
target_cli: "antigravity"
```

## skill_prefix

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `skill_prefix` | string | `"koumei"` | スキルコマンドの接頭辞 |

例:
- `"koumei"` → `/koumei-request`, `/koumei-start`, `/koumei-review`
- `"km"` → `/km-request`, `/km-start`, `/km-review`
- `"dev"` → `/dev-request`, `/dev-start`, `/dev-review`

## commander

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `name` | string | `"Commander"` | 指揮者のコードネーム |

## models

各ロールで使用するAIモデル。`target_cli` に合わせて、Codex CLI では `gpt-5.3-codex` 等、Claude Code では `sonnet` 等、Antigravity CLI では `gemini-3.5-pro` 等を指定します。

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `commander` | string | `"gpt-5.3-codex"` | 指揮者のモデル |
| `tech-lead` | string | `"gpt-5.3-codex"` | 技術リードのモデル |
| `reviewer` | string | `"gpt-5.3-codex"` | レビュアーのモデル |
| `analyst` | string | `"gpt-5.3-codex"` | 分析担当のモデル |
| `ux-designer` | string | `"gpt-5.3-codex"` | UXデザイナーのモデル |

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
| `check_command` | string | `""` | lint/format チェックコマンド（PR前に実行）。例: `"npm run check"`（Biome）。**空の場合はチェック工程をスキップ**（lint未導入プロジェクトでも安全） |

### check_command の挙動

`check_command` を設定すると、`/{prefix}-implement`（実装直後）と `/{prefix}-status`（PR提案前）で lint/format チェックが実行されます。

- 自動修正（`biome check --write` 等）で差分が出た場合は、その修正をコミット対象に含めて続行します（停止しません）。
- 自動修正で解消できない lint エラーが残った場合のみ修正対応し、最大2回で解決しなければ停止して報告します。
- 設定したコマンドが実行先プロジェクトに存在しない場合（`Missing script` 等）は、lint 未導入と判断してスキップします（失敗扱いにしません）。
- 空（`""`）の場合は、生成されるスキル・TEAM.md からチェック工程自体が省かれます。

## output

AIエージェントが生成する成果物（設計書・レビュー結果等）の出力先設定。

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `dir` | string | `"docs"` | 成果物の出力ディレクトリ（プロジェクトルート相対） |
| `format` | string | `"md"` | 出力形式（現在は md のみ） |
| `instructions` | string | `""` | 成果物に関する追加指示 |

### 指示の優先順位

成果物の出力先は以下の優先順位で決定されます：

1. **プロジェクトの AGENTS.md / CLAUDE.md** に出力先の記述がある場合 → 最優先
2. **koumei.config.yaml** の `output.dir` 設定
3. **デフォルト**（`docs-official/`）

### 例

```yaml
output:
  dir: "docs-confidential"
  format: "md"
  instructions: |
    - 同フォルダ内の既存 .md ファイルの書き方を参考にすること
    - 見出しレベルは ## から開始すること
```

## git

| キー | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `main_branch` | string | `"main"` | メインブランチ名 |
| `develop_branch` | string | `""` | 開発ブランチ名（空なら直接mainへ） |
| `feature_prefix` | string | `"feature/"` | featureブランチの接頭辞 |
| `branch_pattern` | string | `"feature/task-{number}-{summary}"` | ブランチ命名パターン |

## custom_instructions

各ロールの指示ファイル（Codex CLI では `AGENTS.md`、Claude Code では `CLAUDE.md`）に追記されるカスタム指示。YAML複数行記法（`|`）を使用。

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
