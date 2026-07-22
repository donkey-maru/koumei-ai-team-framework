# エージェントチーム構成

## プロジェクト: {{PROJECT_NAME}}

### スキルコマンド一覧

全ての指示出しはスキルコマンドで実行する。ロールの切り替えは不要。

| コマンド | 役割 | 説明 |
|---------|------|------|
| `/koumei-start {要件}` | 諸葛孔明 | タスク定義・全担当への指示書作成 |
| `/koumei-analyze [タスクID]` | analyst | 既存コードベースの分析 |
| `/koumei-design [タスクID]` | **ux-designer + tech-lead** | UX設計と技術設計を**並列実行** |
| `/koumei-review [タスクID]` | devils-advocate | 全成果物のレビュー |
| `/koumei-implement [フェーズ番号]` | tech-lead | 実装（レビュー通過後） |
| `/koumei-status` | 諸葛孔明 | 進捗確認・次のアクション提案 |

個別実行（差し戻し時の再実行用）:

| コマンド | 役割 | 説明 |
|---------|------|------|
| `/koumei-design-ux [タスクID]` | ux-designer | UX設計のみ単独実行 |
| `/koumei-design-tech [タスクID]` | tech-lead | 技術設計のみ単独実行 |

### チーム構成

| 役割 | コードネーム | ワークスペース | 責務 | モデル |
|------|------------|--------------|------|--------|
| **最高指揮者** | 諸葛孔明 (koumei) | `.agents/koumei/` | 全体統括、タスク分割、指示出し、最終判断 | sonnet |
| **システム分析担当** | analyst | `.agents/analyst/` | 既存コード・API・DB分析 | sonnet |
| **UXデザイン担当** | ux-designer | `.agents/ux-designer/` | UI設計、画面遷移設計、レスポンシブ対応 | sonnet |
| **技術アーキテクチャ&実装担当** | tech-lead | `.agents/tech-lead/` | 技術設計・実装 | **fable**（設計）/ **opus**（実装） |
| **悪魔の代弁者** | devils-advocate | `.agents/devils-advocate/` | 全成果物のレビュー・問題提起 | **fable** |

#### モデル指定の仕組み

オーケストレーター（`/koumei-start` の各Phase、`/koumei-design`、`/koumei-review`）は、サブエージェント起動時に上記テーブルの「モデル」列を Agent tool の `model` パラメータに指定する。モデル列を書き換えるだけで、全スキルの起動モデルが変わる。

- 指定可能な値: `haiku` / `sonnet` / `opus` / `fable`（またはフルモデルID）、および下記「外部CLIモデル定義」に登録した外部モデル名（`grok` / `codex` 等）
- **外部CLIモデルを指定した場合**: オーケストレーターは Agent tool ではなく Bash 経由でその CLI を呼び出す。CLI が利用不可（`command -v` で不在）の場合は Claude の既定モデルにフォールバックし、その旨を報告する
- **配置の原則**: 高単価モデルは「トークン量が多い場所」ではなく「判断のレバレッジが高く出力が小さい場所」に置く
  - **devils-advocate = fable**: レビューVERDICTがフロー全体（差し戻しループ）を制御する品質ゲートであり、誤判定のコストが最も高い
  - **tech-lead 設計 = fable / 実装 = opus**: 設計ミスは実装で増幅される。実装はトークン量が多いため opus（または Codex 委譲）
  - **koumei / analyst / ux-designer = sonnet**: オーケストレーションは機械的、分析は読み取り中心

#### 外部CLIモデル定義

モデル列・レビューモデル・セカンドオピニオンで外部CLIモデルを使う場合の呼び出し方法。使用する CLI の仕様に合わせて編集してください。

| モデル名 | 呼び出し方法 | 備考 |
|---------|------------|------|
| codex | `codex exec "{プロンプト}"` | OpenAI Codex CLI。モデルは `~/.codex/config.toml` の `model` に従う |
| gpt-5.6-sol | `codex exec -m gpt-5.6-sol "{プロンプト}"` | codex CLI 経由でモデルを固定する例。`-m {モデルID}` で任意のモデルを登録できる |
| grok | `grok -p "{プロンプト}"` | xAI Grok CLI（grok-4.5 等）。インストール済みの場合のみ |
| gemini | `gemini "{プロンプト}"` | Google Gemini CLI |

**サンドボックスの注意**: codex CLI の既定サンドボックスは読み取り専用。**ファイル書き込みを伴う委譲（分析成果物の保存・実装）では `-s workspace-write --full-auto` を追加する**こと（例: `codex exec -s workspace-write --full-auto "{プロンプト}"`）。レビュー・セカンドオピニオンのように標準出力を呼び出し元が受け取って保存する用途では不要。

利用可否は CLI 本体の存在（例: `command -v codex`）で確認し、不可の場合は Claude にフォールバックして報告する。

### カスタムロール（オプション）

プロジェクト特性に応じてカスタムロールを追加できます。以下のテンプレートを参考に定義してください。

<!-- 必要に応じてカスタムロールを追加 -->
<!-- | **カスタムロール名** | custom-role-name | `.agents/custom-role-name/` | 責務の説明 | sonnet | -->

#### カスタムロールの追加手順

1. `.agents/{ロール名}/CLAUDE.md` を作成（下記テンプレート参照）
2. 上記「チーム構成」テーブルにロールを追記
3. 必要に応じて `/koumei-start` の指示書生成にロールを含める

#### カスタムロール CLAUDE.md テンプレート

```text
# {ロール名} CLAUDE.md

## 役割
{このロールの責務を記載}

## 責務
1. {責務1}
2. {責務2}

## 成果物フォーマット
{成果物の形式を記載}

## ワークスペース
- 指示書: `.agents/{ロール名}/instructions/`
- 成果物: `.agents/{ロール名}/deliverables/`
- 完了報告: `.agents/koumei/reports/`
```

### モデル委譲設定（トークン節約・オプション）

サブエージェントの一部を外部モデル（Codex等）に委譲し、Claudeトークンを節約できます。

<!-- 必要に応じてコメントを外し、委譲するロールを設定 -->
<!--
| 役割 | 委譲先 | 呼び出し方法 | 対象フェーズ |
|------|--------|------------|------------|
| analyst | codex | `codex exec -s workspace-write --full-auto "{プロンプト}"` | 分析（/koumei-analyze） |
| tech-lead | codex | `codex exec -s workspace-write --full-auto "{プロンプト}"` | 実装（/koumei-implement） |
-->

**有効化方法**: 上記テーブルのコメントを外し、委譲するロールを記載してください。
委譲未設定のロールは通常通りClaudeサブエージェントとして実行されます。

**委譲に適さないロール（Claude推奨）:**
- **koumei** — オーケストレーション（Claude Agent APIが必要）
- **ux-designer** — 創造的なUX判断が多い
- **devils-advocate** — 品質ゲートは信頼性重視

### レビューモデル設定

レビュー（devils-advocate）の実行モデルを設定する。
上から順に優先度が高い。利用可能な最優先モデルが使用される。

| 優先度 | モデル | 呼び出し方法 | 条件 |
|--------|--------|------------|------|
| 1 | codex | `/codex:review --wait` | codex スキルが利用可能 |
| 2 | lmstudio | `mcp__lmstudio-mcp__chat_completion` | 節約モード時 (`review_mode: economy`) |
| 3 | claude | Agent ツール（モデルは「チーム構成」の devils-advocate 列。既定: fable） | 常に利用可能 |
| - | grok | grok CLI（「外部CLIモデル定義」参照） | `--model grok` 指定時。常用したい場合はこの表の優先度に組み込む |

#### レビューモード

```
review_mode: default
review_timeout: 600
```

- `default` — 優先度順（codex → claude）
- `economy` — lmstudio-mcp を優先（codex → lmstudio → claude）
- `claude-only` — 常に Claude（devils-advocate のモデル列。既定: fable）を使用
- `review_timeout` — codex / lmstudio レビューの制限時間（秒）。超過したら中断し、次の優先モデルにフォールバックする
- 一時的な切り替えは `/koumei-review --model claude` のように `--model` フラグで指定できる（TEAM.md の編集不要）

### セカンドオピニオン設定（オプション）

Devil's Advocateレビュー時に、Claude以外のモデルによるセカンドオピニオンを取得できます。

<!-- 必要に応じてセカンドオピニオンモデルを設定 -->
<!--
| モデル名 | プロバイダー | 呼び出し方法 |
|---------|------------|------------|
| codex | OpenAI | `codex exec "{プロンプト}"` |
| grok | xAI | `grok -p "{プロンプト}"` |
| gemini | Google | `gemini "{プロンプト}"` |
-->

**有効化方法**: 上記テーブルのコメントを外し、使用するモデルを記載してください。
セカンドオピニオンが未設定の場合、`/koumei-review` は通常のClaude単独レビューとして動作します。

### マルチタスク実行（オプション）

`/koumei-start {要件} --multi` で、独立した複数タスクを並列実行できます。

- 諸葛孔明が要件を複数タスクに分割し、タスクごとに **task-manager（部将）** サブエージェントを起動
- 各 task-manager は git worktree 内で Phase 1〜7 のパイプラインを完遂し、PR作成まで行う
- 依存関係・ファイル競合のあるタスクは直列実行される
- **前提**: Claude Code v2.1.172 以降（サブエージェントのネスト起動）、`.agents/`・`.claude/` がリポジトリにコミットされていること
- 詳細手順: `.claude/skills/koumei-start/docs/multi-task.md` / 役割定義: `.agents/task-manager/CLAUDE.md`

### ワークフロー（スキル駆動）

```
【設計フェーズ】
1. /koumei-start {要件}       → タスク定義・指示書を自動生成
2. /koumei-analyze             → 既存システム分析
3. /koumei-design              → UX設計 + 技術設計を並列実行
4. /koumei-review              → 全成果物レビュー
   → 差し戻し: /koumei-design-ux or /koumei-design-tech で個別再実行 → /koumei-review

【実装フェーズ】
5. /koumei-implement           → 実装（レビュー通過後のみ実行可能）
6. /koumei-review              → コードレビュー

【検証フェーズ】
7. /koumei-status              → 最終進捗確認
8. 動作確認 → メインブランチへ PR

※ 迷ったら /koumei-status で次のアクションを確認
```

### 対象プロジェクト

<!-- 自プロジェクトに合わせて編集 -->

| プロジェクト | パス | フレームワーク | 役割 |
|------------|------|--------------|------|
| **{{PROJECT_1}}** | `{{PROJECT_1_PATH}}` | {{FRAMEWORK_1}} | {{ROLE_1}} |
| **{{PROJECT_2}}** | `{{PROJECT_2_PATH}}` | {{FRAMEWORK_2}} | {{ROLE_2}} |

### 通信アーキテクチャ

<!-- 自プロジェクトのアーキテクチャに合わせて編集 -->

```
[クライアント] --> [APIサーバー] --> [データベース]
```

### 指示書・報告書の命名規則

- タスク定義: `{タスクID}.md` (例: `task-001.md`)
- 指示書: `{タスクID}-instruction.md` (例: `task-001-instruction.md`)
- 成果物: `{タスクID}-{種類}.md` (例: `task-001-analysis.md`)
- 分析レビュー: `{タスクID}-analysis-review.md` (例: `task-001-analysis-review.md`)
- 設計レビュー: `{タスクID}-design-review.md` (例: `task-001-design-review.md`)
- コードレビュー: `{タスクID}-code-review.md` (例: `task-001-code-review.md`)
- 完了報告: `{タスクID}-{担当名}-report.md` (例: `task-001-analyst-report.md`)

### 開発規約

<!-- プロジェクト固有の開発規約を記載 -->

- コミットメッセージに自動生成マーカーやCo-Authored-Byを含めない
