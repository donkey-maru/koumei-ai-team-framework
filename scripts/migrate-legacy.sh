#!/bin/bash
# ============================================================
# koumei.config.yaml / .agents レイアウトの移行スクリプト
# ============================================================
# origin 統合（Phase 1）以前の旧スキーマ（commander/reviewer ロール名、
# tech-lead単一モデル、dev_command キー等）から新スキーマへ変換する。
#
# 使い方: 移行対象プロジェクトのルートで実行
#   /path/to/koumei-ai-team-framework/scripts/migrate-legacy.sh [--dry-run]
#
# 前提: このプロジェクトの koumei.config.yaml が旧スキーマであること
#       （roles: に commander/reviewer が含まれる）
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="koumei.config.yaml"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log()  { echo -e "\033[0;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err()  { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

if [[ ! -f "$CONFIG_FILE" ]]; then
  err "koumei.config.yaml が見つかりません。プロジェクトルートで実行してください。"
  exit 1
fi

if ! grep -qE '^\s*-\s*commander\s*$' "$CONFIG_FILE"; then
  warn "roles: に 'commander' が見当たりません。既に新スキーマの可能性があります。中断します。"
  exit 1
fi

log "対象: $(pwd)/${CONFIG_FILE}"
$DRY_RUN && log "[DRY-RUN] 実際の変更は行いません"

# --- 1. config.yaml の変換（単一パス・状態管理で行単位に処理） ---
convert_config() {
  perl -ne '
    BEGIN { $section = ""; }

    # セクション見出しの検出（行頭にインデントなしで始まる識別子）
    if (/^([a-zA-Z_]+):\s*$/) { $section = $1; }

    # 注意: \s は改行にもマッチするため、行末を跨ぐキャプチャ($) は避け、
    # 改行は print 側の明示的な \n だけに任せる（二重改行によるバグを防ぐ）
    if ($section eq "roles" && /^(\s*-\s*)commander[ \t]*$/) {
      print "${1}koumei\n"; next;
    }
    if ($section eq "roles" && /^(\s*-\s*)reviewer[ \t]*$/) {
      print "${1}devils-advocate\n"; next;
    }

    if ($section eq "models") {
      if (/^(\s*)commander:(\s*"[^"]*")\s*$/) { print "${1}koumei:${2}\n"; next; }
      if (/^(\s*)reviewer:(\s*"[^"]*")\s*$/)  { print "${1}devils-advocate:${2}\n"; next; }
      if (/^(\s*)tech-lead:\s*"([^"]*)"\s*$/) {
        print "${1}tech-lead-design: \"$2\"\n";
        print "${1}tech-lead-implement: \"$2\"\n";
        next;
      }
      # models: ブロック終端（空行）の直前に review: セクションを挿入
      if (/^\s*$/ && !$review_inserted) {
        print "\n# === レビュー設定 ===\nreview:\n  mode: \"default\"\n  timeout: 600\n";
        $review_inserted = 1;
      }
    }

    if ($section eq "custom_instructions") {
      if (/^(\s*)commander:(.*)$/) { print "${1}koumei:${2}\n"; next; }
      if (/^(\s*)reviewer:(.*)$/)  { print "${1}devils-advocate:${2}\n"; next; }
    }

    if ($section eq "tech_stack" && /^\s*dev_command:/) { next; }

    print;
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

if $DRY_RUN; then
  log "config変換プレビュー（実際には書き込みません）:"
  cp "$CONFIG_FILE" /tmp/migrate-preview.yaml
  convert_config /tmp/migrate-preview.yaml
  diff -u "$CONFIG_FILE" /tmp/migrate-preview.yaml || true
  rm -f /tmp/migrate-preview.yaml
else
  cp "$CONFIG_FILE" "${CONFIG_FILE}.pre-migration.bak"
  log "バックアップ: ${CONFIG_FILE}.pre-migration.bak"
  convert_config "$CONFIG_FILE"
  log "config.yaml を新スキーマに変換しました"
fi

# --- 2. .agents/ ディレクトリのリネーム ---
is_git_tracked() { git ls-files --error-unmatch "$1" &>/dev/null 2>&1; }

rename_role_dir() {
  local old="$1" new="$2"
  [[ -d "$old" ]] || return 0
  if [[ -d "$new" ]]; then
    warn "移行先 ${new}/ が既に存在します。${old}/ との統合が必要なため自動処理をスキップします。手動で確認してください。"
    return 0
  fi
  if $DRY_RUN; then
    log "[DRY-RUN] Would move: ${old} -> ${new}"
    return 0
  fi
  if [[ -n "$(git ls-files "$old" 2>/dev/null)" ]]; then
    git mv "$old" "$new"
    log "git mv: ${old} -> ${new}"
  else
    mv "$old" "$new"
    log "mv: ${old} -> ${new}"
  fi
}

rename_role_dir ".agents/commander" ".agents/koumei"
rename_role_dir ".agents/reviewer" ".agents/devils-advocate"

echo ""
if $DRY_RUN; then
  log "[DRY-RUN] 完了。実際に適用するには --dry-run を外して再実行してください。"
else
  log "config・ディレクトリの変換が完了しました。次のコマンドで再生成してください:"
  log "  ${SCRIPT_DIR}/setup.sh --update"
fi
