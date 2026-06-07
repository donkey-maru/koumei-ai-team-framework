# koumei-ai-team-framework

Codex CLI 向けマルチエージェント開発フローシステム。
`target_cli: "claude"` を指定すると、従来どおり Claude Code 向けにも展開できます。

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

### 3. Codex CLI でスキルコマンドを実行

```
/koumei-request "GA4アナリティクス計測設定"
```

要件が明確な場合は `/koumei-start` で直接タスクを開始することもできます。

## セットアップコマンド

```bash
setup.sh              # 初回セットアップ（config未存在時はウィザード起動）
setup.sh --init        # ウィザードを明示的に実行（config作成/上書き）
setup.sh --roles       # ロール構成のみ変更（対話式）
setup.sh --update      # 設定変更後の再展開（成果物は保持）
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

```
プロジェクトルート/
├── koumei.config.yaml              ← プロジェクト固有の設定
├── .agents/                        ← AI内部通信
│   ├── TEAM.md                     ← チーム構成・ルール
│   ├── commander/
│   │   ├── AGENTS.md               ← 指揮者の役割定義
│   │   ├── tasks/                  ← タスク定義書
│   │   ├── requests/               ← 要件整理の指示書
│   │   └── reports/                ← 各担当からの完了報告
│   ├── tech-lead/
│   │   ├── AGENTS.md
│   │   └── instructions/           ← commanderからの指示
│   ├── reviewer/
│   │   ├── AGENTS.md
│   │   └── instructions/
│   ├── analyst/                    ← オプション
│   └── ux-designer/                ← オプション
├── .codex/skills/                 ← スキルコマンド定義
│   ├── koumei-request/SKILL.md
│   ├── koumei-start/SKILL.md
│   ├── koumei-design-tech/SKILL.md
│   ├── koumei-review/SKILL.md
│   ├── koumei-implement/SKILL.md
│   ├── koumei-status/SKILL.md
│   └── ...（オプションロール分）
└── docs-confidential/              ← 成果物（output.dir で設定）
    ├── task-001-analysis.md
    ├── task-001-design.md
    └── task-001-review.md
```

## ドキュメント

- [設定ファイル詳細](docs/configuration.md)
- [カスタマイズガイド](docs/customization.md)
