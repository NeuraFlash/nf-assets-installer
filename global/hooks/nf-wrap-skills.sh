#!/usr/bin/env bash
#
# nf-wrap-skills.sh
#
# Idempotent scanner that wraps third-party SKILL.md files with the
# nf-assets telemetry preamble/postamble in place.
#
# Used in two contexts:
#   1) Called from install.sh at the end of every install to wrap whatever
#      is already on disk.
#   2) Wired as a SessionStart hook in Claude Code (~/.claude/settings.json)
#      and Codex (~/.codex/hooks.json) so skills installed AFTER nf-assets
#      get wrapped automatically next time the user opens a session.
#
# Contract: must never block the host. Exits 0 on every failure path; only
# logs to stderr.
#
# Behavior per SKILL.md file:
#   - Skips folders named .system or _template (Codex's bundled skills and
#     our own template, respectively).
#   - Skips files that already contain "## Step 0 — start telemetry".
#   - Skips files without YAML frontmatter (wrap script refuses them).
#   - On first wrap, copies the original to SKILL.md.bak alongside so
#     uninstall.sh can restore.
#
# Usage:
#   bash nf-wrap-skills.sh <skills-root-dir> [<skills-root-dir> ...]
#
# Examples:
#   bash nf-wrap-skills.sh ~/.codex/skills
#   bash nf-wrap-skills.sh ~/.codex/skills ~/.claude/skills
#
# Environment:
#   NF_WRAP_PREAMBLE_DIR — overrides the directory we look in for
#     SKILL_PREAMBLE.md / SKILL_POSTAMBLE.md. Default is computed relative
#     to this script's install location (../).

set -euo pipefail

# Resolve where the preamble/postamble live. When this script is installed
# into ~/.claude/hooks/ or ~/.codex/hooks/, install.sh also drops the
# preamble + postamble into the same hooks dir so we don't have to chase
# the repo root at runtime.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PREAMBLE_DIR="${NF_WRAP_PREAMBLE_DIR:-$SCRIPT_DIR}"
PREAMBLE="$PREAMBLE_DIR/SKILL_PREAMBLE.md"
POSTAMBLE="$PREAMBLE_DIR/SKILL_POSTAMBLE.md"
WRAP_SCRIPT="$PREAMBLE_DIR/wrap-thirdparty-skill.sh"

log() { printf '[nf-wrap-skills] %s\n' "$*" >&2; }

# Guard rails: silently no-op if our dependencies aren't present rather
# than blow up a session start.
[ -f "$PREAMBLE" ]    || { log "preamble missing at $PREAMBLE — skipping."; exit 0; }
[ -f "$POSTAMBLE" ]   || { log "postamble missing at $POSTAMBLE — skipping."; exit 0; }
[ -x "$WRAP_SCRIPT" ] || { log "wrap script missing/non-exec at $WRAP_SCRIPT — skipping."; exit 0; }

if [ "$#" -lt 1 ]; then
  log "usage: $0 <skills-root> [<skills-root> ...]"
  exit 0
fi

wrap_one() {
  local skill_md="$1"
  local parent_name bak tmp
  parent_name="$(basename "$(dirname "$skill_md")")"

  # Codex reserves .system/ for its bundled skills. Our own template lives
  # at skills/_template/ in the repo and may end up under a managed dir
  # too. Don't touch either.
  case "$parent_name" in
    .system|_template) return 0 ;;
  esac

  # Already wrapped? wrap-thirdparty-skill.sh would no-op, but checking
  # here avoids spawning a subprocess per skill in the common case.
  if grep -qE '^## Step 0 — start telemetry' "$skill_md" 2>/dev/null; then
    return 0
  fi

  # Refuse files without YAML frontmatter — wrap script would reject too,
  # but failing here keeps stderr cleaner.
  head -n1 "$skill_md" 2>/dev/null | grep -qE '^---[[:space:]]*$' || return 0

  # Preserve original once, before first wrap.
  bak="${skill_md}.bak"
  [ -f "$bak" ] || cp "$skill_md" "$bak"

  # Rewrite in place via a temp file so a mid-run failure leaves the
  # original intact (the .bak guarantees recovery either way).
  tmp="$(mktemp)"
  if NF_WRAP_PREAMBLE_DIR="$PREAMBLE_DIR" bash "$WRAP_SCRIPT" "$skill_md" "$tmp" 2>/dev/null; then
    mv "$tmp" "$skill_md"
    log "wrapped $skill_md"
  else
    rm -f "$tmp"
    log "wrap failed for $skill_md — leaving original in place"
  fi
}

for root in "$@"; do
  [ -d "$root" ] || continue
  for skill_dir in "$root"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_md="${skill_dir%/}/SKILL.md"
    [ -f "$skill_md" ] || continue
    wrap_one "$skill_md"
  done
done

exit 0
