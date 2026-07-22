# koumei 統合検討資料: koumei-origin × koumei-ai-team-framework 機能比較

> 目的: 2つのマルチエージェント開発フレームワークの機能比較（統合方針検討の基礎資料）。
>
> - **origin** = `kuruusuniku/koumei`（上流OSS・MIT。以下 origin）
> - **framework** = `donkey-maru/koumei-ai-team-framework`（本リポジトリ。以下 framework）
>
> **統合方針・実行計画は `integration-proposal-origin-base.md` を参照**（本資料は比較のみ）。

---

## 1. 一言でいうと

| | origin | framework |
|---|---|---|
| 強い領域 | **チーム運用の実戦ノウハウ**（レビュー体制・モデル経済・Hooks・並列実行） | **配布と設定のエンジン**（config駆動・ウィザード・マルチCLI展開・更新機構） |
| 思想 | Claude Code 上での運用を深く最適化 | 複数CLI・複数プロジェクトへの展開を容易に |

推奨統合方針: **「エンジンは framework、プレイブックは origin」**
（配布・設定機構は framework をベースに、ロール定義・レビュー運用・Hooks 等の中身は origin から移植）

---

## 2. 詳細比較マトリクス

### 2.1 配布・セットアップ

| 項目 | origin | framework |
|---|---|---|
| セットアップ | `setup.sh /path`：ファイルコピー + settings.json の jq マージのみ | 対話式ウィザード（技術スタック自動検出付き）で config 生成 → テンプレート変数展開 |
| 設定ファイル | **なし**。`TEAM.md` 内の Markdown 表が実質の設定。プレースホルダ（`{{PROJECT_NAME}}` 等）は**手動置換** | `koumei.config.yaml`（プロジェクト情報 / ロール / モデル / 技術スタック / Git運用 / 出力先 / カスタム指示） |
| 更新機構 | **なし**（再コピーのみ、上書き確認あり） | `--update`（config差分検知付き再生成）/ `--reconfig` / `--roles` / `--cli` / `--clean` / `--dry-run` |
| 既存ファイル保護 | 上書き y/N 確認のみ | Git管理下ファイルは上書きスキップ、管理外はバックアップ後に上書き |
| 対象CLI | Claude Code 専用 | **claude / codex / antigravity** の3CLIに展開可能（`target_cli`） |

### 2.2 ロール構成・命名

| 概念 | origin | framework |
|---|---|---|
| 指揮者 | `koumei`（諸葛孔明ペルソナ。軍事メタファー: タスク=戦、レビュー=軍議 等） | `commander`（コードネームは config で変更可、デフォルト "Commander"） |
| レビュアー | `devils-advocate`（悪魔の代弁者） | `reviewer` |
| 分析 / UX / 技術 | `analyst` / `ux-designer` / `tech-lead`（全ロール常設） | 同名（analyst / ux-designer は**オプションロール**、config で有効化） |
| 並列実行単位 | `task-manager`（部将）— マルチタスク時のみの使い捨て実行役 | なし |
| カスタムロール | テンプレート3種同梱（api-designer / data-engineer / infra-architect）+ 実行時自動検出 | なし |

### 2.3 スキル・ワークフロー

| スキル | origin | framework |
|---|---|---|
| 要件整理 | **なし**（koumei-start が要件から直接タスク化） | `koumei-request`（対話で要件整理 → requests/ に指示書） |
| タスク開始 | `koumei-start`（全自動 / `--manual` / `--multi` を内包） | `koumei-start`（タスク定義・指示書作成のみ） |
| 全自動実行 | koumei-start に統合 | `koumei-run`（独立スキル。フェーズ別モデル振り分け） |
| 分析 / 設計 / レビュー / 実装 / 進捗 | analyze / design(並列) / design-ux / design-tech / review / implement / status | 同構成 |
| タスク種別による省略 | あり（軽微修正=Phase1-4スキップ、バグ修正小=Phase3-4スキップ等。**コードレビューは絶対に省略しない**） | なし（フロー固定） |
| `disable-model-invocation` | **全スキル true**（`/`手動起動のみ） | **全スキルから削除済み**（モデル自動起動を許可） |
| lint/format ゲート | auto-format hook（prettier、保存時自動） | `check_command` 設定（PR前に lint 実行、空ならスキップ） |

### 2.4 モデル運用（大きな思想差あり）

| 項目 | origin | framework |
|---|---|---|
| モデル定義場所 | `TEAM.md` チーム構成表の「モデル」列（単一の真実源） | `koumei.config.yaml` の `models:` セクション |
| デフォルト配置 | koumei=sonnet、analyst=sonnet、ux=sonnet、**tech-lead=fable(設計)/opus(実装)のフェーズ分割**、**devils-advocate=fable** | commander=sonnet、**tech-lead=opus、reviewer=opus**、analyst=sonnet、ux=sonnet |
| 配置思想 | 高IQモデルは「レバレッジが高く出力が小さい所」（レビュー判定・設計）に置く | 負荷の高いロール（設計・実装・レビュー）に上位モデル |
| 外部CLIモデル | **対応**（TEAM.md に呼出構文登録: `codex exec` / `grok -p` / `gemini` 等。Agent の代わりに Bash 起動、`command -v` チェック + claude フォールバック） | なし（Claude系エイリアスのみ） |
| モデル委譲 | analyst / tech-lead実装 を codex に委譲してトークン節約（設定でON） | なし |
| economy モード | あり（codex → LM Studio → claude の3段フォールバック） | なし |

### 2.5 レビュー体制（origin が圧倒的に厚い）

| 項目 | origin | framework |
|---|---|---|
| レビュー種別自動判定 | git diff → コード / tech-lead成果物 → 設計 / analyst成果物 → 分析 | 手動（design/code の区別はスキル内手順） |
| セキュリティ監査 | `--security`: OWASP Top10 + STRIDE、スコア8/10未満は強制差し戻し | なし |
| セカンドオピニオン | `--second-opinion`: 外部モデルと突合、統合VERDICT算出ルールあり | なし |
| 一時モデル切替 | `--model codex\|lmstudio\|grok\|claude` | なし |
| タイムアウトフォールバック | `review_timeout`(600s) 超過で次順位モデルへ自動フォールバック、理由を記録 | なし |
| **レビュアー独立性** | **絶対ルール**: 自己レビュー禁止。独立エージェント or 外部モデル必須。不可能なら停止して報告 | reviewer ロール分離はあるが明文化された絶対ルールなし |
| 差し戻し管理 | フェーズ別カウンタ（各Phase最大2回、3回目でユーザーエスカレーション） | koumei-run 内にリトライカウンタあり（類似） |
| コードレビュー必須チェックリスト | 6項目定型（認証認可 / シークレット / リソースリーク / リトライ上限 / クロスブラウザ / フォーム同期） | なし |

### 2.6 マルチタスク並列実行（origin のみ）

- `/koumei-start {要件} --multi`: 要件を「1タスク=1ブランチ=1PR」単位に分割
- 依存関係・ファイル競合で直列/並列グループ化 → 実行計画をユーザー承認後に実行
- 各タスクを `task-manager` が **git worktree** 内で完結実行（Phase1-7 + PR作成）
- 1タスクの失敗は他に波及しない。HALTED はまとめてユーザーに確認
- 前提: Claude Code v2.1.172+（サブエージェント5段ネスト）

### 2.7 Hooks・運用支援（origin のみ）

| Hook | 内容 |
|---|---|
| quality-gate.sh | TEAM.md の直接編集をブロック（※他FW由来のデッドコードあり、統合時に要清掃） |
| log-operation.sh | 全ツール操作を `.agents/logs/YYYY-MM-DD.jsonl` に記録 |
| auto-format.sh | 保存時 prettier 自動実行（.md は除外） |
| notify-phase.sh | 成果物/レビュー/報告の書き込みを macOS 通知（osascript） |

### 2.8 ドキュメント・成果物の配置

| 項目 | origin | framework |
|---|---|---|
| 成果物の置き場所 | `.agents/{ロール}/deliverables/`（内部通信と成果物が同居） | `{{OUTPUT_DIR}}`（`docs-official` 等）に分離 |
| 命名 | `task-{番号}-{種類}.md`（タスクID基準、差し戻し時は同名上書き） | 同様（ただし review 系の命名に3系統の不整合あり: `-review.md` / `-design-review.md` / `-code-review.md`） |
| 機能単位の集約 | なし（タスク定義に「エピック」参照項目のみ） | なし |

> **合意済みの新方針（framework側で先行議論済み）**: 2層構成
> - 作業成果物（分析・設計ドラフト・レビュー結果）→ `.agents/{ロール}/deliverables/`（= origin 準拠）
> - 公式ドキュメント → `docs-official/` に**機能/エピック単位で要件・仕様・設計を1ファイル**、実装完了後に更新（生きたドキュメント）
>
> この設計は origin 互換化の第一歩を兼ねる。

### 2.9 規約の相違（統合方針の決定対象）

| 項目 | origin | framework |
|---|---|---|
| コミットメッセージ | **Co-Authored-By・自動生成マーカー禁止**（TEAM.md 開発規約） | Co-Authored-By 使用（Claude Code デフォルト運用） |
| スキル自動起動 | 禁止（disable-model-invocation: true） | 許可（削除済み） |
| 設定変更の手段 | TEAM.md 直接編集（ただし hook がブロック → 手動解除前提） | config 編集 + `--update` 再生成 |
| ペルソナ | 諸葛孔明フル装備（口調・軍事メタファー） | なし（中立） |

→ いずれも `integration-proposal-origin-base.md` で **origin 準拠を採用** と決定済み。

---

## 3. 統合方針・実行計画

`integration-proposal-origin-base.md` に移管（アーキテクチャ=origin準拠、リポジトリ=framework、マルチCLI維持、Phase 1-5 実行計画）。

---

## 4. 統合時のクリーンアップ項目（備忘）

- origin `hooks/quality-gate.sh` に他フレームワーク（tachikoma）由来のデッドコード（要削除）
- framework のレビュー成果物命名の3系統不整合（`-review.md` / `-design-review.md` / `-code-review.md`）を統合時に一本化
- origin のプレースホルダ手動置換（`{{PROJECT_NAME}}` 等）は framework のテンプレートエンジンで自動化可能
