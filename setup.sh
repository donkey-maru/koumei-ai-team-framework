#!/bin/bash
# ============================================================
# koumei-ai-team-framework セットアップスクリプト
# ============================================================
# 使い方:
#   ./setup.sh                    # 初回セットアップ
#   ./setup.sh --update           # 設定変更後の再展開（成果物は保持）
#   ./setup.sh --clean            # 展開済みファイルを削除
#   ./setup.sh --dry-run          # 実際にファイルを作成せずプレビュー
# ============================================================

set -euo pipefail

# --- 定数 ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
CONFIG_FILE="koumei.config.yaml"
VERSION="1.0.0"
DEFAULT_TARGET_CLI="codex"

# --- カラー出力 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# --- 引数処理 ---
MODE="setup"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --init)    MODE="init" ;;
    --roles)   MODE="roles" ;;
    --update)  MODE="update" ;;
    --clean)   MODE="clean" ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "koumei-ai-team-framework setup v${VERSION}"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (none)      Initial setup (auto-runs wizard if no config found)"
      echo "  --init      Run config wizard (create/overwrite koumei.config.yaml)"
      echo "  --roles     Change role composition only"
      echo "  --update    Re-generate from config (preserves deliverables)"
      echo "  --clean     Remove all generated files"
      echo "  --dry-run   Preview without creating files"
      echo "  --help      Show this help"
      exit 0
      ;;
  esac
done

# ============================================================
# 対話式セットアップウィザード
# ============================================================

# ユーザー入力を取得（デフォルト値付き）
prompt_input() {
  local prompt="$1"
  local default="$2"
  local result

  if [[ -n "$default" ]]; then
    printf "${BLUE}%s${NC} [${GREEN}%s${NC}]: " "$prompt" "$default" >&2
  else
    printf "${BLUE}%s${NC}: " "$prompt" >&2
  fi
  read -r result </dev/tty 2>/dev/null || read -r result
  echo "${result:-$default}"
}

# Yes/No入力
prompt_yn() {
  local prompt="$1"
  local default="${2:-n}"
  local result

  if [[ "$default" == "y" ]]; then
    printf "${BLUE}%s${NC} [${GREEN}Y${NC}/n]: " "$prompt" >&2
  else
    printf "${BLUE}%s${NC} [y/${GREEN}N${NC}]: " "$prompt" >&2
  fi
  read -r result </dev/tty 2>/dev/null || read -r result
  result="${result:-$default}"
  [[ "$result" =~ ^[Yy] ]]
}

# ロール選択ウィザード（説明付き）
# 結果はグローバル変数 WIZARD_SELECTED_ROLES に格納
wizard_select_roles() {
  WIZARD_SELECTED_ROLES=("commander" "tech-lead" "reviewer")

  echo ""
  echo -e "${BLUE}━━━ ロール構成 ━━━${NC}"
  echo ""
  echo -e "${GREEN}【コアロール（必須）】${NC}"
  echo -e "  ✅ ${GREEN}commander${NC}   … 全体統括・タスク分割・指示出し・最終判断を行う指揮者"
  echo -e "  ✅ ${GREEN}tech-lead${NC}   … 技術設計・アーキテクチャ決定・実装を担当"
  echo -e "  ✅ ${GREEN}reviewer${NC}    … 設計書・コードの品質レビュー・問題提起を担当"
  echo ""
  echo -e "${YELLOW}【オプションロール】${NC}"
  echo ""

  # analyst
  echo -e "  ${YELLOW}analyst${NC} … 既存コードベースの調査・分析を担当"
  echo -e "           移行プロジェクトや大規模リファクタリングで特に有用。"
  echo -e "           既存の実装パターン・依存関係・技術的負債を可視化する。"
  if prompt_yn "  analyst を有効にしますか？"; then
    WIZARD_SELECTED_ROLES+=("analyst")
    echo -e "  → ${GREEN}✅ 有効${NC}"
  else
    echo -e "  → ☐ 無効"
  fi

  echo ""

  # ux-designer
  echo -e "  ${YELLOW}ux-designer${NC} … UI/UX設計・コンポーネント設計・画面遷移設計を担当"
  echo -e "               フロントエンド開発やユーザー向け機能の実装で特に有用。"
  echo -e "               tech-lead と並列で設計を行い、設計の質を向上させる。"
  if prompt_yn "  ux-designer を有効にしますか？"; then
    WIZARD_SELECTED_ROLES+=("ux-designer")
    echo -e "  → ${GREEN}✅ 有効${NC}"
  else
    echo -e "  → ☐ 無効"
  fi

  echo ""
  echo -e "選択されたロール: ${GREEN}${WIZARD_SELECTED_ROLES[*]}${NC}"
}

# ============================================================
# プロジェクト自動検出
# ============================================================

# package.json から依存関係を検出
detect_pkg_dep() {
  local pkg="$1"
  local file="package.json"
  [[ ! -f "$file" ]] && return 1
  grep -q "\"$pkg\"" "$file" 2>/dev/null
}

# package.json の scripts からコマンドを検出
detect_pkg_script() {
  local script="$1"
  local file="package.json"
  [[ ! -f "$file" ]] && return 1
  grep -q "\"$script\":" "$file" 2>/dev/null
}

# 技術スタックの自動検出
detect_tech_stack() {
  DETECTED_LANG=""
  DETECTED_FW=""
  DETECTED_UI_LIB=""
  DETECTED_STYLING=""
  DETECTED_DB=""
  DETECTED_TESTING=""
  DETECTED_BUILD_CMD=""
  DETECTED_TEST_CMD=""
  DETECTED_DEV_CMD=""
  DETECTED_CHECK_CMD=""

  # --- 言語検出 ---
  if [[ -f "tsconfig.json" ]]; then
    DETECTED_LANG="TypeScript"
  elif [[ -f "package.json" ]]; then
    DETECTED_LANG="JavaScript"
  elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    DETECTED_LANG="Python"
  elif [[ -f "Gemfile" ]]; then
    DETECTED_LANG="Ruby"
  elif [[ -f "go.mod" ]]; then
    DETECTED_LANG="Go"
  elif [[ -f "Cargo.toml" ]]; then
    DETECTED_LANG="Rust"
  fi

  # --- フレームワーク検出 ---
  if detect_pkg_dep "next"; then
    local next_ver
    next_ver=$(grep '"next"' package.json 2>/dev/null | head -1 | sed 's/.*: *"\^*~*\([0-9]*\).*/\1/')
    DETECTED_FW="Next.js ${next_ver}"
  elif detect_pkg_dep "nuxt"; then
    local nuxt_ver
    nuxt_ver=$(grep '"nuxt"' package.json 2>/dev/null | head -1 | sed 's/.*: *"\^*~*\([0-9]*\).*/\1/')
    DETECTED_FW="Nuxt ${nuxt_ver}"
  elif detect_pkg_dep "vue"; then
    DETECTED_FW="Vue"
  elif detect_pkg_dep "react"; then
    DETECTED_FW="React"
  elif detect_pkg_dep "express"; then
    DETECTED_FW="Express"
  elif [[ -f "requirements.txt" ]] && grep -q "django" requirements.txt 2>/dev/null; then
    DETECTED_FW="Django"
  elif [[ -f "requirements.txt" ]] && grep -q "flask" requirements.txt 2>/dev/null; then
    DETECTED_FW="Flask"
  elif [[ -f "Gemfile" ]] && grep -q "rails" Gemfile 2>/dev/null; then
    DETECTED_FW="Rails"
  fi

  # --- UIライブラリ検出 ---
  if detect_pkg_dep "@shadcn" || [[ -f "components.json" ]]; then
    DETECTED_UI_LIB="shadcn/ui"
  elif detect_pkg_dep "@mui/material"; then
    DETECTED_UI_LIB="MUI"
  elif detect_pkg_dep "vuetify" || detect_pkg_dep "@nuxtjs/vuetify"; then
    DETECTED_UI_LIB="Vuetify"
  elif detect_pkg_dep "antd"; then
    DETECTED_UI_LIB="Ant Design"
  elif detect_pkg_dep "@chakra-ui"; then
    DETECTED_UI_LIB="Chakra UI"
  fi

  # --- スタイリング検出 ---
  if detect_pkg_dep "tailwindcss"; then
    local tw_ver
    tw_ver=$(grep '"tailwindcss"' package.json 2>/dev/null | head -1 | sed 's/.*: *"\^*~*\([0-9]*\).*/\1/')
    DETECTED_STYLING="Tailwind CSS v${tw_ver}"
  elif [[ -f "styled-components" ]] || detect_pkg_dep "styled-components"; then
    DETECTED_STYLING="styled-components"
  elif detect_pkg_dep "@emotion/react"; then
    DETECTED_STYLING="Emotion"
  fi
  # CSS Modules は設定ファイルなしで使えるため検出困難

  # --- データベース検出 ---
  if detect_pkg_dep "firebase" || detect_pkg_dep "firebase-admin"; then
    DETECTED_DB="Firestore"
  elif detect_pkg_dep "prisma" || detect_pkg_dep "@prisma/client"; then
    DETECTED_DB="PostgreSQL (Prisma)"
  elif detect_pkg_dep "mongoose"; then
    DETECTED_DB="MongoDB"
  elif detect_pkg_dep "mysql2"; then
    DETECTED_DB="MySQL"
  elif detect_pkg_dep "pg"; then
    DETECTED_DB="PostgreSQL"
  elif detect_pkg_dep "better-sqlite3" || detect_pkg_dep "sqlite3"; then
    DETECTED_DB="SQLite"
  fi

  # --- テストFW検出 ---
  if detect_pkg_dep "vitest"; then
    DETECTED_TESTING="Vitest"
  elif detect_pkg_dep "jest"; then
    DETECTED_TESTING="Jest"
  elif detect_pkg_dep "mocha"; then
    DETECTED_TESTING="Mocha"
  elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]] && grep -q "pytest" pyproject.toml 2>/dev/null; then
    DETECTED_TESTING="pytest"
  fi

  # --- コマンド検出 ---
  if detect_pkg_script "build"; then
    DETECTED_BUILD_CMD="npm run build"
  elif [[ -f "Makefile" ]]; then
    DETECTED_BUILD_CMD="make build"
  fi

  if detect_pkg_script "test"; then
    DETECTED_TEST_CMD="npm run test"
  elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
    DETECTED_TEST_CMD="pytest"
  fi

  if detect_pkg_script "dev"; then
    DETECTED_DEV_CMD="npm run dev"
  elif detect_pkg_script "start"; then
    DETECTED_DEV_CMD="npm start"
  fi

  # lint/format チェックコマンド検出（"check" を優先、なければ "lint"）
  if detect_pkg_script "check"; then
    DETECTED_CHECK_CMD="npm run check"
  elif detect_pkg_script "lint"; then
    DETECTED_CHECK_CMD="npm run lint"
  fi
}

# Git ブランチの自動検出
detect_git_branches() {
  DETECTED_MAIN_BRANCH=""
  DETECTED_DEVELOP_BRANCH=""

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    return
  fi

  # メインブランチ検出
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    DETECTED_MAIN_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    DETECTED_MAIN_BRANCH="master"
  fi

  # 開発ブランチ検出
  if git show-ref --verify --quiet refs/heads/develop 2>/dev/null; then
    DETECTED_DEVELOP_BRANCH="develop"
  elif git show-ref --verify --quiet refs/heads/development 2>/dev/null; then
    DETECTED_DEVELOP_BRANCH="development"
  fi
}

# 検出結果を表示（値があれば緑✅、なければ黄色で未検出）
show_detected() {
  local label="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    printf "  %-16s ${GREEN}%s ✅${NC}\n" "$label:" "$value" >&2
  else
    printf "  %-16s ${YELLOW}（未検出）${NC}\n" "$label:" >&2
  fi
}

# フルウィザード（koumei.config.yaml 生成）
run_wizard() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   koumei-ai-team-framework 初期設定ウィザード       ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
  echo ""

  # --- プロジェクト基本情報 ---
  echo -e "${BLUE}━━━ プロジェクト基本情報 ━━━${NC}"
  local proj_name proj_desc
  local default_name
  default_name=$(basename "$(pwd)")
  proj_name=$(prompt_input "プロジェクト名" "$default_name")
  proj_desc=$(prompt_input "プロジェクトの説明" "")

  # --- 技術スタック（自動検出 → 確認） ---
  echo ""
  echo -e "${BLUE}━━━ 技術スタック ━━━${NC}"
  echo -e "  AIがコードを書く際に従うべき技術スタックです。"
  echo -e "  プロジェクトのファイルから自動検出を試みます..."
  echo ""

  detect_tech_stack

  local has_detection=false
  [[ -n "$DETECTED_LANG" || -n "$DETECTED_FW" || -n "$DETECTED_UI_LIB" || -n "$DETECTED_STYLING" || -n "$DETECTED_DB" || -n "$DETECTED_TESTING" ]] && has_detection=true

  if $has_detection; then
    echo -e "  ${GREEN}検出結果:${NC}"
    echo ""
    echo -e "  ${YELLOW}【コード生成に影響する設定】${NC}"
    echo -e "  ${YELLOW}  AIがコードを書く際、以下の技術に従って実装します${NC}"
    show_detected "言語" "$DETECTED_LANG"
    show_detected "フレームワーク" "$DETECTED_FW"
    show_detected "UIライブラリ" "$DETECTED_UI_LIB"
    echo -e "    ${YELLOW}↑ ボタン・フォーム等の既製UIコンポーネント集${NC}"
    show_detected "スタイリング" "$DETECTED_STYLING"
    echo -e "    ${YELLOW}↑ CSS の書き方（ユーティリティクラス / CSS-in-JS 等）${NC}"
    show_detected "データベース" "$DETECTED_DB"
    show_detected "テストFW" "$DETECTED_TESTING"
    echo ""
    echo -e "  ${YELLOW}【実装後の検証コマンド】${NC}"
    echo -e "  ${YELLOW}  AIが実装後にビルド・テストを実行して動作確認します${NC}"
    show_detected "ビルド" "$DETECTED_BUILD_CMD"
    show_detected "テスト" "$DETECTED_TEST_CMD"
    show_detected "Lint/Format" "$DETECTED_CHECK_CMD"
    echo -e "    ${YELLOW}↑ PR前に実行する lint/format チェック（Biome/ESLint等）${NC}"
    show_detected "開発サーバー" "$DETECTED_DEV_CMD"
    echo ""
  fi

  local lang fw ui_lib styling db testing
  local build_cmd test_cmd dev_cmd check_cmd

  if $has_detection && prompt_yn "検出結果をベースに進めますか？（個別に修正可能）" "y"; then
    echo ""
    echo -e "  ${YELLOW}変更したい項目だけ入力してください。そのままならEnter。${NC}"
    echo ""
    lang=$(prompt_input "言語" "${DETECTED_LANG:-TypeScript}")
    fw=$(prompt_input "フレームワーク" "${DETECTED_FW:-}")
    ui_lib=$(prompt_input "UIライブラリ（なければ空Enter）" "${DETECTED_UI_LIB:-}")
    styling=$(prompt_input "スタイリング（なければ空Enter）" "${DETECTED_STYLING:-}")
    db=$(prompt_input "データベース（なければ空Enter）" "${DETECTED_DB:-}")
    testing=$(prompt_input "テストFW（なければ空Enter）" "${DETECTED_TESTING:-}")
    build_cmd=$(prompt_input "ビルドコマンド" "${DETECTED_BUILD_CMD:-npm run build}")
    test_cmd=$(prompt_input "テストコマンド（なければ空Enter）" "${DETECTED_TEST_CMD:-}")
    echo -e "  ${YELLOW}Lint/Format: PR前に実行する lint/format チェック。空なら工程ごとスキップ${NC}"
    check_cmd=$(prompt_input "Lint/Formatチェックコマンド（なければ空Enter）" "${DETECTED_CHECK_CMD:-}")
    dev_cmd=$(prompt_input "開発サーバーコマンド" "${DETECTED_DEV_CMD:-npm run dev}")
  else
    echo ""
    echo -e "  ${YELLOW}手動で入力してください。${NC}"
    echo ""
    lang=$(prompt_input "言語（AIが書くコードの言語）" "TypeScript")
    fw=$(prompt_input "フレームワーク（プロジェクトのFW）" "")
    echo -e "  ${YELLOW}UIライブラリ: AIがUI実装時に使用するコンポーネントライブラリ（例: shadcn/ui, MUI, Vuetify）${NC}"
    ui_lib=$(prompt_input "UIライブラリ（なければ空Enter）" "")
    echo -e "  ${YELLOW}スタイリング: CSSの記述方法（例: Tailwind CSS v4, CSS Modules, styled-components）${NC}"
    styling=$(prompt_input "スタイリング（なければ空Enter）" "")
    echo -e "  ${YELLOW}データベース: AIがクエリやスキーマを書く際の対象DB${NC}"
    db=$(prompt_input "データベース（なければ空Enter）" "")
    echo -e "  ${YELLOW}テストFW: AIがテストを書く際に使用するFW（例: Vitest, Jest, pytest）${NC}"
    testing=$(prompt_input "テストフレームワーク（なければ空Enter）" "")
    echo ""
    echo -e "  ${YELLOW}以下はAIが実装後の検証で実行するコマンドです。${NC}"
    build_cmd=$(prompt_input "ビルドコマンド" "npm run build")
    test_cmd=$(prompt_input "テストコマンド（なければ空Enter）" "")
    echo -e "  ${YELLOW}Lint/Format: PR前に実行する lint/format チェック。空なら工程ごとスキップ${NC}"
    check_cmd=$(prompt_input "Lint/Formatチェックコマンド（なければ空Enter）" "")
    dev_cmd=$(prompt_input "開発サーバーコマンド" "npm run dev")
  fi

  # --- 成果物出力 ---
  echo ""
  echo -e "${BLUE}━━━ 成果物の出力設定 ━━━${NC}"
  echo -e "  ${YELLOW}AIが生成する設計書・分析レポート・レビュー結果の保存先です。${NC}"
  echo -e "  ${YELLOW}.agents/ 内部ではなくプロジェクトのドキュメントとして残ります。${NC}"
  echo -e "  ${YELLOW}例: 「docs」「docs-confidential」「documents」${NC}"
  echo ""
  local output_dir output_instructions
  output_dir=$(prompt_input "出力先ディレクトリ（プロジェクトルートからの相対パス）" "docs")
  echo -e "  ${YELLOW}追加指示: 出力フォーマットの指定等（例: 「既存の.mdファイルを参考にすること」）${NC}"
  output_instructions=$(prompt_input "追加指示（なければ空Enter）" "")

  # --- Git（自動検出 → 確認） ---
  echo ""
  echo -e "${BLUE}━━━ Git運用 ━━━${NC}"
  echo -e "  AIがブランチ作成・PR先決定で従うルールです。"

  detect_git_branches

  if [[ -n "$DETECTED_MAIN_BRANCH" ]]; then
    echo ""
    echo -e "  ${GREEN}検出結果:${NC}"
    show_detected "メインブランチ" "$DETECTED_MAIN_BRANCH"
    show_detected "開発ブランチ" "$DETECTED_DEVELOP_BRANCH"
    echo ""
  fi

  local git_main git_develop git_branch_pattern
  git_main=$(prompt_input "メインブランチ（本番ブランチ）" "${DETECTED_MAIN_BRANCH:-main}")
  echo -e "  ${YELLOW}開発ブランチ: PRの向き先。空ならメインブランチに直接PR${NC}"
  git_develop=$(prompt_input "開発ブランチ（なければ空Enter）" "${DETECTED_DEVELOP_BRANCH:-}")
  echo -e "  ${YELLOW}ブランチ名パターン: {number}はタスク番号、{summary}はタスク概要に自動置換${NC}"
  local default_bp='feature/task-{number}-{summary}'
  git_branch_pattern=$(prompt_input "ブランチ命名パターン" "$default_bp")

  # --- スキルプレフィックス ---
  echo ""
  echo -e "${BLUE}━━━ スキルコマンド設定 ━━━${NC}"
  echo -e "  ${YELLOW}Codex CLI / Claude Code のスキルコマンド接頭辞です。${NC}"
  echo -e "  ${YELLOW}この接頭辞でスキルディレクトリ名とコマンド名が決まります。${NC}"
  echo -e "  例: 「koumei」→ /koumei-start, /koumei-run"
  echo -e "  例: 「km」→ /km-start, /km-run"
  echo -e "  例: 「dev」→ /dev-start, /dev-run"
  local skill_prefix
  skill_prefix=$(prompt_input "スキルプレフィックス" "koumei")

  # --- 指揮者 ---
  echo ""
  echo -e "${BLUE}━━━ 指揮者設定 ━━━${NC}"
  echo -e "  ${YELLOW}AIチームの指揮者（commander）のコードネームです。${NC}"
  echo -e "  ${YELLOW}スキル説明やタスク定義書に表示されます。${NC}"
  echo -e "  例: 「諸葛孔明」「Commander」「Archimedes」"
  local commander_name
  commander_name=$(prompt_input "指揮者の名前" "Commander")

  # --- ロール選択 ---
  wizard_select_roles

  # --- 移行プロジェクト ---
  echo ""
  echo -e "${BLUE}━━━ 移行プロジェクト設定 ━━━${NC}"
  echo -e "  ${YELLOW}既存システムから新システムへの移行プロジェクトの場合に設定します。${NC}"
  echo -e "  ${YELLOW}有効にすると、分析・設計時に移行元コードの参照指示がAIに含まれます。${NC}"
  local mig_enabled="false" mig_source="" mig_source_fw="" mig_target_fw=""
  if prompt_yn "既存システムからの移行プロジェクトですか？"; then
    mig_enabled="true"
    mig_source=$(prompt_input "移行元プロジェクトのパス" "")
    mig_source_fw=$(prompt_input "移行元フレームワーク（例: Nuxt 2, Rails 5）" "")
    mig_target_fw=$(prompt_input "移行先フレームワーク（例: Next.js 15）" "$fw")
  fi

  # --- YAML生成 ---
  echo ""
  log_step "koumei.config.yaml を生成中..."

  # ロール配列を生成
  local roles_yaml=""
  for r in "${WIZARD_SELECTED_ROLES[@]}"; do
    roles_yaml+="  - ${r}"$'\n'
  done

  # output.instructions のYAMLフォーマット
  local output_inst_yaml=""
  if [[ -n "$output_instructions" ]]; then
    output_inst_yaml="  instructions: |
    ${output_instructions}"
  else
    output_inst_yaml="  instructions: \"\""
  fi

  cat > "$CONFIG_FILE" << YAML_EOF
# ============================================================
# koumei-ai-team-framework 設定ファイル
# Generated by setup wizard v${VERSION}
# ============================================================

# === プロジェクト基本情報 ===
project:
  name: "${proj_name}"
  description: "${proj_desc}"
  path: "."

# === 移行プロジェクト設定 ===
migration:
  enabled: ${mig_enabled}
  source_path: "${mig_source}"
  source_framework: "${mig_source_fw}"
  target_framework: "${mig_target_fw}"

# === ロール構成 ===
# コアロール（commander, tech-lead, reviewer）は必須
# setup.sh --roles で後から変更可能
roles:
${roles_yaml}
# === スキルコマンド設定 ===
target_cli: "codex"
skill_prefix: "${skill_prefix}"

# === 指揮者設定 ===
commander:
  name: "${commander_name}"

# === 各ロール モデル設定 ===
models:
  commander: "gpt-5.3-codex"
  tech-lead: "gpt-5.3-codex"
  reviewer: "gpt-5.3-codex"
  analyst: "gpt-5.3-codex"
  ux-designer: "gpt-5.3-codex"

# === 技術スタック ===
tech_stack:
  language: "${lang}"
  framework: "${fw}"
  ui_library: "${ui_lib}"
  styling: "${styling}"
  database: "${db}"
  testing: "${testing}"
  build_command: "${build_cmd}"
  test_command: "${test_cmd}"
  dev_command: "${dev_cmd}"
  check_command: "${check_cmd}"

# === 成果物の出力設定 ===
output:
  dir: "${output_dir}"
  format: "md"
${output_inst_yaml}

# === Git運用 ===
git:
  main_branch: "${git_main}"
  develop_branch: "${git_develop}"
  branch_pattern: "${git_branch_pattern}"

# === カスタム指示（各ロールの指示ファイルに追記される） ===
custom_instructions:
  commander: ""
  tech-lead: ""
  reviewer: ""
  analyst: ""
  ux-designer: ""

# === 参照ドキュメント ===
reference_docs: []
YAML_EOF

  log_info "koumei.config.yaml を生成しました。"
  echo ""
}

# ロール変更ウィザード（既存config のロール部分だけ書き換え）
run_roles_wizard() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "koumei.config.yaml が見つかりません。先に setup.sh を実行してください。"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   ロール構成の変更                       ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

  # 現在のロールを表示
  echo ""
  echo -e "現在のロール構成:"
  local current_roles=()
  while IFS= read -r role; do
    [[ -n "$role" ]] && current_roles+=("$role")
  done < <(yaml_get_array "roles")
  echo -e "  ${GREEN}${current_roles[*]}${NC}"

  # 新しいロールを選択
  wizard_select_roles

  # config ファイルのロール部分を書き換え（Perl で）
  local roles_yaml=""
  for r in "${WIZARD_SELECTED_ROLES[@]}"; do
    roles_yaml+="  - ${r}\n"
  done

  perl -i -0777 -pe "
    s/^roles:\n(  - .+\n)+/roles:\n${roles_yaml}/m;
  " "$CONFIG_FILE"

  log_info "ロール構成を更新しました: ${WIZARD_SELECTED_ROLES[*]}"
  echo ""
  log_step "変更を反映するためにセットアップを実行します..."
  echo ""
}

# ============================================================
# YAML パーサー（yq優先、なければ簡易awkパーサー）
# ============================================================

# yq が利用可能かチェック
has_yq() {
  command -v yq &>/dev/null
}

# yq でYAML値を取得
yq_get() {
  local key="$1"
  yq eval "$key" "$CONFIG_FILE" 2>/dev/null
}

# awk ベースの簡易YAMLパーサー
# ネストされたキーは "." で区切る（例: "project.name"）
awk_yaml_get() {
  local key="$1"
  local file="$2"

  # トップレベルの単純なキー
  if [[ "$key" != *.* ]]; then
    awk -v key="$key" '
      $0 ~ "^"key":" { gsub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]+#.*/, ""); gsub(/["\x27]/, ""); print; exit }
    ' "$file"
    return
  fi

  # ネストされたキー（2レベルまで対応）
  local parent="${key%%.*}"
  local child="${key#*.}"

  awk -v parent="$parent" -v child="$child" '
    BEGIN { in_parent = 0 }
    $0 ~ "^"parent":" { in_parent = 1; next }
    in_parent && /^[a-zA-Z_]/ { in_parent = 0 }
    in_parent && $0 ~ "^[[:space:]]+"child":" {
      gsub(/^[[:space:]]+[^:]+:[[:space:]]*/, "")
      sub(/[[:space:]]+#.*/, "")
      gsub(/["\x27]/, "")
      print
      exit
    }
  ' "$file"
}

# YAML配列の要素を取得（rolesなど）
awk_yaml_get_array() {
  local key="$1"
  local file="$2"

  awk -v key="$key" '
    BEGIN { in_key = 0 }
    $0 ~ "^"key":" { in_key = 1; next }
    in_key && /^[a-zA-Z_]/ { exit }
    in_key && /^[[:space:]]*-[[:space:]]/ {
      gsub(/^[[:space:]]*-[[:space:]]*/, "")
      sub(/[[:space:]]+#.*/, "")
      gsub(/["\x27[:space:]]/, "")
      if ($0 !~ /^#/ && $0 != "") print
    }
  ' "$file"
}

# YAML複数行値を取得（custom_instructions等）
awk_yaml_get_multiline() {
  local parent="$1"
  local child="$2"
  local file="$3"

  awk -v parent="$parent" -v child="$child" '
    BEGIN { in_parent = 0; in_child = 0; indent = 0 }
    $0 ~ "^"parent":" { in_parent = 1; next }
    in_parent && /^[a-zA-Z_]/ { in_parent = 0 }
    in_parent && $0 ~ "^[[:space:]]+"child":[[:space:]]*\\|" {
      in_child = 1
      # インデントレベルを記録
      match($0, /^[[:space:]]+/)
      indent = RLENGTH + 2
      next
    }
    in_parent && in_child {
      # インデントが浅くなったら終了
      if ($0 !~ /^[[:space:]]*$/ && $0 !~ "^"sprintf("%*s", indent, "")) {
        exit
      }
      # インデントを削除して出力
      sub("^"sprintf("%*s", indent, ""), "")
      print
    }
  ' "$file"
}

# 統合的なYAML値取得関数
yaml_get() {
  local key="$1"
  if has_yq; then
    local result
    result=$(yq_get ".$key")
    # yq は値がない場合 "null" を返す
    if [[ "$result" == "null" || -z "$result" ]]; then
      echo ""
    else
      echo "$result"
    fi
  else
    awk_yaml_get "$key" "$CONFIG_FILE"
  fi
}

# 統合的なYAML配列取得関数
yaml_get_array() {
  local key="$1"
  if has_yq; then
    yq_get ".${key}[]" 2>/dev/null | grep -v '^$' || true
  else
    awk_yaml_get_array "$key" "$CONFIG_FILE"
  fi
}

# 統合的なYAML複数行値取得関数
yaml_get_multiline() {
  local parent="$1"
  local child="$2"
  if has_yq; then
    local result
    result=$(yq_get ".${parent}.${child}")
    if [[ "$result" == "null" || -z "$result" ]]; then
      echo ""
    else
      echo "$result"
    fi
  else
    awk_yaml_get_multiline "$parent" "$child" "$CONFIG_FILE"
  fi
}

# ============================================================
# 設定の読み込み
# ============================================================

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo ""
    log_warn "koumei.config.yaml が見つかりません。"
    echo ""
    if prompt_yn "初期設定ウィザードを開始しますか？" "y"; then
      run_wizard
    else
      log_info "手動で作成する場合はサンプルをコピーしてください:"
      log_info "  cp ${SCRIPT_DIR}/koumei.config.example.yaml ./${CONFIG_FILE}"
      exit 0
    fi
  fi

  log_step "設定ファイルを読み込み中..."

  # プロジェクト情報
  PROJECT_NAME=$(yaml_get "project.name")
  PROJECT_DESCRIPTION=$(yaml_get "project.description")
  PROJECT_PATH=$(yaml_get "project.path")

  # 移行設定
  MIGRATION_ENABLED=$(yaml_get "migration.enabled")
  MIGRATION_SOURCE_PATH=$(yaml_get "migration.source_path")
  MIGRATION_SOURCE_FRAMEWORK=$(yaml_get "migration.source_framework")
  MIGRATION_TARGET_FRAMEWORK=$(yaml_get "migration.target_framework")

  # スキルプレフィックス
  TARGET_CLI=$(yaml_get "target_cli")
  TARGET_CLI="${TARGET_CLI:-$DEFAULT_TARGET_CLI}"
  case "$TARGET_CLI" in
    codex)
      AI_CLI_NAME="Codex CLI"
      SKILLS_DIR=".codex/skills"
      AGENT_INSTRUCTIONS_FILENAME="AGENTS.md"
      ;;
    claude)
      AI_CLI_NAME="Claude Code"
      SKILLS_DIR=".claude/skills"
      AGENT_INSTRUCTIONS_FILENAME="CLAUDE.md"
      ;;
    *)
      log_warn "不明な target_cli '${TARGET_CLI}' のため codex として扱います。"
      TARGET_CLI="codex"
      AI_CLI_NAME="Codex CLI"
      SKILLS_DIR=".codex/skills"
      AGENT_INSTRUCTIONS_FILENAME="AGENTS.md"
      ;;
  esac

  # スキルプレフィックス
  SKILL_PREFIX=$(yaml_get "skill_prefix")
  SKILL_PREFIX="${SKILL_PREFIX:-koumei}"

  # 指揮者設定
  COMMANDER_NAME=$(yaml_get "commander.name")
  COMMANDER_NAME="${COMMANDER_NAME:-Commander}"

  # モデル設定
  MODEL_COMMANDER=$(yaml_get "models.commander")
  MODEL_TECH_LEAD=$(yaml_get "models.tech-lead")
  MODEL_REVIEWER=$(yaml_get "models.reviewer")
  MODEL_ANALYST=$(yaml_get "models.analyst")
  MODEL_UX_DESIGNER=$(yaml_get "models.ux-designer")
  if [[ "$TARGET_CLI" == "claude" ]]; then
    MODEL_COMMANDER="${MODEL_COMMANDER:-sonnet}"
    MODEL_TECH_LEAD="${MODEL_TECH_LEAD:-opus}"
    MODEL_REVIEWER="${MODEL_REVIEWER:-opus}"
    MODEL_ANALYST="${MODEL_ANALYST:-sonnet}"
    MODEL_UX_DESIGNER="${MODEL_UX_DESIGNER:-sonnet}"
  else
    MODEL_COMMANDER="${MODEL_COMMANDER:-gpt-5.3-codex}"
    MODEL_TECH_LEAD="${MODEL_TECH_LEAD:-gpt-5.3-codex}"
    MODEL_REVIEWER="${MODEL_REVIEWER:-gpt-5.3-codex}"
    MODEL_ANALYST="${MODEL_ANALYST:-gpt-5.3-codex}"
    MODEL_UX_DESIGNER="${MODEL_UX_DESIGNER:-gpt-5.3-codex}"
  fi

  # 技術スタック
  TECH_LANGUAGE=$(yaml_get "tech_stack.language")
  TECH_FRAMEWORK=$(yaml_get "tech_stack.framework")
  TECH_UI_LIBRARY=$(yaml_get "tech_stack.ui_library")
  TECH_STYLING=$(yaml_get "tech_stack.styling")
  TECH_DATABASE=$(yaml_get "tech_stack.database")
  TECH_TESTING=$(yaml_get "tech_stack.testing")
  BUILD_COMMAND=$(yaml_get "tech_stack.build_command")
  BUILD_COMMAND="${BUILD_COMMAND:-npm run build}"
  TEST_COMMAND=$(yaml_get "tech_stack.test_command")
  TEST_COMMAND="${TEST_COMMAND:-npm run test}"
  # lint/format チェック: デフォルトなし（空ならチェック工程をスキップ）
  CHECK_COMMAND=$(yaml_get "tech_stack.check_command")

  # Git設定
  GIT_MAIN_BRANCH=$(yaml_get "git.main_branch")
  GIT_MAIN_BRANCH="${GIT_MAIN_BRANCH:-main}"
  GIT_DEVELOP_BRANCH=$(yaml_get "git.develop_branch")
  GIT_BRANCH_PATTERN=$(yaml_get "git.branch_pattern")
  local default_branch_pattern='feature/task-{number}-{summary}'
  GIT_BRANCH_PATTERN="${GIT_BRANCH_PATTERN:-$default_branch_pattern}"

  # 成果物出力設定
  OUTPUT_DIR=$(yaml_get "output.dir")
  OUTPUT_DIR="${OUTPUT_DIR:-docs}"
  OUTPUT_FORMAT=$(yaml_get "output.format")
  OUTPUT_FORMAT="${OUTPUT_FORMAT:-md}"
  OUTPUT_INSTRUCTIONS=$(yaml_get_multiline "output" "instructions")

  # ロール一覧
  ROLES=()
  while IFS= read -r role; do
    [[ -n "$role" ]] && ROLES+=("$role")
  done < <(yaml_get_array "roles")

  # カスタム指示
  CUSTOM_INSTRUCTIONS_COMMANDER=$(yaml_get_multiline "custom_instructions" "commander")
  CUSTOM_INSTRUCTIONS_TECH_LEAD=$(yaml_get_multiline "custom_instructions" "tech-lead")
  CUSTOM_INSTRUCTIONS_REVIEWER=$(yaml_get_multiline "custom_instructions" "reviewer")
  CUSTOM_INSTRUCTIONS_ANALYST=$(yaml_get_multiline "custom_instructions" "analyst")
  CUSTOM_INSTRUCTIONS_UX_DESIGNER=$(yaml_get_multiline "custom_instructions" "ux-designer")

  # 参照ドキュメント
  REFERENCE_DOCS=""
  if has_yq; then
    local count
    count=$(yq_get '.reference_docs | length')
    if [[ "$count" != "0" && "$count" != "null" ]]; then
      for i in $(seq 0 $((count - 1))); do
        local path desc
        path=$(yq_get ".reference_docs[$i].path")
        desc=$(yq_get ".reference_docs[$i].description")
        REFERENCE_DOCS+="- \`${path}\` - ${desc}"$'\n'
      done
    fi
  fi

  # Perlテンプレートエンジン用に環境変数をエクスポート
  export KOUMEI_VAR_PROJECT_NAME="$PROJECT_NAME"
  export KOUMEI_VAR_PROJECT_DESCRIPTION="$PROJECT_DESCRIPTION"
  export KOUMEI_VAR_PROJECT_PATH="$PROJECT_PATH"
  export KOUMEI_VAR_TARGET_CLI="$TARGET_CLI"
  export KOUMEI_VAR_AI_CLI_NAME="$AI_CLI_NAME"
  export KOUMEI_VAR_SKILLS_DIR="$SKILLS_DIR"
  export KOUMEI_VAR_AGENT_INSTRUCTIONS_FILENAME="$AGENT_INSTRUCTIONS_FILENAME"
  export KOUMEI_VAR_COMMANDER_NAME="$COMMANDER_NAME"
  export KOUMEI_VAR_SKILL_PREFIX="$SKILL_PREFIX"
  export KOUMEI_VAR_BUILD_COMMAND="$BUILD_COMMAND"
  export KOUMEI_VAR_TEST_COMMAND="$TEST_COMMAND"
  export KOUMEI_VAR_CHECK_COMMAND="$CHECK_COMMAND"
  export KOUMEI_VAR_GIT_MAIN_BRANCH="$GIT_MAIN_BRANCH"
  export KOUMEI_VAR_GIT_DEVELOP_BRANCH="$GIT_DEVELOP_BRANCH"
  export KOUMEI_VAR_GIT_BRANCH_PATTERN="$GIT_BRANCH_PATTERN"
  export KOUMEI_VAR_MODEL_COMMANDER="$MODEL_COMMANDER"
  export KOUMEI_VAR_MODEL_TECH_LEAD="$MODEL_TECH_LEAD"
  export KOUMEI_VAR_MODEL_REVIEWER="$MODEL_REVIEWER"
  export KOUMEI_VAR_MODEL_ANALYST="$MODEL_ANALYST"
  export KOUMEI_VAR_MODEL_UX_DESIGNER="$MODEL_UX_DESIGNER"
  export KOUMEI_VAR_OUTPUT_DIR="$OUTPUT_DIR"
  export KOUMEI_VAR_OUTPUT_FORMAT="$OUTPUT_FORMAT"
  export KOUMEI_VAR_MIGRATION_SOURCE_PATH="$MIGRATION_SOURCE_PATH"
  export KOUMEI_VAR_MIGRATION_SOURCE_FRAMEWORK="$MIGRATION_SOURCE_FRAMEWORK"
  export KOUMEI_VAR_MIGRATION_TARGET_FRAMEWORK="$MIGRATION_TARGET_FRAMEWORK"

  log_info "プロジェクト: ${PROJECT_NAME}"
  log_info "対象CLI: ${AI_CLI_NAME}"
  log_info "ロール: ${ROLES[*]}"
  log_info "スキルプレフィックス: ${SKILL_PREFIX}"
}

# ============================================================
# ヘルパー関数
# ============================================================

# ロールが有効かチェック
has_role() {
  local target="$1"
  for role in "${ROLES[@]}"; do
    [[ "$role" == "$target" ]] && return 0
  done
  return 1
}

# 技術スタックテーブルを生成
generate_tech_stack_table() {
  local table="| 項目 | 技術 |"$'\n'
  table+="|------|------|"$'\n'
  [[ -n "$TECH_LANGUAGE" ]]    && table+="| 言語 | ${TECH_LANGUAGE} |"$'\n'
  [[ -n "$TECH_FRAMEWORK" ]]   && table+="| フレームワーク | ${TECH_FRAMEWORK} |"$'\n'
  [[ -n "$TECH_UI_LIBRARY" ]]  && table+="| UIライブラリ | ${TECH_UI_LIBRARY} |"$'\n'
  [[ -n "$TECH_STYLING" ]]     && table+="| スタイリング | ${TECH_STYLING} |"$'\n'
  [[ -n "$TECH_DATABASE" ]]    && table+="| データベース | ${TECH_DATABASE} |"$'\n'
  [[ -n "$TECH_TESTING" ]]     && table+="| テスト | ${TECH_TESTING} |"$'\n'
  [[ -n "$CHECK_COMMAND" ]]    && table+="| Lint/Format | \`${CHECK_COMMAND}\` |"$'\n'
  echo "$table"
}

# 有効ロール一覧テキストを生成
generate_active_roles_list() {
  local list=""
  for role in "${ROLES[@]}"; do
    [[ "$role" == "commander" ]] && continue
    [[ -n "$list" ]] && list+=", "
    list+="$role"
  done
  echo "$list"
}

# ワークフロー図を生成
generate_workflow_diagram() {
  local diagram="/${SKILL_PREFIX}-start"

  if has_role "analyst"; then
    diagram+=" → /${SKILL_PREFIX}-analyze"
  fi

  if has_role "ux-designer"; then
    diagram+=" → /${SKILL_PREFIX}-design（UX+技術 並列）"
  else
    diagram+=" → /${SKILL_PREFIX}-design-tech"
  fi

  diagram+=" → /${SKILL_PREFIX}-review → /${SKILL_PREFIX}-implement → /${SKILL_PREFIX}-review → /${SKILL_PREFIX}-status"

  echo "$diagram"
}

# 次ステップテキストを生成
generate_next_step_after_start() {
  if has_role "analyst"; then
    echo "次のステップ: /${SKILL_PREFIX}-analyze で既存システムの分析を開始してください。"
  elif has_role "ux-designer"; then
    echo "次のステップ: /${SKILL_PREFIX}-design でUX設計と技術設計を並列実行してください。"
  else
    echo "次のステップ: /${SKILL_PREFIX}-design-tech で技術設計を開始してください。"
  fi
}

generate_next_step_after_analyze() {
  if has_role "ux-designer"; then
    echo "次のステップ: /${SKILL_PREFIX}-design でUX設計と技術設計を並列実行してください。"
  else
    echo "次のステップ: /${SKILL_PREFIX}-design-tech で技術設計を開始してください。"
  fi
}

generate_next_step_after_design_tech() {
  if has_role "ux-designer"; then
    cat <<EOF
次のステップ:
- /${SKILL_PREFIX}-design-ux がまだなら実行してください
- 両方完了したら /${SKILL_PREFIX}-review でレビューを開始してください
EOF
  else
    echo "次のステップ: /${SKILL_PREFIX}-review でレビューを開始してください。"
  fi
}

# テンプレート変数を置換（全てファイルベースで処理）
process_template() {
  local input_content="$1"

  # 動的変数（関数で生成する値）を一時ファイルに書き出す
  local vars_dir
  vars_dir=$(mktemp -d)

  generate_active_roles_list > "${vars_dir}/ACTIVE_ROLES_LIST"
  generate_workflow_diagram > "${vars_dir}/WORKFLOW_DIAGRAM"
  generate_tech_stack_table > "${vars_dir}/TECH_STACK_TABLE"
  generate_next_step_after_start > "${vars_dir}/NEXT_STEP_AFTER_START"
  generate_next_step_after_analyze > "${vars_dir}/NEXT_STEP_AFTER_ANALYZE"
  generate_next_step_after_design_tech > "${vars_dir}/NEXT_STEP_AFTER_DESIGN_TECH"
  printf '%s' "$CUSTOM_INSTRUCTIONS_COMMANDER" > "${vars_dir}/CUSTOM_INSTRUCTIONS_COMMANDER"
  printf '%s' "$CUSTOM_INSTRUCTIONS_TECH_LEAD" > "${vars_dir}/CUSTOM_INSTRUCTIONS_TECH_LEAD"
  printf '%s' "$CUSTOM_INSTRUCTIONS_REVIEWER" > "${vars_dir}/CUSTOM_INSTRUCTIONS_REVIEWER"
  printf '%s' "$CUSTOM_INSTRUCTIONS_ANALYST" > "${vars_dir}/CUSTOM_INSTRUCTIONS_ANALYST"
  printf '%s' "$CUSTOM_INSTRUCTIONS_UX_DESIGNER" > "${vars_dir}/CUSTOM_INSTRUCTIONS_UX_DESIGNER"
  printf '%s' "$REFERENCE_DOCS" > "${vars_dir}/REFERENCE_DOCS"
  printf '%s' "$OUTPUT_INSTRUCTIONS" > "${vars_dir}/OUTPUT_INSTRUCTIONS"

  # 入力をファイルに書き出し
  local input_file
  input_file=$(mktemp)
  printf '%s' "$input_content" > "$input_file"

  # 全ての置換を1つのPerlスクリプトで実行
  local result
  result=$(perl -e '
    use strict;
    use warnings;

    my $vars_dir = $ARGV[0];
    my $input_file = $ARGV[1];

    # 入力ファイル読み込み
    open(my $fh, "<", $input_file) or die "Cannot open input: $!";
    local $/;
    my $content = <$fh>;
    close $fh;

    # 1. 環境変数ベースの置換（KOUMEI_VAR_* → 単純変数）
    my %env_vars;
    foreach my $key (keys %ENV) {
      if ($key =~ /^KOUMEI_VAR_(.+)$/) {
        $env_vars{$1} = $ENV{$key};
      }
    }
    # キー長い順にソートして部分マッチを防ぐ
    for my $key (sort { length($b) <=> length($a) } keys %env_vars) {
      my $val = $env_vars{$key};
      my $qkey = quotemeta($key);
      # 置換値をリテラルとして扱う（\Q...\E相当）
      $val =~ s/\\/\\\\/g;
      $val =~ s/\$/\\\$/g;
      $val =~ s/\@/\\\@/g;
      $content =~ s/\{\{$qkey\}\}/$val/g;
    }

    # 2. ファイルベースの置換（動的生成値）
    opendir(my $dh, $vars_dir) or die "Cannot open vars dir: $!";
    my @var_files = grep { -f "$vars_dir/$_" } readdir($dh);
    closedir $dh;

    for my $var_name (sort { length($b) <=> length($a) } @var_files) {
      open(my $vfh, "<", "$vars_dir/$var_name") or next;
      local $/;
      my $val = <$vfh>;
      close $vfh;
      $val = "" unless defined $val;
      my $qname = quotemeta($var_name);
      # 置換値をリテラルとして扱う
      $val =~ s/\\/\\\\/g;
      $val =~ s/\$/\\\$/g;
      $val =~ s/\@/\\\@/g;
      $content =~ s/\{\{$qname\}\}/$val/g;
    }

    print $content;
  ' "$vars_dir" "$input_file")

  rm -rf "$vars_dir" "$input_file"
  printf '%s' "$result"
}

# 条件ブロックを処理（Perl版）
process_conditions() {
  local content="$1"

  # 有効ロール一覧をカンマ区切りで
  local roles_csv
  roles_csv=$(printf '%s,' "${ROLES[@]}")

  local tmpfile_cond
  tmpfile_cond=$(mktemp)
  printf '%s' "$content" > "$tmpfile_cond"

  content=$(perl -e '
    use strict;
    my %active_roles = map { $_ => 1 } split(/,/, $ARGV[0]);
    my $migration = $ARGV[1] eq "true" ? 1 : 0;
    my $has_develop = length($ARGV[2]) > 0 ? 1 : 0;
    my $has_check = length($ARGV[3]) > 0 ? 1 : 0;

    open(my $fh, "<", $ARGV[4]) or die "Cannot open: $!";
    my @lines = <$fh>;
    close $fh;

    my @skip_stack;
    my @result;

    for my $line (@lines) {
      chomp $line;

      # {{#IF_ROLE role}}
      if ($line =~ /\{\{#IF_ROLE\s+(\S+)\}\}/) {
        my $role = $1;
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $active_roles{$role} ? 0 : 1;
        }
        next;
      }

      # {{#IF_NO_ROLE role}}
      if ($line =~ /\{\{#IF_NO_ROLE\s+(\S+)\}\}/) {
        my $role = $1;
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $active_roles{$role} ? 1 : 0;
        }
        next;
      }

      # {{#IF_MIGRATION}}
      if ($line =~ /\{\{#IF_MIGRATION\}\}/) {
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $migration ? 0 : 1;
        }
        next;
      }

      # {{#IF_DEVELOP_BRANCH}}
      if ($line =~ /\{\{#IF_DEVELOP_BRANCH\}\}/) {
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $has_develop ? 0 : 1;
        }
        next;
      }

      # {{#IF_NO_DEVELOP_BRANCH}}
      if ($line =~ /\{\{#IF_NO_DEVELOP_BRANCH\}\}/) {
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $has_develop ? 1 : 0;
        }
        next;
      }

      # {{#IF_CHECK_COMMAND}}
      if ($line =~ /\{\{#IF_CHECK_COMMAND\}\}/) {
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $has_check ? 0 : 1;
        }
        next;
      }

      # {{#IF_NO_CHECK_COMMAND}}
      if ($line =~ /\{\{#IF_NO_CHECK_COMMAND\}\}/) {
        if (@skip_stack && $skip_stack[-1]) {
          push @skip_stack, 1;
        } else {
          push @skip_stack, $has_check ? 1 : 0;
        }
        next;
      }

      # Closing tags
      if ($line =~ /\{\{\/(IF_ROLE|IF_NO_ROLE|IF_MIGRATION|IF_DEVELOP_BRANCH|IF_NO_DEVELOP_BRANCH|IF_CHECK_COMMAND|IF_NO_CHECK_COMMAND)\}\}/) {
        pop @skip_stack if @skip_stack;
        next;
      }

      # Output line if not skipping
      if (!@skip_stack || !$skip_stack[-1]) {
        push @result, $line;
      }
    }

    print join("\n", @result) . "\n";
  ' "$roles_csv" "$MIGRATION_ENABLED" "$GIT_DEVELOP_BRANCH" "$CHECK_COMMAND" "$tmpfile_cond")

  rm -f "$tmpfile_cond"
  echo "$content"
}

# ファイルがGit管理下かチェック
is_git_tracked() {
  local file="$1"
  git ls-files --error-unmatch "$file" &>/dev/null 2>&1
}

# 既存ファイルのバックアップ
backup_file() {
  local file="$1"
  local backup_dir=".agents/.backup"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_path="${backup_dir}/${file//\//_}.${timestamp}.bak"

  mkdir -p "$backup_dir"
  cp "$file" "$backup_path"
  log_info "バックアップ: ${file} → ${backup_path}"
}

# ファイルを書き出し（既存ファイル保護付き）
write_file() {
  local dest="$1"
  local content="$2"

  if $DRY_RUN; then
    log_info "[DRY-RUN] Would create: ${dest}"
    return
  fi

  # 既存ファイルがある場合の保護処理
  if [[ -f "$dest" ]]; then
    if is_git_tracked "$dest"; then
      # Git管理下 → 上書きしない
      log_warn "スキップ: ${dest}（Git管理下の既存ファイル）"
      return
    else
      # Git管理外 → バックアップしてから上書き
      backup_file "$dest"
    fi
  fi

  local dir
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  printf '%s\n' "$content" > "$dest"
  log_info "作成: ${dest}"
}

# ディレクトリを作成（.gitkeep付き）
create_dir_with_gitkeep() {
  local dir="$1"

  if $DRY_RUN; then
    log_info "[DRY-RUN] Would create dir: ${dir}"
    return
  fi

  mkdir -p "$dir"
  if [[ ! -f "${dir}/.gitkeep" ]]; then
    touch "${dir}/.gitkeep"
  fi
}

# ============================================================
# メイン処理
# ============================================================

do_clean() {
  log_step "展開済みファイルを削除中..."

  # スキルディレクトリ内のkoumei-ai-team-framework生成ファイルを削除
  local prefix="${SKILL_PREFIX:-koumei}"

  for skills_base in ".codex/skills" ".claude/skills"; do
    [[ -d "$skills_base" ]] || continue
    for dir in "${skills_base}"/${prefix}-*; do
      [[ -d "$dir" ]] && rm -rf "$dir" && log_info "削除: $dir"
    done
  done

  # .agents/ ディレクトリを削除（成果物も含む）
  if [[ -d ".agents" ]]; then
    rm -rf .agents
    log_info "削除: .agents/"
  fi

  log_info "クリーン完了"
}

do_setup() {
  local is_update=false
  [[ "$MODE" == "update" ]] && is_update=true

  if $is_update; then
    log_step "設定を再展開中（成果物は保持）..."
  else
    log_step "初回セットアップ開始..."
  fi

  # --- エージェント定義の展開 ---
  log_step "エージェント定義を展開中..."

  # TEAM.md
  local team_content
  team_content=$(cat "${TEMPLATES_DIR}/agents/TEAM.md.tmpl")
  team_content=$(process_template "$team_content")
  team_content=$(process_conditions "$team_content")
  write_file ".agents/TEAM.md" "$team_content"

  # コアロール
  for role_dir in commander tech-lead reviewer; do
    local tmpl="${TEMPLATES_DIR}/agents/core/${role_dir}/CLAUDE.md.tmpl"
    if [[ -f "$tmpl" ]]; then
      local content
      content=$(cat "$tmpl")
      content=$(process_template "$content")
      content=$(process_conditions "$content")
      write_file ".agents/${role_dir}/${AGENT_INSTRUCTIONS_FILENAME}" "$content"
    fi

    # 成果物ディレクトリ
    case "$role_dir" in
      commander)
        create_dir_with_gitkeep ".agents/commander/tasks"
        create_dir_with_gitkeep ".agents/commander/reports"
        create_dir_with_gitkeep ".agents/commander/requests"
        ;;
      tech-lead)
        create_dir_with_gitkeep ".agents/tech-lead/instructions"
        create_dir_with_gitkeep ".agents/tech-lead/deliverables"
        ;;
      reviewer)
        create_dir_with_gitkeep ".agents/reviewer/instructions"
        create_dir_with_gitkeep ".agents/reviewer/reviews"
        ;;
    esac
  done

  # オプションロール
  for role_dir in analyst ux-designer; do
    if has_role "$role_dir"; then
      local tmpl="${TEMPLATES_DIR}/agents/optional/${role_dir}/CLAUDE.md.tmpl"
      if [[ -f "$tmpl" ]]; then
        local content
        content=$(cat "$tmpl")
        content=$(process_template "$content")
        content=$(process_conditions "$content")
        write_file ".agents/${role_dir}/${AGENT_INSTRUCTIONS_FILENAME}" "$content"
      fi

      create_dir_with_gitkeep ".agents/${role_dir}/instructions"
      create_dir_with_gitkeep ".agents/${role_dir}/deliverables"
    fi
  done

  # --- スキルファイルの展開 ---
  log_step "スキルファイルを展開中..."

  # コアスキル
  for skill_dir in "${TEMPLATES_DIR}"/skills/core/koumei-*/; do
    local skill_name
    skill_name=$(basename "$skill_dir")
    # プレフィックスを置換
    local target_name="${skill_name/koumei-/${SKILL_PREFIX}-}"

    local tmpl="${skill_dir}SKILL.md.tmpl"
    if [[ -f "$tmpl" ]]; then
      local content
      content=$(cat "$tmpl")
      content=$(process_template "$content")
      content=$(process_conditions "$content")
      write_file "${SKILLS_DIR}/${target_name}/SKILL.md" "$content"
    fi
  done

  # オプションスキル
  for skill_dir in "${TEMPLATES_DIR}"/skills/optional/koumei-*/; do
    local skill_name
    skill_name=$(basename "$skill_dir")

    # スキルに対応するロールが有効かチェック
    local should_install=false
    case "$skill_name" in
      koumei-analyze)
        has_role "analyst" && should_install=true
        ;;
      koumei-design|koumei-design-ux)
        has_role "ux-designer" && should_install=true
        ;;
    esac

    if $should_install; then
      local target_name="${skill_name/koumei-/${SKILL_PREFIX}-}"
      local tmpl="${skill_dir}SKILL.md.tmpl"
      if [[ -f "$tmpl" ]]; then
        local content
        content=$(cat "$tmpl")
        content=$(process_template "$content")
        content=$(process_conditions "$content")
        write_file "${SKILLS_DIR}/${target_name}/SKILL.md" "$content"
      fi
    fi
  done

  # --- 完了 ---
  echo ""
  log_info "=============================="
  log_info "セットアップ完了!"
  log_info "=============================="
  echo ""
  log_info "利用可能なスキルコマンド:"
  log_info "  /${SKILL_PREFIX}-request   要件整理・指示書作成"
  log_info "  /${SKILL_PREFIX}-start     タスク定義・指示書作成"
  log_info "  /${SKILL_PREFIX}-run       全自動実行（設計→レビュー→実装→PR手前）"
  if has_role "analyst"; then
    log_info "  /${SKILL_PREFIX}-analyze   既存コード分析"
  fi
  if has_role "ux-designer"; then
    log_info "  /${SKILL_PREFIX}-design    UX+技術設計（並列実行）"
    log_info "  /${SKILL_PREFIX}-design-ux UX設計（単体実行）"
  fi
  log_info "  /${SKILL_PREFIX}-design-tech 技術設計"
  log_info "  /${SKILL_PREFIX}-review    レビュー"
  log_info "  /${SKILL_PREFIX}-implement 実装"
  log_info "  /${SKILL_PREFIX}-status    進捗確認"
  echo ""
  log_info "要件整理から始める場合は /${SKILL_PREFIX}-request を使ってください。"
  log_info "要件が明確な場合は /${SKILL_PREFIX}-start で直接タスクを開始できます。"
}

# ============================================================
# 実行
# ============================================================

# --init: ウィザードのみ実行（configなくてもOK）
if [[ "$MODE" == "init" ]]; then
  run_wizard
  # 生成後にセットアップも実行
  load_config
  do_setup
  exit 0
fi

# --roles: ロール変更のみ
if [[ "$MODE" == "roles" ]]; then
  load_config  # 既存config読み込み（yaml_get_array 用）
  run_roles_wizard
  load_config  # 更新されたconfigを再読み込み
  do_setup
  exit 0
fi

# 通常フロー
load_config

case "$MODE" in
  clean)  do_clean ;;
  *)      do_setup ;;
esac
