# koumei-ai-team-framework

Claude Code / Codex CLI / Antigravity CLI 対応のマルチエージェント開発フローシステム。
`target_cli` で展開先を切り替えられます（`"claude"` / `"codex"` / `"antigravity"`）。デフォルトは `claude`。

複数のAIエージェントロール（指揮者・技術リード・レビュアー等）が協調し、要件整理→タスク定義→分析→設計→レビュー→実装の段階的開発フローを実現します。

## 特徴

- **対話式セットアップ**: ウィザード形式で設定ファイルを自動生成
- **段階的開発フロー**: 要件整理→タスク定義→分析→設計→レビュー→実装の体系的なワークフロー
- **マルチエージェント協調**: 各ロールが専門領域に集中し、品質を担保
- **コア/オプション構成**: 最小3ロール（指揮者+技術+レビュー）から始め、必要に応じて拡張
- **技術スタック非依存**: 設定ファイルでプロジェクト固有の技術情報を注入
- **成果物出力先の設定**: プロジェクトごとに設計書・レビュー結果の保存先を指定可能
- **プロジェクト既存指示の尊重**: AGENTS.md / CLAUDE.md の指示がある場合はそちらを優先
- **コマンドプレフィックス変更可能**: `/koumei-start` を `/km-start` や `/dev-start` に変更可能

## クイックスタート

### 1. リポジトリをクローン

```bash
git clone <repository-url> /path/to/koumei-ai-team-framework
```

### 2. プロジェクトディレクトリでセットアップ実行

```bash
cd /path/to/my-project
/path/to/koumei-ai-team-framework/setup.sh
```

`koumei.config.yaml` がなければ**対話式ウィザード**が自動起動し、設定ファイルを生成します。

### 3. Claude Code でスキルコマンドを実行

```
/koumei-request "GA4アナリティクス計測設定"
```

要件が明確な場合は `/koumei-start` で直接タスクを開始することもできます。

## セットアップコマンド

```bash
setup.sh              # 初回セットアップ（config未存在時はウィザード起動）
setup.sh --init        # ウィザードを明示的に実行（config作成/上書き）
setup.sh --reconfig    # 既存プロジェクトの設定を見直す（--init のエイリアス）
setup.sh --roles       # ロール構成のみ変更（対話式）
setup.sh --cli         # 対象CLIのみ変更（codex/claude/antigravity、対話式）
setup.sh --update      # 最新テンプレで再展開（configは変更しない・成果物は保持）
                        # フレームワーク側に新しい設定項目が追加されている場合は
                        # 再生成せず --reconfig の実行を案内する
setup.sh --clean       # 展開済みファイルを削除
setup.sh --dry-run     # 実際にファイルを作成せずプレビュー
```

## ロール構成

### コアロール（必須）

| ロール | スキルコマンド | 説明 |
|--------|--------------|------|
| **Commander** (指揮者) | `request`, `start`, `status` | 要件整理・タスク定義・指示書作成・進捗管理 |
| **Tech Lead** (技術リード) | `design-tech`, `implement` | 技術設計・実装 |
| **Reviewer** (レビュアー) | `review` | 品質レビュー・ゲートキーパー |

### オプションロール

| ロール | スキルコマンド | 説明 |
|--------|--------------|------|
| **Analyst** (分析担当) | `analyze` | 既存コードベースの調査・分析。移行や大規模リファクタリングで有用 |
| **UX Designer** (UX担当) | `design-ux`, `design` | UI/UX設計。tech-leadと並列で設計を実行 |

ロール構成は後から `setup.sh --roles` で変更可能です。

## ワークフロー

### コア構成（3ロール）
```
/koumei-request → /koumei-start → /koumei-design-tech → /koumei-review → /koumei-implement → /koumei-review → /koumei-status
```

### フル構成（5ロール）
```
/koumei-request → /koumei-start → /koumei-analyze → /koumei-design（UX+技術 並列） → /koumei-review → /koumei-implement → /koumei-review → /koumei-status
```

## 成果物の出力先

`koumei.config.yaml` の `output` セクションで設定：

```yaml
output:
  dir: "docs-confidential"    # 設計書・レビュー結果の保存先
  format: "md"
  instructions: |
    - 同フォルダ内の既存 .md ファイルの書き方を参考にすること
```

### 指示の優先順位

1. **プロジェクトの AGENTS.md / CLAUDE.md** の記述（テックチーム管理）→ 最優先
2. **koumei.config.yaml** の `output.dir` 設定
3. **デフォルト**（`docs/`）

指示書・タスク定義・完了報告は `.agents/` 内（AI内部通信用）に配置されます。

## ディレクトリ構成（生成後）

◀◀◀ `target_cli` に応じたスキル配置先 ▶▶▶

### Claude Code (`target_cli: "claude"`) — デフォルト
```
プロジェクトルート/
├── .claude/skills/                ← スキルコマンド定義
│   ├── koumei-request/SKILL.md
│   ├── koumei-start/SKILL.md
│   └── ...
└── .agents/*/CLAUDE.md            ← エージェント指示ファイル
```

### Codex CLI (`target_cli: "codex"`)
```
プロジェクトルート/
├── .codex/skills/                 ← スキルコマンド定義
│   ├── koumei-request/SKILL.md
│   ├── koumei-start/SKILL.md
│   └── ...
└── .agents/*/AGENTS.md            ← エージェント指示ファイル
```

### Antigravity CLI (`target_cli: "antigravity"`)
```
プロジェクトルート/
├── .agents/skills/                ← スキルコマンド定義
│   ├── koumei-request/SKILL.md
│   ├── koumei-start/SKILL.md
│   └── ...
└── .agents/*/AGENTS.md            ← エージェント指示ファイル
```

### 共通ディレクトリ構成（全CLI共通）
```
プロジェクトルート/
├── koumei.config.yaml              ← プロジェクト固有の設定
├── .agents/                        ← AI内部通信
│   ├── TEAM.md                     ← チーム構成・ルール
│   ├── commander/
│   │   ├── AGENTS.md / CLAUDE.md   ← 指揮者の役割定義
│   │   ├── tasks/                  ← タスク定義書
│   │   ├── requests/               ← 要件整理の指示書
│   │   └── reports/                ← 各担当からの完了報告
│   ├── tech-lead/
│   │   ├── AGENTS.md / CLAUDE.md
│   │   └── instructions/           ← commanderからの指示
│   ├── reviewer/
│   │   ├── AGENTS.md / CLAUDE.md
│   │   └── instructions/
│   ├── analyst/                    ← オプション
│   └── ux-designer/                ← オプション
└── docs-confidential/              ← 成果物（output.dir で設定）
    ├── task-001-analysis.md
    ├── task-001-design.md
    └── task-001-review.md
```

## ドキュメント

- [設定ファイル詳細](docs/configuration.md)
- [カスタマイズガイド](docs/customization.md)
