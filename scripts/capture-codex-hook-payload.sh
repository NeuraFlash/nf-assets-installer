#!/usr/bin/env bash
#
# capture-codex-hook-payload.sh
#
# One-shot diagnostic: registers catch-all hooks in ~/.codex/hooks.json that
# dump each invocation's stdin payload to ~/.nf-codex-capture/. We hook
# multiple events so we can figure out which one (if any) fires when a
# Codex skill loads / runs.
#
# Events captured:
#   - PreToolUse        (the one we hope skill invocations fire)
#   - PostToolUse       (paired with PreToolUse)
#   - SubagentStart     (in case skills are dispatched as subagents)
#   - SubagentStop      (paired with SubagentStart)
#   - UserPromptSubmit  (if the skill is triggered via a user message)
#
# Usage:
#   bash scripts/capture-codex-hook-payload.sh install
#       Install capture hooks. Restart Codex after this.
#
#   bash scripts/capture-codex-hook-payload.sh show
#       List captured payloads (newest first).
#
#   bash scripts/capture-codex-hook-payload.sh uninstall
#       Remove capture hooks.
#
# Hook entries are tagged with `nf-codex-capture` in the command string so
# they can be yanked without disturbing any user-managed hooks.

set -euo pipefail

CODEX_HOME="$HOME/.codex"
CODEX_HOOKS_JSON="$CODEX_HOME/hooks.json"
CAPTURE_DIR="$HOME/.nf-codex-capture"
HOOK_SCRIPT="$CAPTURE_DIR/dump-stdin.sh"

HOOK_TAG="nf-codex-capture"
EVENTS=(PreToolUse PostToolUse SubagentStart SubagentStop UserPromptSubmit)

log()  { printf '\033[1;34m[nf-capture]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[nf-capture]\033[0m %s\n' "$*" >&2; exit 1; }

require_node() {
  command -v node >/dev/null 2>&1 || fail "node is required to edit hooks.json."
}

cmd_install() {
  [ -d "$CODEX_HOME" ] || fail "~/.codex not found — Codex CLI doesn't appear to be installed."
  require_node

  mkdir -p "$CAPTURE_DIR"
  chmod 700 "$CAPTURE_DIR"

  cat > "$HOOK_SCRIPT" <<'HOOK_EOF'
#!/usr/bin/env bash
# Dumps stdin (the hook payload Codex sends) to a timestamped file.
# Argument $1 is the event label supplied by the wrapping hooks.json entry.
set -e
out_dir="$HOME/.nf-codex-capture"
mkdir -p "$out_dir"
chmod 700 "$out_dir" 2>/dev/null || true
ts="$(date +%Y%m%dT%H%M%S)"
ns="$(date +%N 2>/dev/null || echo 000000)"
label="${1:-unknown}"
cat > "$out_dir/${ts}-${ns}-${label}.json"
exit 0
HOOK_EOF
  chmod +x "$HOOK_SCRIPT"
  log "wrote capture hook script: $HOOK_SCRIPT"

  [ -f "$CODEX_HOOKS_JSON" ] || echo '{}' > "$CODEX_HOOKS_JSON"

  local tmp; tmp="$(mktemp)"
  HOOKS_FILE="$CODEX_HOOKS_JSON" HOOK="$HOOK_SCRIPT" TAG="$HOOK_TAG" \
  EVENTS="${EVENTS[*]}" OUT="$tmp" node -e '
    const fs = require("fs");
    const cfg = JSON.parse(fs.readFileSync(process.env.HOOKS_FILE, "utf8") || "{}");
    const events = process.env.EVENTS.split(/\s+/).filter(Boolean);
    cfg.hooks = cfg.hooks || {};
    const isOurs = (entry) =>
      (entry.hooks || []).some(h => h.command && h.command.includes(process.env.TAG));
    for (const ev of events) {
      const label = ev.toLowerCase();
      const cmd = `${process.env.HOOK} ${label}  # ${process.env.TAG}`;
      cfg.hooks[ev] = (cfg.hooks[ev] || []).filter(e => !isOurs(e));
      cfg.hooks[ev].push({
        matcher: ".*",
        hooks: [{ type: "command", command: cmd }]
      });
    }
    fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
  '
  mv "$tmp" "$CODEX_HOOKS_JSON"
  log "registered capture hooks for: ${EVENTS[*]}"
  log "wrote $CODEX_HOOKS_JSON"

  cat <<EOF

Next:
  1. Restart Codex (CLI and/or app) so it reloads hooks.json.
  2. Invoke a skill in Codex — either one of ours under ~/.codex/skills/
     or a third-party skill you want to track.
  3. Inspect what fired:
       ls -lt $CAPTURE_DIR
       cat \$(ls -t $CAPTURE_DIR/*.json | head -1)
  4. Paste a couple of representative payloads back so we can wire the
     real telemetry hooks (or pick a different approach if skills don't
     fire any of these events).
  5. When done:
       bash $0 uninstall
EOF
}

cmd_show() {
  if [ ! -d "$CAPTURE_DIR" ] || [ -z "$(ls -A "$CAPTURE_DIR" 2>/dev/null || true)" ]; then
    log "no captures in $CAPTURE_DIR"
    return 0
  fi
  log "captures in $CAPTURE_DIR (newest first):"
  ls -lt "$CAPTURE_DIR" | awk 'NR>1 {print "  " $0}'
}

cmd_uninstall() {
  if [ -f "$CODEX_HOOKS_JSON" ]; then
    require_node
    local tmp; tmp="$(mktemp)"
    HOOKS_FILE="$CODEX_HOOKS_JSON" TAG="$HOOK_TAG" OUT="$tmp" node -e '
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(process.env.HOOKS_FILE, "utf8") || "{}");
      const isOurs = (entry) =>
        (entry.hooks || []).some(h => h.command && h.command.includes(process.env.TAG));
      for (const ev of Object.keys(cfg.hooks || {})) {
        cfg.hooks[ev] = (cfg.hooks[ev] || []).filter(e => !isOurs(e));
        if (cfg.hooks[ev].length === 0) delete cfg.hooks[ev];
      }
      if (cfg.hooks && Object.keys(cfg.hooks).length === 0) delete cfg.hooks;
      fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
    '
    mv "$tmp" "$CODEX_HOOKS_JSON"
    log "removed capture hooks from $CODEX_HOOKS_JSON"
  fi

  if [ -f "$HOOK_SCRIPT" ]; then
    rm -f "$HOOK_SCRIPT"
    log "removed $HOOK_SCRIPT"
  fi

  log "capture dir left in place: $CAPTURE_DIR (delete manually if no longer needed)"
}

case "${1:-install}" in
  install)   cmd_install ;;
  show)      cmd_show ;;
  uninstall) cmd_uninstall ;;
  *)         fail "unknown command: $1 (expected: install | show | uninstall)" ;;
esac
