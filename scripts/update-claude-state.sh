#!/usr/bin/env bash
set -euo pipefail

# 优化：采用更标准的 XDG 缓存变量定义
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dms-pet"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/claude-state.json"

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
SESSION=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

case "$EVENT" in
  SessionStart)             PET_STATE="waking" ;;
  PreToolUse)               PET_STATE="working" ;;
  PostToolUse)              PET_STATE="working" ;;
  UserPromptSubmit)         PET_STATE="working" ;;  # 新增：检测用户回车输入即刻激活，避免响应延迟空档
  PostToolUseFailure)       PET_STATE="error" ;;
  Stop)                     PET_STATE="idle" ;;
  StopFailure)              PET_STATE="error" ;;
  Notification)             PET_STATE="alert" ;;
  SessionEnd)               PET_STATE="sleeping" ;;
  *)                        PET_STATE="idle" ;;
esac

# 写入状态文件。updatedAt 使用本地时间戳便于 QML 进行过期判断
echo "{\"state\":\"$PET_STATE\",\"event\":\"$EVENT\",\"tool\":\"$TOOL\",\"session\":\"$SESSION\",\"timestamp\":\"$TIMESTAMP\",\"updatedAt\":$(date +%s)}" > "$STATE_FILE"
exit 0