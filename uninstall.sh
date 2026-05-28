#!/usr/bin/env bash
#
# uninstall.sh
#
# Reverses what install.sh did (agentskills.io layout):
#   - Removes ~/.claude/skills/<our-names>, ~/.claude/agents/<our-names>,
#     ~/.claude/commands/<our-names>, ~/.claude/hooks/nf-telemetry-*.sh
#   - Removes ~/.agents/skills/<our-names>  (shared Codex+Gemini destination)
#   - Strips the nf-assets marker block from ~/.claude/CLAUDE.md,
#     ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md
#   - Removes MCP entries we installed (by name) from each tool's config
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
  rm -f "$home/hooks/nf-telemetry-skill-start.sh" "$home/hooks/nf-telemetry-skill-end.sh"

  strip_marker_block "$home/CLAUDE.md"

  if command -v claude >/dev/null 2>&1; then
    for n in $(mcp_names); do
      if claude mcp remove "$n" --scope user >/dev/null 2>&1; then
        log "  -claude mcp: $n"
      fi
    done
  fi
}

uninstall_agents_shared() {
  local agents_skills="$HOME/.agents/skills"
  if [ -d "$agents_skills" ]; then
    for n in $(skill_names); do
      if [ -d "$agents_skills/$n" ]; then
        rm -rf "$agents_skills/$n"
        log "  -shared skill: $n"
      fi
    done
  fi

  # Strip the nf-assets rules block from Codex's AGENTS.md if present
  if [ -d "$HOME/.codex" ]; then
    strip_marker_block "$HOME/.codex/AGENTS.md"

    # Strip the nf-assets mcp block from config.toml
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
  fi

  # Strip the nf-assets rules block from Gemini's GEMINI.md and remove
  # MCP entries from settings.json.
  if [ -d "$HOME/.gemini" ]; then
    strip_marker_block "$HOME/.gemini/GEMINI.md"

    if command -v node >/dev/null 2>&1; then
      local cfg="$HOME/.gemini/settings.json"
      if [ -f "$cfg" ]; then
        local tmp; tmp="$(mktemp)"
        NAMES="$(mcp_names | tr '\n' ',')" CFG="$cfg" OUT="$tmp" node -e '
          const fs = require("fs");
          const cfg = JSON.parse(fs.readFileSync(process.env.CFG, "utf8") || "{}");
          const names = (process.env.NAMES || "").split(",").filter(Boolean);
          cfg.mcpServers = cfg.mcpServers || {};
          for (const n of names) {
            if (cfg.mcpServers[n]) { delete cfg.mcpServers[n]; console.error(`[nf-assets]   -gemini mcp: ${n}`); }
          }
          fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
        '
        mv "$tmp" "$cfg"
      fi
    fi
  fi
}

uninstall_claude
uninstall_agents_shared

cat <<EOF

[nf-assets] uninstall complete.

Telemetry MCP is owned by nf-telemetry-installer — to remove it, run that
installer's uninstall script separately.
EOF
