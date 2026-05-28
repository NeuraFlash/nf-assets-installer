#!/usr/bin/env bash
#
# wrap-thirdparty-skill.sh
#
# Wrap a third-party SKILL.md with NeuraFlash's telemetry preamble/postamble
# (the same Step 0 / Step N blocks scripts/build-skills.sh applies to
# first-party skills) so the wrapped skill emits skill_start / skill_end
# even though it wasn't authored against the contract.
#
# When you need this:
#   • Claude Desktop: there's no PreToolUse hook on Desktop, so the only way
#     to get telemetry from a third-party skill is to wrap its SKILL.md
#     before uploading to the Team-license skills console.
#   • Claude Code: usually NOT needed — the PreToolUse hooks installed by
#     install.sh already capture every skill invocation. Only wrap if you
#     want belt-and-braces coverage (server-side dedupe on invocation_id
#     handles the double-emit).
#
# Usage:
#   scripts/wrap-thirdparty-skill.sh <path-to-original-SKILL.md> [output-path]
#
# If output-path is omitted, writes to stdout.
#
# Idempotent: if the source already contains a "## Step 0 — start telemetry"
# heading, the script copies the source through unchanged and exits 0 with
# a stderr warning.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREAMBLE="$ROOT/global/SKILL_PREAMBLE.md"
POSTAMBLE="$ROOT/global/SKILL_POSTAMBLE.md"

[ "$#" -ge 1 ] || { echo "Usage: $0 <path-to-SKILL.md> [output-path]" >&2; exit 2; }
SRC="$1"
OUT="${2:-/dev/stdout}"

[ -f "$SRC" ]       || { echo "[wrap] source not found: $SRC" >&2; exit 1; }
[ -f "$PREAMBLE" ]  || { echo "[wrap] missing $PREAMBLE" >&2; exit 1; }
[ -f "$POSTAMBLE" ] || { echo "[wrap] missing $POSTAMBLE" >&2; exit 1; }

if ! head -n1 "$SRC" | grep -qE '^---[[:space:]]*$'; then
  echo "[wrap] $SRC must start with YAML frontmatter (---). Refusing to wrap." >&2
  exit 1
fi

if grep -qE '^## Step 0 — start telemetry' "$SRC"; then
  echo "[wrap] $SRC already contains a Step 0 telemetry block — pass-through." >&2
  cat "$SRC" > "$OUT"
  exit 0
fi

# Same splicing logic as scripts/build-skills.sh — keep them in sync if you
# change the structure of the preamble/postamble blocks.
awk -v preamble="$PREAMBLE" -v postamble="$POSTAMBLE" '
  BEGIN { in_fm = 0; fm_done = 0 }
  NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }
  in_fm && /^---[[:space:]]*$/   { in_fm = 0; fm_done = 1; print
    print ""
    while ((getline line < preamble) > 0) print line
    close(preamble)
    next
  }
  in_fm { print; next }
  fm_done { print }
  END {
    print ""
    while ((getline line < postamble) > 0) print line
    close(postamble)
  }
' "$SRC" > "$OUT"

[ "$OUT" != "/dev/stdout" ] && echo "[wrap] wrote $OUT" >&2
exit 0
