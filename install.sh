#!/usr/bin/env bash
#
# install.sh
#
# Bootstrap installer for NeuraFlash AI coding assets, now conforming to the
# open Agent Skills specification at https://agentskills.io/specification.
#
# Each skills/<name>/ is a self-contained canonical SKILL.md folder. The
# installer copies those folders unchanged to:
#   - ~/.claude/skills/<name>/   (Claude Code)
#   - ~/.agents/skills/<name>/   (Codex CLI + Gemini CLI, shared per spec)
#
# Idempotent — rerunning upgrades skills/agents/commands and re-merges global
# rules files + MCP entries.
#
# Surfaces handled (detected by presence of the corresponding home dir):
#   - Claude Code         (~/.claude)
#   - OpenAI Codex CLI    (~/.codex)        — uses ~/.agents/skills/
#   - Google Antigravity  (~/.gemini)       — uses ~/.agents/skills/
#
# Claude Desktop config is also written if the Desktop app dir is present
# alongside ~/.claude. MCP entries flagged claude_desktop go there.
#
# Telemetry MCP is NOT installed here — run nf-telemetry-installer separately.
#
# Usage:
#   # From a clone of the source repo:
#   bash install.sh
#
#   # Direct, no clone (recommended for end users):
#   bash <(curl -fsSL https://raw.githubusercontent.com/neuraflash/nf-assets-installer/main/install.sh)

set -euo pipefail

# ---- Bootstrap (curl-pipe install) ------------------------------------------

MIRROR_REPO="${NF_MIRROR_REPO:-neuraflash/nf-assets-installer}"
MIRROR_TARBALL_URL="${NF_MIRROR_TARBALL_URL:-https://github.com/${MIRROR_REPO}/raw/main/latest.tar.gz}"

bootstrap() {
  command -v curl >/dev/null 2>&1 || { printf '[nf-assets] curl is required.\n' >&2; exit 1; }
  command -v tar  >/dev/null 2>&1 || { printf '[nf-assets] tar is required.\n' >&2; exit 1; }

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT INT TERM

  printf '[nf-assets] Fetching install payload from %s\n' "$MIRROR_TARBALL_URL"
  if ! curl -fsSL "$MIRROR_TARBALL_URL" -o "$tmp/payload.tar.gz"; then
    printf '[nf-assets] Failed to fetch payload tarball.\n' >&2
    exit 1
  fi

  mkdir -p "$tmp/payload"
  tar -xzf "$tmp/payload.tar.gz" -C "$tmp/payload"
  [ -f "$tmp/payload/install.sh" ] || { printf '[nf-assets] Tarball missing install.sh\n' >&2; exit 1; }

  local rc=0
  bash "$tmp/payload/install.sh" "$@" || rc=$?
  exit "$rc"
}

NF_SELF="${BASH_SOURCE[0]:-$0}"
NF_SELF_DIR=""
if [ -f "$NF_SELF" ]; then
  NF_SELF_DIR="$(cd "$(dirname "$NF_SELF")" 2>/dev/null && pwd || true)"
fi

if [ -z "${REPO_ROOT:-}" ] && { [ -z "$NF_SELF_DIR" ] || [ ! -f "$NF_SELF_DIR/mcp/servers.json" ]; }; then
  bootstrap "$@"
fi

# ---- Paths ------------------------------------------------------------------

REPO_ROOT="${REPO_ROOT:-$NF_SELF_DIR}"

# Source rules markdown — single canonical file
RULES_MD="$REPO_ROOT/global/CLAUDE.md"

# Claude Code
CLAUDE_HOME="$HOME/.claude"
CLAUDE_SKILLS="$CLAUDE_HOME/skills"
CLAUDE_AGENTS="$CLAUDE_HOME/agents"
CLAUDE_COMMANDS="$CLAUDE_HOME/commands"
CLAUDE_HOOKS="$CLAUDE_HOME/hooks"
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"

# Codex CLI
CODEX_HOME="$HOME/.codex"
CODEX_AGENTS_MD="$CODEX_HOME/AGENTS.md"
CODEX_CONFIG_TOML="$CODEX_HOME/config.toml"

# Antigravity / Gemini CLI
GEMINI_HOME="$HOME/.gemini"
GEMINI_MD="$GEMINI_HOME/GEMINI.md"
GEMINI_SETTINGS="$GEMINI_HOME/settings.json"

# Shared agentskills.io destination for Codex + Gemini
AGENTS_HOME="$HOME/.agents"
AGENTS_SKILLS="$AGENTS_HOME/skills"

# Claude Desktop
case "$(uname -s)" in
  Darwin)
    DESKTOP_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    DESKTOP_APP_DIR="$HOME/Library/Application Support/Claude"
    ;;
  Linux)
    DESKTOP_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/Claude/claude_desktop_config.json"
    DESKTOP_APP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Claude"
    ;;
  *)
    echo "Unsupported OS: $(uname -s). This script targets macOS and Linux." >&2
    exit 1
    ;;
esac

# Markers for the global-rules merge block — anything between these is owned
# by this installer and rewritten on every run.
NF_BEGIN='<!-- BEGIN nf-assets — do not edit, rewritten on every install -->'
NF_END='<!-- END nf-assets -->'

# ---- Logging ----------------------------------------------------------------

log()  { printf '\033[1;34m[nf-assets]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[nf-assets]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[nf-assets]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- Helpers ----------------------------------------------------------------

# Merge global rules file into a destination, idempotently bracketed by markers.
merge_global_rules() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  touch "$dst"

  local block_file
  block_file="$(mktemp)"
  {
    printf '%s\n' "$NF_BEGIN"
    cat "$src"
    printf '%s\n' "$NF_END"
  } > "$block_file"

  if grep -qF "$NF_BEGIN" "$dst"; then
    local tmp; tmp="$(mktemp)"
    awk -v begin="$NF_BEGIN" -v end="$NF_END" -v block_file="$block_file" '
      $0 == begin {
        while ((getline line < block_file) > 0) print line
        close(block_file)
        skipping = 1
        next
      }
      $0 == end   { skipping = 0; next }
      !skipping   { print }
    ' "$dst" > "$tmp"
    mv "$tmp" "$dst"
  else
    {
      [ -s "$dst" ] && echo
      cat "$block_file"
    } >> "$dst"
  fi

  rm -f "$block_file"
}

# Copy every skills/<name>/ folder (sans _template) to a destination root.
# Removes dest/<name>/ first for a clean overwrite. Skips folders without a
# SKILL.md (defensive).
install_skills_to() {
  local dest="$1"
  mkdir -p "$dest"
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    local name
    name="$(basename "$skill_dir")"
    [ "$name" = "_template" ] && continue
    [ -f "$skill_dir/SKILL.md" ] || { warn "skill $name has no SKILL.md, skipping"; continue; }
    local target="$dest/$name"
    rm -rf "$target"
    cp -R "$skill_dir" "$target"
    log "  skill -> $target"
  done
}

# ---- Claude Code install ----------------------------------------------------

install_claude() {
  [ -d "$CLAUDE_HOME" ] || { log "~/.claude not found — skipping Claude Code."; return 0; }
  log "Installing into $CLAUDE_HOME"
  mkdir -p "$CLAUDE_SKILLS" "$CLAUDE_AGENTS" "$CLAUDE_COMMANDS" "$CLAUDE_HOOKS"

  # Skills — copy each skills/<name>/ folder unchanged
  install_skills_to "$CLAUDE_SKILLS"

  # Agents (Claude-only)
  for f in "$REPO_ROOT"/agents/*.md; do
    [ -e "$f" ] || continue
    local name; name="$(basename "$f")"
    [ "$name" = "_template.md" ] && continue
    cp "$f" "$CLAUDE_AGENTS/$name"
    log "  claude agent: $name"
  done

  # Commands (Claude-only)
  for f in "$REPO_ROOT"/commands/*.md; do
    [ -e "$f" ] || continue
    local name; name="$(basename "$f")"
    [ "$name" = "_template.md" ] && continue
    cp "$f" "$CLAUDE_COMMANDS/$name"
    log "  claude command: $name"
  done

  # Global rules → ~/.claude/CLAUDE.md
  merge_global_rules "$RULES_MD" "$CLAUDE_MD"
  log "  claude rules: merged into $CLAUDE_MD"

  # MCP servers (claude_code surface)
  if command -v claude >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    SERVERS="$REPO_ROOT/mcp/servers.json" node -e '
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(process.env.SERVERS, "utf8"));
      const out = [];
      for (const [name, def] of Object.entries(cfg.servers || {})) {
        if (!(def.surfaces || []).includes("claude_code")) continue;
        out.push({ name, def });
      }
      process.stdout.write(JSON.stringify(out));
    ' | python3 -c '
import json, os, subprocess, sys
for entry in json.loads(sys.stdin.read()):
    name, d = entry["name"], entry["def"]
    subprocess.run(["claude", "mcp", "remove", name, "--scope", d.get("scope", "user")],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    flags = ["--scope", d.get("scope", "user")]
    for k, v in (d.get("env") or {}).items():
        flags += ["--env", f"{k}={v}"]
    cmd = ["claude", "mcp", "add", name, *flags, "--", d["command"], *d.get("args", [])]
    subprocess.check_call(cmd)
    print(f"[nf-assets]   claude mcp: {name}")
'
  else
    warn "claude CLI or node missing — Claude MCP entries skipped."
  fi

  # Telemetry hooks (Claude-only; Codex/Gemini have no hook equivalent)
  install_claude_hooks
}

install_claude_hooks() {
  command -v claude >/dev/null 2>&1 || return 0

  local hooks_src="$REPO_ROOT/global/hooks"
  [ -d "$hooks_src" ] || return 0

  for f in "$hooks_src"/*.sh; do
    [ -e "$f" ] || continue
    local name; name="$(basename "$f")"
    cp "$f" "$CLAUDE_HOOKS/$name"
    chmod +x "$CLAUDE_HOOKS/$name"
    log "  claude hook: $name"
  done

  command -v node >/dev/null 2>&1 || { warn "node missing — hooks copied but $CLAUDE_SETTINGS not wired."; return 0; }

  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
  local tmp; tmp="$(mktemp)"
  SETTINGS="$CLAUDE_SETTINGS" HOOKS_DIR="$CLAUDE_HOOKS" OUT="$tmp" node -e '
    const fs = require("fs");
    const startCmd = `${process.env.HOOKS_DIR}/nf-telemetry-skill-start.sh`;
    const endCmd   = `${process.env.HOOKS_DIR}/nf-telemetry-skill-end.sh`;
    const cfg = JSON.parse(fs.readFileSync(process.env.SETTINGS, "utf8") || "{}");
    cfg.hooks = cfg.hooks || {};
    const isOurs = (entry) =>
      (entry.hooks || []).some(h => h.command && h.command.includes("nf-telemetry-skill-"));
    const upsert = (event, cmd) => {
      cfg.hooks[event] = (cfg.hooks[event] || []).filter(e => !isOurs(e));
      cfg.hooks[event].push({ matcher: "Skill", hooks: [{ type: "command", command: cmd }] });
    };
    upsert("PreToolUse",  startCmd);
    upsert("PostToolUse", endCmd);
    fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
  '
  mv "$tmp" "$CLAUDE_SETTINGS"
  log "  claude hooks wired into $CLAUDE_SETTINGS"
}

# Claude Desktop MCP merge (lives next to Claude Code install)
install_claude_desktop_mcp() {
  [ -d "$DESKTOP_APP_DIR" ] || return 0
  command -v node >/dev/null 2>&1 || { warn "node missing — Claude Desktop MCP skipped."; return 0; }

  [ -f "$DESKTOP_CFG" ] || echo '{}' > "$DESKTOP_CFG"
  local tmp; tmp="$(mktemp)"
  SERVERS="$REPO_ROOT/mcp/servers.json" CFG="$DESKTOP_CFG" OUT="$tmp" node -e '
    const fs = require("fs");
    const src = JSON.parse(fs.readFileSync(process.env.SERVERS, "utf8"));
    const cfg = JSON.parse(fs.readFileSync(process.env.CFG, "utf8") || "{}");
    cfg.mcpServers = cfg.mcpServers || {};
    for (const [name, def] of Object.entries(src.servers || {})) {
      if (!(def.surfaces || []).includes("claude_desktop")) continue;
      cfg.mcpServers[name] = {
        command: def.command,
        args:    def.args || [],
        env:     def.env || {}
      };
      console.error(`[nf-assets]   claude desktop mcp: ${name}`);
    }
    fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
  '
  mv "$tmp" "$DESKTOP_CFG"
}

# ---- Codex + Gemini shared install ------------------------------------------

# Single function that handles ~/.agents/skills/ for Codex AND Gemini,
# plus each tool's own rules-file merge and MCP-config write.
install_agents_shared() {
  local have_codex=0 have_gemini=0
  [ -d "$CODEX_HOME"  ] && have_codex=1
  [ -d "$GEMINI_HOME" ] && have_gemini=1
  if [ "$have_codex" -eq 0 ] && [ "$have_gemini" -eq 0 ]; then
    log "neither ~/.codex nor ~/.gemini found — skipping shared agents install."
    return 0
  fi

  # 1) Shared skill folders — written once, consumed by both Codex and Gemini
  log "Installing shared skills into $AGENTS_SKILLS"
  install_skills_to "$AGENTS_SKILLS"

  # 2) Codex-specific: AGENTS.md rules + config.toml MCP block
  if [ "$have_codex" -eq 1 ]; then
    log "Installing Codex CLI bits into $CODEX_HOME"
    merge_global_rules "$RULES_MD" "$CODEX_AGENTS_MD"
    log "  codex rules: merged into $CODEX_AGENTS_MD"

    if command -v node >/dev/null 2>&1; then
      [ -f "$CODEX_CONFIG_TOML" ] || touch "$CODEX_CONFIG_TOML"
      SERVERS="$REPO_ROOT/mcp/servers.json" CFG="$CODEX_CONFIG_TOML" node -e '
        const fs = require("fs");
        const path = process.env.CFG;
        const src = JSON.parse(fs.readFileSync(process.env.SERVERS, "utf8"));

        const tomlEscape = (s) => String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");

        const renderEntry = (name, def) => {
          const lines = [];
          lines.push(`[mcp_servers.${name}]`);
          lines.push(`command = "${tomlEscape(def.command)}"`);
          const args = (def.args || []).map(a => `"${tomlEscape(a)}"`).join(", ");
          lines.push(`args = [${args}]`);
          const env = def.env || {};
          const envPairs = Object.entries(env)
            .map(([k, v]) => `${k} = "${tomlEscape(v)}"`).join(", ");
          lines.push(`env = { ${envPairs} }`);
          return lines.join("\n") + "\n";
        };

        let body = fs.readFileSync(path, "utf8");
        const MARK_BEGIN = "# BEGIN nf-assets mcp\n";
        const MARK_END   = "# END nf-assets mcp\n";

        let block = MARK_BEGIN;
        for (const [name, def] of Object.entries(src.servers || {})) {
          if (!(def.surfaces || []).includes("codex_cli")) continue;
          block += renderEntry(name, def) + "\n";
          console.error(`[nf-assets]   codex mcp: ${name}`);
        }
        block += MARK_END;

        const beginIdx = body.indexOf(MARK_BEGIN);
        const endIdx   = body.indexOf(MARK_END);
        if (beginIdx >= 0 && endIdx > beginIdx) {
          body = body.slice(0, beginIdx) + block + body.slice(endIdx + MARK_END.length);
        } else {
          body = body.trimEnd() + (body ? "\n\n" : "") + block;
        }
        fs.writeFileSync(path, body);
      '
    else
      warn "node missing — Codex MCP entries skipped."
    fi
  fi

  # 3) Gemini-specific: GEMINI.md rules + settings.json MCP block
  if [ "$have_gemini" -eq 1 ]; then
    log "Installing Gemini CLI bits into $GEMINI_HOME"
    merge_global_rules "$RULES_MD" "$GEMINI_MD"
    log "  gemini rules: merged into $GEMINI_MD"

    if command -v node >/dev/null 2>&1; then
      [ -f "$GEMINI_SETTINGS" ] || echo '{}' > "$GEMINI_SETTINGS"
      local tmp; tmp="$(mktemp)"
      SERVERS="$REPO_ROOT/mcp/servers.json" CFG="$GEMINI_SETTINGS" OUT="$tmp" node -e '
        const fs = require("fs");
        const src = JSON.parse(fs.readFileSync(process.env.SERVERS, "utf8"));
        const cfg = JSON.parse(fs.readFileSync(process.env.CFG, "utf8") || "{}");
        cfg.mcpServers = cfg.mcpServers || {};
        for (const [name, def] of Object.entries(src.servers || {})) {
          if (!(def.surfaces || []).includes("gemini_cli")) continue;
          cfg.mcpServers[name] = {
            command: def.command,
            args:    def.args || [],
            env:     def.env || {}
          };
          console.error(`[nf-assets]   gemini mcp: ${name}`);
        }
        fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
      '
      mv "$tmp" "$GEMINI_SETTINGS"
    else
      warn "node missing — Gemini MCP entries skipped."
    fi
  fi
}

# ---- Main -------------------------------------------------------------------

main() {
  log "nf-assets installer (version $(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo unknown))"

  install_claude
  install_claude_desktop_mcp
  install_agents_shared

  cat <<EOF

[nf-assets] done.

Next steps:
  • Open a new Claude Code session to pick up new skills/agents/commands.
  • Restart Claude Desktop if any MCP entries changed.
  • First-time MCP auth: as documented in mcp/servers.json descriptions.
EOF
}

main "$@"
