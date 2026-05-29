#!/usr/bin/env bash
#
# uninstall.sh
#
# Reverses what install.sh did:
#   - Removes ~/.claude/skills/<our-names>, ~/.claude/agents/<our-names>,
#     ~/.claude/commands/<our-names>, ~/.claude/hooks/nf-* files
#   - Removes ~/.codex/skills/<our-names>  (Codex destination)
#   - Removes ~/.codex/hooks/* files we installed
#   - Restores any SKILL.md.bak files left by the auto-wrap pass, so
#     third-party skills are returned to their original state
#   - Removes our SessionStart entries from ~/.claude/settings.json
#     and ~/.codex/hooks.json
#   - Strips the nf-assets marker block from ~/.claude/CLAUDE.md and
#     ~/.codex/AGENTS.md
#   - Removes MCP entries we installed (by name) from each tool's config
#
# Never touches ~/.codex/skills/.system/ (Codex's bundled-skill area).
#
# Does NOT remove the telemetry MCP — that's owned by nf-telemetry-installer.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
NF_BEGIN='<!-- BEGIN nf-assets — do not edit, rewritten on every install -->'
NF_END='<!-- END nf-assets -->'

log()  { printf '\033[1;34m[nf-assets]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[nf-assets]\033[0m %s\n' "$*" >&2; }

# Names to remove are derived from the source dirs.
skill_names() {
  for d in "$REPO_ROOT"/skills/*/; do
    n="$(basename "$d")"
    [ "$n" = "_template" ] || echo "$n"
  done
}
agent_names() {
  for f in "$REPO_ROOT"/agents/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    [ "$n" = "_template.md" ] || echo "$n"
  done
}
command_names() {
  for f in "$REPO_ROOT"/commands/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    [ "$n" = "_template.md" ] || echo "$n"
  done
}
mcp_names() {
  node -e '
    const fs = require("fs");
    const cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    for (const name of Object.keys(cfg.servers || {})) console.log(name);
  ' "$REPO_ROOT/mcp/servers.json"
}

strip_marker_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  local tmp; tmp="$(mktemp)"
  awk -v begin="$NF_BEGIN" -v end="$NF_END" '
    $0 == begin { skipping = 1; next }
    $0 == end   { skipping = 0; next }
    !skipping   { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  log "  stripped marker block from $file"
}

# Restore SKILL.md.bak files left by nf-wrap-skills.sh, so third-party
# skills are returned to their original (unwrapped) state on uninstall.
restore_wrap_bakups() {
  local root="$1"
  [ -d "$root" ] || return 0
  local bak skill_md restored=0
  for skill_dir in "$root"/*/; do
    [ -d "$skill_dir" ] || continue
    bak="${skill_dir%/}/SKILL.md.bak"
    skill_md="${skill_dir%/}/SKILL.md"
    if [ -f "$bak" ]; then
      mv "$bak" "$skill_md"
      restored=$((restored + 1))
    fi
  done
  if [ "$restored" -gt 0 ]; then
    log "  restored $restored unwrapped SKILL.md from .bak under $root"
  fi
}

# Remove our SessionStart entry from a JSON hooks/settings file. Tag is
# the substring we wrote into the command — the same marker used at
# install time so we can find ourselves without disturbing other entries.
strip_session_start_hook() {
  local file="$1" tag="$2"
  [ -f "$file" ] || return 0
  command -v node >/dev/null 2>&1 || return 0
  local tmp; tmp="$(mktemp)"
  FILE="$file" TAG="$tag" OUT="$tmp" node -e '
    const fs = require("fs");
    const cfg = JSON.parse(fs.readFileSync(process.env.FILE, "utf8") || "{}");
    if (!cfg.hooks || !cfg.hooks.SessionStart) {
      fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
      return;
    }
    const tag = process.env.TAG;
    cfg.hooks.SessionStart = cfg.hooks.SessionStart.filter(e =>
      !(e.hooks || []).some(h => h.command && h.command.includes(tag))
    );
    if (cfg.hooks.SessionStart.length === 0) delete cfg.hooks.SessionStart;
    if (Object.keys(cfg.hooks).length === 0) delete cfg.hooks;
    fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
  '
  mv "$tmp" "$file"
  log "  stripped $tag SessionStart entry from $file"
}

uninstall_claude() {
  local home="$HOME/.claude"
  [ -d "$home" ] || return 0
  log "Removing from $home"

  for n in $(skill_names); do
    if [ -d "$home/skills/$n" ]; then
      rm -rf "$home/skills/$n"
      log "  -claude skill: $n"
    fi
  done
  for n in $(agent_names); do
    if [ -f "$home/agents/$n" ]; then
      rm -f "$home/agents/$n"
      log "  -claude agent: $n"
    fi
  done
  for n in $(command_names); do
    if [ -f "$home/commands/$n" ]; then
      rm -f "$home/commands/$n"
      log "  -claude command: $n"
    fi
  done
  rm -f "$home/hooks/nf-telemetry-skill-start.sh" \
        "$home/hooks/nf-telemetry-skill-end.sh" \
        "$home/hooks/nf-wrap-skills.sh" \
        "$home/hooks/wrap-thirdparty-skill.sh" \
        "$home/hooks/SKILL_PREAMBLE.md" \
        "$home/hooks/SKILL_POSTAMBLE.md"

  # Restore any third-party SKILL.md files we wrapped.
  restore_wrap_bakups "$home/skills"

  # Drop our SessionStart entry from Claude's settings.
  strip_session_start_hook "$home/settings.json" "nf-wrap-skills"

  strip_marker_block "$home/CLAUDE.md"

  if command -v claude >/dev/null 2>&1; then
    for n in $(mcp_names); do
      if claude mcp remove "$n" --scope user >/dev/null 2>&1; then
        log "  -claude mcp: $n"
      fi
    done
  fi
}

uninstall_codex() {
  [ -d "$HOME/.codex" ] || return 0

  local codex_skills="$HOME/.codex/skills"
  if [ -d "$codex_skills" ]; then
    for n in $(skill_names); do
      # Never touch .system — that's Codex's bundled-skill area.
      [ "$n" = ".system" ] && continue
      if [ -d "$codex_skills/$n" ]; then
        rm -rf "$codex_skills/$n"
        log "  -codex skill: $n"
      fi
    done

    # Restore any third-party SKILL.md files we wrapped, including any
    # under .system/ defensively (we should never have wrapped them, but
    # if we ever did, restore is harmless).
    restore_wrap_bakups "$codex_skills"
  fi

  rm -f "$HOME/.codex/hooks/nf-wrap-skills.sh" \
        "$HOME/.codex/hooks/wrap-thirdparty-skill.sh" \
        "$HOME/.codex/hooks/SKILL_PREAMBLE.md" \
        "$HOME/.codex/hooks/SKILL_POSTAMBLE.md"

  strip_session_start_hook "$HOME/.codex/hooks.json" "nf-wrap-skills"

  strip_marker_block "$HOME/.codex/AGENTS.md"

  local cfg="$HOME/.codex/config.toml"
  if [ -f "$cfg" ]; then
    local tmp; tmp="$(mktemp)"
    awk '
      /^# BEGIN nf-assets mcp$/ { skipping = 1; next }
      /^# END nf-assets mcp$/   { skipping = 0; next }
      !skipping { print }
    ' "$cfg" > "$tmp"
    mv "$tmp" "$cfg"
    log "  stripped nf-assets mcp block from $cfg"
  fi
}

uninstall_claude
uninstall_codex

cat <<EOF

[nf-assets] uninstall complete.

Telemetry MCP is owned by nf-telemetry-installer — to remove it, run that
installer's uninstall script separately.
EOF
