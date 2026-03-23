#!/bin/bash
# ============================================================
# koumei-system セットアップスクリプト
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
    --update)  MODE="update" ;;
    --clean)   MODE="clean" ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "koumei-system setup v${VERSION}"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (none)      Initial setup"
      echo "  --update    Re-generate from config (preserves deliverables)"
      echo "  --clean     Remove all generated files"
      echo "  --dry-run   Preview without creating files"
      echo "  --help      Show this help"
      exit 0
      ;;
  esac
done

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
      $0 ~ "^"key":" { gsub(/^[^:]+:[[:space:]]*/, ""); gsub(/["\x27]/, ""); print; exit }
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
    log_error "設定ファイル '${CONFIG_FILE}' が見つかりません。"
    log_info "koumei.config.example.yaml をコピーして編集してください:"
    log_info "  cp ${SCRIPT_DIR}/koumei.config.example.yaml ./${CONFIG_FILE}"
    exit 1
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
  SKILL_PREFIX=$(yaml_get "skill_prefix")
  SKILL_PREFIX="${SKILL_PREFIX:-koumei}"

  # 指揮者設定
  COMMANDER_NAME=$(yaml_get "commander.name")
  COMMANDER_NAME="${COMMANDER_NAME:-Commander}"

  # モデル設定
  MODEL_COMMANDER=$(yaml_get "models.commander")
  MODEL_COMMANDER="${MODEL_COMMANDER:-sonnet}"
  MODEL_TECH_LEAD=$(yaml_get "models.tech-lead")
  MODEL_TECH_LEAD="${MODEL_TECH_LEAD:-opus}"
  MODEL_REVIEWER=$(yaml_get "models.reviewer")
  MODEL_REVIEWER="${MODEL_REVIEWER:-opus}"
  MODEL_ANALYST=$(yaml_get "models.analyst")
  MODEL_ANALYST="${MODEL_ANALYST:-sonnet}"
  MODEL_UX_DESIGNER=$(yaml_get "models.ux-designer")
  MODEL_UX_DESIGNER="${MODEL_UX_DESIGNER:-sonnet}"

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
  export KOUMEI_VAR_COMMANDER_NAME="$COMMANDER_NAME"
  export KOUMEI_VAR_SKILL_PREFIX="$SKILL_PREFIX"
  export KOUMEI_VAR_BUILD_COMMAND="$BUILD_COMMAND"
  export KOUMEI_VAR_TEST_COMMAND="$TEST_COMMAND"
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

    open(my $fh, "<", $ARGV[3]) or die "Cannot open: $!";
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

      # Closing tags
      if ($line =~ /\{\{\/(IF_ROLE|IF_NO_ROLE|IF_MIGRATION|IF_DEVELOP_BRANCH|IF_NO_DEVELOP_BRANCH)\}\}/) {
        pop @skip_stack if @skip_stack;
        next;
      }

      # Output line if not skipping
      if (!@skip_stack || !$skip_stack[-1]) {
        push @result, $line;
      }
    }

    print join("\n", @result) . "\n";
  ' "$roles_csv" "$MIGRATION_ENABLED" "$GIT_DEVELOP_BRANCH" "$tmpfile_cond")

  rm -f "$tmpfile_cond"
  echo "$content"
}

# ファイルを書き出し
write_file() {
  local dest="$1"
  local content="$2"

  if $DRY_RUN; then
    log_info "[DRY-RUN] Would create: ${dest}"
    return
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

  # スキルディレクトリ内のkoumei-system生成ファイルを削除
  local prefix="${SKILL_PREFIX:-koumei}"

  if [[ -d ".claude/skills" ]]; then
    for dir in .claude/skills/${prefix}-*; do
      [[ -d "$dir" ]] && rm -rf "$dir" && log_info "削除: $dir"
    done
  fi

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
      write_file ".agents/${role_dir}/CLAUDE.md" "$content"
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
        write_file ".agents/${role_dir}/CLAUDE.md" "$content"
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
      write_file ".claude/skills/${target_name}/SKILL.md" "$content"
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
        write_file ".claude/skills/${target_name}/SKILL.md" "$content"
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

load_config

case "$MODE" in
  clean)  do_clean ;;
  *)      do_setup ;;
esac
