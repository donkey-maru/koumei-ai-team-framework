# koumei-system

Claude Code 向けマルチエージェント開発フローシステム。

複数のAIエージェントロール（指揮者・技術リード・レビュアー等）が協調し、タスク定義→分析→設計→レビュー→実装の段階的開発フローを実現します。

## 特徴

- **段階的開発フロー**: タスク定義→分析→設計→レビュー→実装の体系的なワークフロー
- **マルチエージェント協調**: 各ロールが専門領域に集中し、品質を担保
- **コア/オプション構成**: 最小3ロール（指揮者+技術+レビュー）から始め、必要に応じて拡張
- **技術スタック非依存**: 設定ファイルでプロジェクト固有の技術情報を注入
- **コマンドプレフィックス変更可能**: `/koumei-start` を `/km-start` や `/dev-start` に変更可能

## クイックスタート

### 1. リポジトリをクローン

```bash
git clone <repository-url> /path/to/koumei-system
```

### 2. 設定ファイルを作成

プロジェクトルートに `koumei.config.yaml` を作成:

```bash
cp /path/to/koumei-system/koumei.config.example.yaml ./koumei.config.yaml
```

プロジェクトに合わせて編集してください。

### 3. セットアップ実行

```bash
/path/to/koumei-system/setup.sh
```

これにより `.agents/` と `.claude/skills/` にファイルが展開されます。

### 4. Claude Code でスキルコマンドを実行

```
/koumei-start "新規タスクの概要"
```

## ロール構成

### コアロール（必須）

| ロール | スキルコマンド | 説明 |
|--------|--------------|------|
| **Commander** (指揮者) | `start`, `status` | タスク定義・指示書作成・進捗管理 |
| **Tech Lead** (技術リード) | `design-tech`, `implement` | 技術設計・実装 |
| **Reviewer** (レビュアー) | `review` | 品質レビュー・ゲートキーパー |

### オプションロール

| ロール | スキルコマンド | 説明 |
|--------|--------------|------|
| **Analyst** (分析担当) | `analyze` | 既存コードベースの分析 |
| **UX Designer** (UX担当) | `design-ux`, `design` | UI/UX設計・並列設計オーケストレーション |

## ワークフロー

### コア構成（3ロール）
```
/koumei-start → /koumei-design-tech → /koumei-review → /koumei-implement → /koumei-review → /koumei-status
```

### フル構成（5ロール）
```
/koumei-start → /koumei-analyze → /koumei-design（UX+技術 並列） → /koumei-review → /koumei-implement → /koumei-review → /koumei-status
```

## 設定変更後の更新

設定を変更した場合は再度セットアップを実行:

```bash
/path/to/koumei-system/setup.sh --update
```

成果物ファイル（tasks/, deliverables/, reviews/ 等）は保持されます。

## ドキュメント

- [設定ファイル詳細](docs/configuration.md)
- [カスタマイズガイド](docs/customization.md)
