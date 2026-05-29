#!/usr/bin/env bash
#
# install.sh
#
# Bootstrap installer for NeuraFlash AI coding assets. Skills follow the
# open Agent Skills specification (https://agentskills.io/specification),
# but each tool reads from its own home dir rather than a shared location.
#
# Each skills/<name>/ is a self-contained canonical SKILL.md folder. The
# installer copies those folders unchanged to:
#   - ~/.claude/skills/<name>/   (Claude Code)
#   - ~/.codex/skills/<name>/    (OpenAI Codex CLI + Codex app — both read
#                                 from the same CODEX_HOME)
#
# Codex reserves ~/.codex/skills/.system/ for its bundled system skills;
# this installer never writes there. After installing, restart Codex so
# it reloads the skill list.
#
# Idempotent — rerunning upgrades skills/agents/commands and re-merges global
# rules files + MCP entries.
#
# Surfaces handled (detected by presence of the corresponding home dir):
#   - Claude Code         (~/.claude)
#   - OpenAI Codex CLI    (~/.codex)
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

# Codex CLI (and Codex app — both surfaces read from CODEX_HOME)
CODEX_HOME="$HOME/.codex"
CODEX_SKILLS="$CODEX_HOME/skills"
CODEX_HOOKS="$CODEX_HOME/hooks"
CODEX_AGENTS_MD="$CODEX_HOME/AGENTS.md"
CODEX_CONFIG_TOML="$CODEX_HOME/config.toml"
CODEX_HOOKS_JSON="$CODEX_HOME/hooks.json"

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

  # nf-wrap-skills.sh runs wrap-thirdparty-skill.sh as a subprocess and
  # expects the preamble/postamble next to it, so co-locate them all.
  cp "$REPO_ROOT/scripts/wrap-thirdparty-skill.sh" "$CLAUDE_HOOKS/wrap-thirdparty-skill.sh"
  chmod +x "$CLAUDE_HOOKS/wrap-thirdparty-skill.sh"
  cp "$REPO_ROOT/global/SKILL_PREAMBLE.md"  "$CLAUDE_HOOKS/SKILL_PREAMBLE.md"
  cp "$REPO_ROOT/global/SKILL_POSTAMBLE.md" "$CLAUDE_HOOKS/SKILL_POSTAMBLE.md"

  command -v node >/dev/null 2>&1 || { warn "node missing — hooks copied but $CLAUDE_SETTINGS not wired."; return 0; }

  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
  local tmp; tmp="$(mktemp)"
  SETTINGS="$CLAUDE_SETTINGS" HOOKS_DIR="$CLAUDE_HOOKS" SKILLS_DIR="$CLAUDE_SKILLS" OUT="$tmp" node -e '
    const fs = require("fs");
    const startCmd = `${process.env.HOOKS_DIR}/nf-telemetry-skill-start.sh`;
    const endCmd   = `${process.env.HOOKS_DIR}/nf-telemetry-skill-end.sh`;
    const wrapCmd  = `NF_WRAP_PREAMBLE_DIR="${process.env.HOOKS_DIR}" "${process.env.HOOKS_DIR}/nf-wrap-skills.sh" "${process.env.SKILLS_DIR}"`;
    const cfg = JSON.parse(fs.readFileSync(process.env.SETTINGS, "utf8") || "{}");
    cfg.hooks = cfg.hooks || {};
    const tagsOurs = (entry, tag) =>
      (entry.hooks || []).some(h => h.command && h.command.includes(tag));
    const upsert = (event, matcher, tag, cmd) => {
      cfg.hooks[event] = (cfg.hooks[event] || []).filter(e => !tagsOurs(e, tag));
      const entry = { hooks: [{ type: "command", command: cmd }] };
      if (matcher) entry.matcher = matcher;
      cfg.hooks[event].push(entry);
    };
    upsert("PreToolUse",   "Skill", "nf-telemetry-skill-start", startCmd);
    upsert("PostToolUse",  "Skill", "nf-telemetry-skill-end",   endCmd);
    upsert("SessionStart", null,    "nf-wrap-skills",           wrapCmd);
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

# ---- Codex install ----------------------------------------------------------

# Installs skills into ~/.codex/skills/ (consumed by both the Codex CLI and
# the Codex app, which share CODEX_HOME), plus AGENTS.md rules and the
# config.toml MCP block. Codex reserves ~/.codex/skills/.system/ for its
# bundled system skills — install_skills_to never writes there because the
# source loop only iterates real skill folders in this repo.
install_codex() {
  [ -d "$CODEX_HOME" ] || { log "~/.codex not found — skipping Codex."; return 0; }

  log "Installing Codex skills into $CODEX_SKILLS"
  install_skills_to "$CODEX_SKILLS"

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

  install_codex_hooks
}

# Drops nf-wrap-skills.sh (+ preamble/postamble/wrap-thirdparty-skill.sh)
# into ~/.codex/hooks/ and registers a SessionStart entry in
# ~/.codex/hooks.json so any unwrapped SKILL.md gets wrapped at the start
# of every Codex session (covers skills the user installs between runs of
# this installer).
install_codex_hooks() {
  mkdir -p "$CODEX_HOOKS"

  cp "$REPO_ROOT/global/hooks/nf-wrap-skills.sh" "$CODEX_HOOKS/nf-wrap-skills.sh"
  chmod +x "$CODEX_HOOKS/nf-wrap-skills.sh"
  cp "$REPO_ROOT/scripts/wrap-thirdparty-skill.sh" "$CODEX_HOOKS/wrap-thirdparty-skill.sh"
  chmod +x "$CODEX_HOOKS/wrap-thirdparty-skill.sh"
  cp "$REPO_ROOT/global/SKILL_PREAMBLE.md"  "$CODEX_HOOKS/SKILL_PREAMBLE.md"
  cp "$REPO_ROOT/global/SKILL_POSTAMBLE.md" "$CODEX_HOOKS/SKILL_POSTAMBLE.md"
  log "  codex hook: nf-wrap-skills.sh (+ preamble/postamble)"

  command -v node >/dev/null 2>&1 || { warn "node missing — codex hooks copied but $CODEX_HOOKS_JSON not wired."; return 0; }

  [ -f "$CODEX_HOOKS_JSON" ] || echo '{}' > "$CODEX_HOOKS_JSON"
  local tmp; tmp="$(mktemp)"
  HOOKS_FILE="$CODEX_HOOKS_JSON" HOOKS_DIR="$CODEX_HOOKS" SKILLS_DIR="$CODEX_SKILLS" OUT="$tmp" node -e '
    const fs = require("fs");
    const wrapCmd = `NF_WRAP_PREAMBLE_DIR="${process.env.HOOKS_DIR}" "${process.env.HOOKS_DIR}/nf-wrap-skills.sh" "${process.env.SKILLS_DIR}"`;
    const cfg = JSON.parse(fs.readFileSync(process.env.HOOKS_FILE, "utf8") || "{}");
    cfg.hooks = cfg.hooks || {};
    const isOurs = (entry) =>
      (entry.hooks || []).some(h => h.command && h.command.includes("nf-wrap-skills"));
    cfg.hooks.SessionStart = (cfg.hooks.SessionStart || []).filter(e => !isOurs(e));
    cfg.hooks.SessionStart.push({ hooks: [{ type: "command", command: wrapCmd }] });
    fs.writeFileSync(process.env.OUT, JSON.stringify(cfg, null, 2) + "\n");
  '
  mv "$tmp" "$CODEX_HOOKS_JSON"
  log "  codex SessionStart hook wired into $CODEX_HOOKS_JSON"
}

# Runs the wrap pass synchronously over both skill roots so the user gets
# coverage immediately, not just after restarting their next session.
run_wrap_pass() {
  local script
  if [ -d "$CODEX_HOME" ] && [ -x "$CODEX_HOOKS/nf-wrap-skills.sh" ]; then
    script="$CODEX_HOOKS/nf-wrap-skills.sh"
    log "Wrapping unwrapped SKILL.md files under $CODEX_SKILLS"
    NF_WRAP_PREAMBLE_DIR="$CODEX_HOOKS" "$script" "$CODEX_SKILLS" || true
  fi
  if [ -d "$CLAUDE_HOME" ] && [ -x "$CLAUDE_HOOKS/nf-wrap-skills.sh" ]; then
    script="$CLAUDE_HOOKS/nf-wrap-skills.sh"
    log "Wrapping unwrapped SKILL.md files under $CLAUDE_SKILLS"
    NF_WRAP_PREAMBLE_DIR="$CLAUDE_HOOKS" "$script" "$CLAUDE_SKILLS" || true
  fi
}

# ---- Main -------------------------------------------------------------------

main() {
  log "nf-assets installer (version $(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo unknown))"

  install_claude
  install_claude_desktop_mcp
  install_codex
  run_wrap_pass

  cat <<EOF

[nf-assets] done.

Next steps:
  • Open a new Claude Code session to pick up new skills/agents/commands.
  • Restart Codex (CLI and app) so it reloads the skill list from ~/.codex/skills/.
  • Restart Claude Desktop if any MCP entries changed.
  • First-time MCP auth: as documented in mcp/servers.json descriptions.
EOF
}

main "$@"
