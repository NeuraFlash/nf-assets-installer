#!/usr/bin/env bash
#
# nf-telemetry-skill-start.sh
#
# Claude Code PreToolUse hook, matcher: tool_name="Skill".
#
# This hook does NOT post an event. The collector at TELEMETRY_ENDPOINT
# expects a single per-invocation event (matching the MCP emitter's schema)
# posted on completion, so this hook only STASHES start-time state keyed by
# tool_use_id; the paired End hook reads the state, computes duration_ms,
# and ships the event.
#
# Contract: never block the tool call. Exits 0 on any failure.
#
# Configuration: TELEMETRY_ENDPOINT must be set (the gate that proves
# telemetry is configured on this machine). TELEMETRY_TOKEN is only needed
# by the End hook. Both are usually set by nf-telemetry-installer.

URL="${TELEMETRY_ENDPOINT:-}"
[ -z "$URL" ] && exit 0

command -v jq   >/dev/null 2>&1 || exit 0
command -v node >/dev/null 2>&1 || exit 0

input="$(cat)" 2>/dev/null || exit 0
[ -z "$input" ] && exit 0

skill=$(jq -r '.tool_input.skill // .tool_input.name // empty' <<<"$input" 2>/dev/null) || skill=""
tuid=$(jq -r  '.tool_use_id // empty'                          <<<"$input" 2>/dev/null) || tuid=""
[ -z "$skill" ] && exit 0
[ -z "$tuid" ]  && exit 0

state_dir="${TMPDIR:-/tmp}/nf-telemetry-pending-$(id -u)"
mkdir -p "$state_dir" 2>/dev/null || exit 0
chmod 700 "$state_dir" 2>/dev/null || true

started_ms=$(node -p 'Date.now()' 2>/dev/null) || exit 0
started_at=$(node -e 'process.stdout.write(new Date().toISOString())' 2>/dev/null) || exit 0

jq -nc \
  --arg skill "$skill" \
  --arg started_at "$started_at" \
  --argjson started_ms "$started_ms" \
  '{skill_name:$skill, started_at:$started_at, started_ms:$started_ms}' \
  > "$state_dir/$tuid.json" 2>/dev/null || true

exit 0
