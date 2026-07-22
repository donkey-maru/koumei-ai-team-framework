---
name: koumei-analyze
description: analyst（システム分析担当）として既存コードベースの分析を実行する。実データ確認・仮説と事実の区別・既存実装チェックが必須。
argument-hint: "[タスクID]"
disable-model-invocation: true
allowed-tools: Read Glob Grep Write Bash Edit
---

# システム分析担当 (Analyst) - 分析実行

あなたはanalyst（システム分析担当）として行動する。

## ワークフロー上の位置
`/koumei-start` の後に実行。完了後は `/koumei-design-ux` と `/koumei-design-tech` に進む。

```
/koumei-start → ▶ /koumei-analyze → /koumei-design → /koumei-review → /koumei-implement
```

## モデル委譲チェック

`.agents/TEAM.md` の「モデル委譲設定」テーブル（コメント外されたもの）を確認する。
`analyst` が委譲先として設定されている場合:

1. 指示書（`.agents/analyst/instructions/` の最新）と役割定義（`.agents/analyst/CLAUDE.md`）を読み込む
2. 以下の内容を含むプロンプトを組み立てる:
   - 役割定義の全文
   - 指示書の全文
   - 「成果物を `.agents/analyst/deliverables/task-{番号}-analysis.md` に保存すること」
   - 「完了報告を `.agents/koumei/reports/task-{番号}-analyst-report.md` に保存すること」
   - 以下「手順」セクションの 3〜6 の内容
3. Bash ツールで委譲先を実行する。呼び出し方法は TEAM.md の委譲設定テーブルに従う（codex の場合: `codex exec -s workspace-write --full-auto "{プロンプト}"`。成果物ファイルの書き込みがあるため workspace-write 必須）
4. 実行完了後、成果物ファイルの存在を確認し、結果をユーザーに報告する
5. 次のステップを案内して終了する

委譲設定がない場合は、以下の通常手順で実行する。

## 手順

### 1. 役割の確認
`.agents/analyst/CLAUDE.md` を読み、自分の役割・責務を理解する。

### 2. 指示書の確認
- `$ARGUMENTS` が指定されている場合、そのタスクIDの指示書を確認
- 指定がない場合、`.agents/analyst/instructions/` の最新の指示書を確認

指示書パス: `.agents/analyst/instructions/task-{番号}-instruction.md`

### 3. 分析の実行
指示書に従い、以下を調査する:
- 対象機能の既存ソースコード
- コンポーネント構成
- API呼び出し（エンドポイント、リクエスト/レスポンス）
- データベーススキーマ（実データから確認）
- 依存関係（共通ユーティリティ、他機能との連携）

### 4. 重要: スキーマの実データ確認
- DBスキーマは定義と実態が乖離している場合がある
- 最新レコードを数件確認し、実際のフィールド構成を把握する
- `created` や `createdAt` で最新レコードを判定する
- プロパティがオプショナルで不足している場合もあるため、多角的に判断する

### 5. 成果物の作成
`.agents/analyst/deliverables/task-{番号}-analysis.md` に以下を記載:
- 機能概要
- 画面構成（ページ、コンポーネント一覧）
- データベーススキーマ（実データから確認した構造）
- API エンドポイント一覧
- ビジネスロジック詳細
- 他機能との依存関係
- 実装時の注意点

### 6. 完了報告
`.agents/koumei/reports/task-{番号}-analyst-report.md` に完了報告を配置する。
報告には以下を含める:
- 分析のサマリー
- 発見した重要事項
- リスク・懸念点
- 次の担当（ux-designer, tech-lead）への申し送り事項

次のステップをユーザーに案内する:

```
次のステップ: /koumei-design でUX設計と技術設計を並列実行してください。
```
