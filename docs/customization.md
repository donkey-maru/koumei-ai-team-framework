# カスタマイズガイド

## ロール構成の変更

### 対話式で変更（推奨）

```bash
/path/to/koumei-ai-team-framework/setup.sh --roles
```

現在のロール構成が表示され、各ロールの説明を見ながら ON/OFF を選択できます。

### 手動で変更

`koumei.config.yaml` の `roles` セクションを編集:

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
/path/to/koumei-ai-team-framework/setup.sh --update
```

### コア構成のみ（最小構成）

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
```

ワークフロー: `request → start → design-tech → review → implement → review → status`

### フル構成

```yaml
roles:
  - commander
  - tech-lead
  - reviewer
  - analyst
  - ux-designer
```

ワークフロー: `request → start → analyze → design(並列) → review → implement → review → status`

## コマンドプレフィックスの変更

```yaml
skill_prefix: "km"
```

再セットアップ後、`/km-request`, `/km-start`, `/km-review` 等で利用可能。

**注意**: プレフィックス変更前のスキルディレクトリは自動削除されません。必要に応じて手動削除するか、`--clean` 後に再セットアップしてください。

## 成果物の出力先変更

```yaml
output:
  dir: "docs-confidential"
  format: "md"
  instructions: |
    - 同フォルダ内の既存 .md ファイルの書き方を参考にすること
```

### プロジェクト既存の指示との共存

プロジェクトの `AGENTS.md` や `CLAUDE.md` に成果物出力先の指示が既にある場合、**そちらが優先**されます。`koumei.config.yaml` の設定はフォールバックとして機能します。

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
- commander の指示ファイルに移行元プロジェクトへの参照が追加
- analyst の指示ファイルに分析対象パスが追加

## 設定の再作成

設定ファイルを最初から作り直したい場合:

```bash
/path/to/koumei-ai-team-framework/setup.sh --init
```

対話式ウィザードが起動し、`koumei.config.yaml` を再生成します。

## テンプレートの直接編集

展開後のファイル（`.agents/*/AGENTS.md`, `.codex/skills/*/SKILL.md`）を直接編集することも可能です。
`target_cli: "claude"` の場合は `.agents/*/CLAUDE.md`, `.claude/skills/*/SKILL.md` が対象です。
`target_cli: "antigravity"` の場合は `.agents/*/AGENTS.md`, `.agents/skills/*/SKILL.md` が対象です。

**注意**: `setup.sh --update` を実行すると上書きされるため、カスタマイズは `custom_instructions` 経由で行うことを推奨します。

## アナリティクスイベント CI チェックの導入

PR 時にアナリティクスイベントの実装漏れを自動検出する CI スクリプトを導入できます。
このスクリプトは koumei に依存しないため、他の AI ハーネスフレームワークを使用するプロジェクトでも利用できます。

### 導入手順

**1. スクリプトをコピー**

```bash
mkdir -p .ci
cp /path/to/koumei-ai-team-framework/examples/ci/check-analytics-events.sh .ci/
chmod +x .ci/check-analytics-events.sh
```

**2. スクリプトの設定を編集**

`.ci/check-analytics-events.sh` の設定セクションをプロジェクトに合わせて変更:

```bash
CONSTANTS_FILE="lib/analytics/constants.ts"   # 定数ファイルのパス
ANALYTICS_OBJECT_NAME="ANALYTICS_EVENTS"      # ソースコード内の使用形式のオブジェクト名
BASE_BRANCH="main"                            # 比較ベースブランチ
```

定数ファイルの形式に合わせて抽出パターンも選択してください（スクリプト内のコメントを参照）。

**3. アナリティクスルールドキュメントをコピー**

```bash
cp /path/to/koumei-ai-team-framework/examples/docs/analytics-rules.md <プロジェクトの任意のパス>
# 例: docs/analytics-rules.md、docs-official/analytics-rules.md など
```

配置先はプロジェクトのドキュメントディレクトリに合わせてください（`docs/` に限りません）。
このファイルが存在することで、koumei の reviewer に限らずどの AI ツールでも
「何を確認すべきか」を参照できます。

配置先を変更した場合は、`.ci/check-analytics-events.sh` の `RULES_DOC_PATH` も合わせて更新してください:

```bash
RULES_DOC_PATH="docs-official/analytics-rules.md"  # 実際の配置先に変更
```

CI 失敗メッセージはこのパスを参照先として出力します。

**4. package.json にスクリプトを追加**

```json
{
  "scripts": {
    "check:analytics": "bash .ci/check-analytics-events.sh"
  }
}
```

**5. CI に組み込む**

Bitbucket Pipelines の例:

```yaml
pipelines:
  pull-requests:
    '**':
      - step:
          name: Analytics Check
          script:
            - npm run check:analytics
```

GitHub Actions の例:

```yaml
- name: Analytics Check
  run: npm run check:analytics
  env:
    BASE_BRANCH: ${{ github.base_ref }}
```

### koumei reviewer との連携

`koumei.config.yaml` の `custom_instructions.reviewer` に以下を追加すると、
AI reviewer が CI では検出できないケース（定数も `track()` も追加しないままボタンだけ追加した場合）を補完します:

```yaml
custom_instructions:
  reviewer: |
    - アナリティクスカバレッジ: docs/analytics-rules.md を参照し、
      新しいユーザー操作に track() が実装されているか確認すること
```

### 検出範囲

| ケース | CI | reviewer |
|--------|-----|----------|
| 定数を追加したのに `track()` を書き忘れた | ✅ FAILED でブロック | ✅ |
| ボタンを追加したのに定数も `track()` も書かなかった | 検出不可 | ✅ |
