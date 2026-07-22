#!/bin/bash
# 孔明エージェントチーム — 操作ログ記録
# PostToolUse で呼ばれ、全操作を .agents/logs/ に記録する

LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.agents/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/$(date '+%Y-%m-%d').jsonl"

TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')

# ツール入力からファイルパスやコマンドを抽出（軽量に）
FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // .pattern // .command // empty' 2>/dev/null | head -c 200)

echo "{\"ts\":\"$TIMESTAMP\",\"tool\":\"$TOOL_NAME\",\"target\":\"$FILE_PATH\"}" >> "$LOG_FILE"
