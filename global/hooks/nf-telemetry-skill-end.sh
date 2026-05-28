#!/usr/bin/env bash
#
# nf-telemetry-skill-end.sh
#
# Claude Code PostToolUse hook, matcher: tool_name="Skill".
#
# Reads the start-time state stashed by nf-telemetry-skill-start.sh
# (keyed by tool_use_id), computes duration_ms, and POSTs a single event
# to TELEMETRY_ENDPOINT in the same wire format the mcp-telemetry-emitter
# server uses:
#
#     POST $TELEMETRY_ENDPOINT
#     Authorization: Bearer $TELEMETRY_TOKEN
#     Content-Type: application/json
#     { "events": [ <event> ] }
#
# The event matches the MCP emitter's shape so the collector accepts both
# hook-emitted and MCP-emitted events without schema changes. `source: "hook"`
# lets the collector dedupe when both fire for the same logical invocation
# (first-party skills running in Claude Code).
#
# Contract: never block the tool call. Exits 0 on any failure.

URL="${TELEMETRY_ENDPOINT:-}"
TOKEN="${TELEMETRY_TOKEN:-}"
[ -z "$URL" ]   && exit 0
[ -z "$TOKEN" ] && exit 0

command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v node >/dev/null 2>&1 || exit 0

input="$(cat)" 2>/dev/null || exit 0
[ -z "$input" ] && exit 0

tuid=$(jq -r '.tool_use_id // empty'         <<<"$input" 2>/dev/null) || tuid=""
err=$(jq -r  '.tool_response.error // empty' <<<"$input" 2>/dev/null) || err=""
[ -z "$tuid" ] && exit 0

state_dir="${TMPDIR:-/tmp}/nf-telemetry-pending-$(id -u)"
state_file="$state_dir/$tuid.json"
[ -f "$state_file" ] || exit 0

state="$(cat "$state_file" 2>/dev/null)" || exit 0
rm -f "$state_file"
[ -z "$state" ] && exit 0

skill=$(jq -r      '.skill_name // empty' <<<"$state")
started_at=$(jq -r '.started_at // empty' <<<"$state")
started_ms=$(jq -r '.started_ms // 0'     <<<"$state")
[ -z "$skill" ] && exit 0

ended_ms=$(node -p 'Date.now()' 2>/dev/null) || exit 0
ended_at=$(node -e 'process.stdout.write(new Date().toISOString())' 2>/dev/null) || exit 0
duration_ms=$(( ended_ms - started_ms ))

status="success"
[ -n "$err" ] && status="error"

# User id: prefer the explicit env var the MCP emitter uses; fall back to
# git config email; final fallback constructs <user>@neuraflash.com.
user_id="${CLAUDE_USER_EMAIL:-${TELEMETRY_EMAIL:-}}"
if [ -z "$user_id" ]; then
  guess="$(git config --global user.email 2>/dev/null || true)"
  case "$guess" in
    *@neuraflash.com) user_id="$guess" ;;
    *)                user_id="${USER:-unknown}@neuraflash.com" ;;
  esac
fi

event=$(jq -nc \
  --arg iid        "$tuid" \
  --arg skill      "$skill" \
  --arg status     "$status" \
  --arg user_id    "$user_id" \
  --arg surface    "claude_code" \
  --arg started_at "$started_at" \
  --arg ended_at   "$ended_at" \
  --argjson duration "$duration_ms" \
  --arg err        "$err" \
  '{
    invocation_id: $iid,
    skill_name:    $skill,
    status:        $status,
    user_id:       $user_id,
    surface:       $surface,
    started_at:    $started_at,
    ended_at:      $ended_at,
    duration_ms:   $duration,
    error_message: $err,
    source:        "hook",
    schema_version: 1
  } | with_entries(select(.value != ""))'
) 2>/dev/null || exit 0

curl -fsS --max-time 2 -X POST "$URL" \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d "{\"events\":[$event]}" >/dev/null 2>&1 || true

exit 0
