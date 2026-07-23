# 設定ファイル詳細（koumei.config.yaml）

`setup.sh` が読み込む唯一の設定ファイル。**TEAM.md・各ロールの役割定義・スキルはすべてこの config からの生成物**であり、設定変更は「config を編集 → `setup.sh --update`」で反映する（TEAM.md の直接編集は quality-gate hook がブロックする）。

## project

| キー | 説明 |
|------|------|
| `name` | プロジェクト名。TEAM.md・各ロール定義に表示される |
| `description` | 概要（任意） |
| `path` | プロジェクトルート相対パス（通常 `.`） |

## migration（任意）

既存システムからの移行プロジェクトの場合に設定。

> ⚠️ **現バージョンでは未配線**: この設定は記録されるのみで、生成テンプレートはまだ参照しない（origin 統合で旧テンプレートの消費箇所が置き換わったため）。配線は今後のフェーズで対応予定。

| キー | 例 |
|------|-----|
| `enabled` | `true` / `false` |
| `source_path` | 移行元プロジェクトのパス |
| `source_framework` / `target_framework` | `"Nuxt 2"` / `"Next.js 15"` |

## roles

コアロール（`koumei` / `tech-lead` / `devils-advocate`）は必須。オプションロール（`analyst` / `ux-designer`）は記載時のみ有効化され、対応するスキル（`-analyze` / `-design` / `-design-ux`）・ワークスペース・TEAM.md の記載が展開される。無効ロールのフェーズはワークフロー上自動的にスキップされる。

## target_cli / skill_prefix

| キー | 値 | 説明 |
|------|-----|------|
| `target_cli` | `"claude"`（既定） / `"codex"` / `"antigravity"` | スキル配置先と役割定義ファイル名が変わる（claude: `.claude/skills` + `CLAUDE.md`、codex: `.codex/skills` + `AGENTS.md`、antigravity: `.agents/skills` + `AGENTS.md`）。**Hooks・task-manager・マルチタスクは claude 限定** |
| `skill_prefix` | `"koumei"`（既定） | コマンド接頭辞。`km` にすると `/km-start` 等になり、スキル名・相互参照・手順書内パスもすべて追従する |

## commander

| キー | 説明 |
|------|------|
| `name` | 最高指揮者のコードネーム（既定: `"諸葛孔明"`）。TEAM.md・koumei ペルソナ・各スキルの名乗りに反映される |

## models

tech-lead は**フェーズ分割**（設計と実装で別モデル）。配置の原則は「高単価モデルは、トークン量が多い場所ではなく判断のレバレッジが高く出力が小さい場所へ」。

| キー | claude 既定 | 役割 |
|------|------|------|
| `koumei` | sonnet | オーケストレーション（機械的） |
| `analyst` | sonnet | 読み取り中心の分析 |
| `ux-designer` | sonnet | UX設計 |
| `tech-lead-design` | **fable** | 設計ミスは実装で増幅されるため最上位 |
| `tech-lead-implement` | **opus** | トークン量が多いため1段下 |
| `devils-advocate` | **fable** | レビューVERDICTは品質ゲート。誤判定コストが最大 |

指定可能な値: `haiku` / `sonnet` / `opus` / `fable`（またはフルモデルID）、および TEAM.md「外部CLIモデル定義」に登録した外部モデル名（`grok` / `codex` 等。この場合 Agent tool ではなく Bash 経由で起動される）。

## review

| キー | 既定 | 説明 |
|------|------|------|
| `mode` | `"default"` | `default`（codex→claude） / `economy`（codex→lmstudio→claude） / `claude-only` |
| `timeout` | `600` | 外部CLIレビューのタイムアウト（秒）。超過で次順位モデルへ自動フォールバック |

一時的なモデル切替は `/koumei-review --model claude` のようにフラグで可能（config 変更不要）。

## tech_stack

AIがコードを書く際に従う技術情報と、実装後の検証コマンド。

| キー | 説明 |
|------|------|
| `language` / `framework` / `ui_library` / `styling` / `database` / `testing` | 技術スタック（TEAM.md の技術スタック表と各ロール定義に反映） |
| `build_command` | 実装完了後のビルド確認に使用 |
| `test_command` | テストコマンド（任意） |
| `check_command` | **PR前 lint/format ゲート**。設定すると実装フェーズの完了条件に「チェックが通ること」が追加される。空ならゲート自体をスキップ |

## git

| キー | 説明 |
|------|------|
| `main_branch` / `develop_branch` | ブランチ運用の既定値（現状エージェントに自動配線されるのは `branch_pattern` のみ。ベース/PR先ブランチは `/koumei-request` の対話で確認される） |
| `branch_pattern` | 作業ブランチの命名パターン（`{number}` `{summary}` が置換される） |
| `dev_rules` | TEAM.md の開発規約セクションに追記する行（任意）。**`#` や引用符を含む値・複数行は必ず `\|` ブロック形式で**（プレーンスカラーは yq 無し環境で `#` 以降が切り捨てられる） |

## output（成果物の2層構成）

- **作業成果物**（分析・設計・レビュー・報告）は `.agents/{ロール}/deliverables/` 等の各ワークスペースに置かれ、config の対象外
- `output.dir` は**公式ドキュメント**（要件・仕様・設計のまとめ）の出力先

| キー | 既定 | 説明 |
|------|------|------|
| `dir` | `"docs-official"` | 公式ドキュメントの出力ディレクトリ |
| `format` | `"md"` | 現在は md のみ |
| `instructions` | — | 公式ドキュメントに関する追加指示（任意・複数行可） |

## custom_instructions

ロール別のプロジェクト固有指示。生成される各ロールの役割定義ファイル末尾に「プロジェクト固有の指示」として追記される。キー: `koumei` / `tech-lead` / `devils-advocate` / `analyst` / `ux-designer`。

## reference_docs

各ロールが作業前に参照すべきドキュメントのリスト（`path` + `description`）。TEAM.md の「参照ドキュメント」セクションに反映される。

> ⚠️ この項目の読み込みには **yq が必要**（`brew install yq`）。yq 無し環境では警告を出した上で「（登録なし）」として生成される。

## 設定変更の反映と差分検知

```bash
setup.sh --update     # config はそのまま、最新テンプレートで再生成
setup.sh --reconfig   # ウィザードで config を作り直してから再生成
```

- `--update` は config スキーマの差分を検知する。フレームワーク更新で新しい設定項目が必要になった場合、再生成せず `--reconfig` を案内して停止する
- 生成ファイルのうち Git 管理下のものは上書きスキップされる（例外: **TEAM.md は純粋な生成物のため常に強制再生成**。上書き前のバックアップは `.agents/.backup/` に保存される）
