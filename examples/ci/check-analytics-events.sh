#!/usr/bin/env bash
# アナリティクスイベント実装カバレッジチェック（PR差分ベース）
#
# このPRで定数ファイルに新規追加されたイベント定数が
# 同PR内のソースファイルで ANALYTICS_OBJECT_NAME.<定数名> として発火されているかを確認する。
#
# 既存の未実装イベントはチェック対象外（差分のみ対象）。
# 意図的に未発火とする場合は ALLOWLIST に定数名を追加する。
#
# 導入手順:
#   1. このファイルをプロジェクトの .ci/check-analytics-events.sh にコピー
#   2. 下記「設定」セクションをプロジェクトに合わせて編集
#   3. analytics-rules.md をプロジェクトのドキュメントディレクトリにコピー
#   4. package.json に追加:
#        "check:analytics": "bash .ci/check-analytics-events.sh"
#   5. CI（Bitbucket Pipelines / GitHub Actions 等）から呼び出し:
#        npm run check:analytics
#
# 終了コード:
#   0 ... 新規イベント全て実装済み（または allowlist 登録済み・追加なし）
#   1 ... 未実装の新規イベントあり

set -uo pipefail

# ── 設定（プロジェクトに合わせて変更してください） ────────────────────────────

# アナリティクス定数ファイルのパス（プロジェクトルート相対）
CONSTANTS_FILE="lib/analytics/constants.ts"

# ソースコード内での使用形式のオブジェクト名
# 例: ANALYTICS_EVENTS.BUTTON_CLICK → "ANALYTICS_EVENTS"
ANALYTICS_OBJECT_NAME="ANALYTICS_EVENTS"

# grep 対象ディレクトリ（スペース区切り）
SEARCH_DIRS="app components lib"

# アナリティクスルール文書のパス（CI 失敗メッセージに表示される）
# analytics-rules.md を配置したパスに合わせて変更してください
RULES_DOC_PATH="docs/analytics-rules.md"

# 意図的に発火しないイベントの除外リスト
ALLOWLIST=(
  # AUTH_LOGIN_FAIL
)

# ── ベースブランチ解決: 引数 > Bitbucket 環境変数 > main ──────────────────────
BASE_BRANCH="${1:-${BITBUCKET_PR_DESTINATION_BRANCH:-main}}"

# ── ベースブランチの取得（CI 環境でのみ必要） ─────────────────────────────────
# ローカルにリモートブランチが存在しなければ fetch する
if ! git rev-parse --verify "origin/${BASE_BRANCH}" &>/dev/null; then
  echo "Fetching origin/${BASE_BRANCH}..."
  git fetch origin "${BASE_BRANCH}" --depth=1 2>/dev/null || true
fi

# ── このPRで定数ファイルに新規追加された定数名を抽出 ──────────────────────────
if git rev-parse --verify "origin/${BASE_BRANCH}" &>/dev/null; then
  DIFF_TARGET="origin/${BASE_BRANCH}...HEAD"
else
  DIFF_TARGET="${BASE_BRANCH}"
fi

NEW_EVENTS=$(git diff "${DIFF_TARGET}" -- "$CONSTANTS_FILE" \
  | grep "^+" \
  | grep -E "^\+[[:space:]]+[A-Z][A-Z_]+:" \
  | sed "s/^+[[:space:]]*//" \
  | sed "s/:.*//" \
  | sort -u || true)

if [ -z "$NEW_EVENTS" ]; then
  echo ""
  echo "✅ Analytics Event Coverage Check: SKIPPED"
  echo "   ${CONSTANTS_FILE} に新規イベント定数の追加はありません"
  echo ""
  exit 0
fi

NEW_COUNT=$(echo "$NEW_EVENTS" | grep -c "." || true)

# ── 未実装イベントの収集 ───────────────────────────────────────────────────────
UNUSED=()

while IFS= read -r event; do
  [ -z "$event" ] && continue

  # allowlist チェック
  in_allowlist=false
  for allowed in "${ALLOWLIST[@]}"; do
    [[ "$event" == "$allowed" ]] && in_allowlist=true && break
  done
  $in_allowlist && continue

  # ソースコード内で ANALYTICS_OBJECT_NAME.<定数名> の参照を検索
  # shellcheck disable=SC2086
  if ! grep -rq "${ANALYTICS_OBJECT_NAME}\.${event}" \
      --include="*.ts" --include="*.tsx" \
      $SEARCH_DIRS 2>/dev/null; then
    UNUSED+=("$event")
  fi
done <<< "$NEW_EVENTS"

# ── 結果出力 ──────────────────────────────────────────────────────────────────
ALLOWLIST_SKIPPED=0
for allowed in "${ALLOWLIST[@]}"; do
  if echo "$NEW_EVENTS" | grep -qx "$allowed"; then
    ALLOWLIST_SKIPPED=$((ALLOWLIST_SKIPPED + 1))
  fi
done

if [ ${#UNUSED[@]} -gt 0 ]; then
  echo ""
  echo "❌ Analytics Event Coverage Check: FAILED"
  echo "   このPRで新規追加されたイベント定数 (${NEW_COUNT} 件) のうち、"
  echo "   発火実装が見つかりません (${#UNUSED[@]} 件):"
  for e in "${UNUSED[@]}"; do
    echo "     - ${ANALYTICS_OBJECT_NAME}.${e}"
  done
  echo ""
  echo "   対処方法:"
  echo "   A) 該当コンポーネントに track(${ANALYTICS_OBJECT_NAME}.${UNUSED[0]}, {...}) を追加"
  echo "   B) 意図的に未発火とする場合は .ci/check-analytics-events.sh の ALLOWLIST に追加"
  echo ""
  echo "   アナリティクス実装ルール: ${RULES_DOC_PATH} を参照してください"
  echo ""
  exit 1
fi

echo ""
echo "✅ Analytics Event Coverage Check: PASSED"
CHECKED=$((NEW_COUNT - ALLOWLIST_SKIPPED))
echo "   新規 ${NEW_COUNT} イベント全ての発火実装を確認 (allowlist スキップ: ${ALLOWLIST_SKIPPED} 件)"
echo ""
