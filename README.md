# nf-assets-installer

Public install payload for [NeuraFlash](https://neuraflash.com)'s internal AI
coding assets — skills, subagents, slash commands, global rules, and MCP
server wiring for **Claude Code**, **OpenAI Codex CLI**, and **Google
Antigravity / Gemini CLI**.

Skills conform to the open [Agent Skills specification](https://agentskills.io/specification)
and install into each tool's standard location.

> ⚠️ Auto-published from a private source repo on every release tag.
> Don't open PRs or push directly — your changes will be wiped on the next
> publish.

## Install

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/NeuraFlash/nf-assets-installer/main/install.sh)
```

That one-liner downloads the latest payload tarball into a temp dir and runs
the installer from there — no clone, no manual unpack. Idempotent: rerun any
time to upgrade.

The installer auto-detects which AI coding tools you have installed by
checking for `~/.claude`, `~/.codex`, and `~/.gemini`. It installs into every
detected tool and skips the rest silently.

## Uninstall

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/NeuraFlash/nf-assets-installer/main/uninstall.sh)
```

Removes only what the installer added. Anything outside the `nf-assets`
marker blocks in `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and
`~/.gemini/GEMINI.md` is preserved.

## What gets installed

| Asset            | Destination                                                       | Tool                         |
| ---------------- | ----------------------------------------------------------------- | ---------------------------- |
| Skills           | `~/.claude/skills/<name>/SKILL.md`                                | Claude Code                  |
| Skills           | `~/.agents/skills/<name>/SKILL.md`                                | Codex CLI + Gemini CLI       |
| Subagents        | `~/.claude/agents/`                                               | Claude Code                  |
| Slash commands   | `~/.claude/commands/`                                             | Claude Code                  |
| Global rules     | `~/.claude/CLAUDE.md` (between markers)                           | Claude Code                  |
| Global rules     | `~/.codex/AGENTS.md` (between markers)                            | Codex CLI                    |
| Global rules     | `~/.gemini/GEMINI.md` (between markers)                           | Gemini CLI                   |
| Telemetry hooks  | `~/.claude/hooks/` + `~/.claude/settings.json`                    | Claude Code                  |
| MCP servers      | `claude mcp add` (Code) + `claude_desktop_config` (Desktop)       | Claude Code + Desktop        |
| MCP servers      | `~/.codex/config.toml` (`[mcp_servers.*]` tables)                 | Codex CLI                    |
| MCP servers      | `~/.gemini/settings.json` (`mcpServers` object)                   | Gemini CLI                   |

`~/.agents/skills/` is the cross-tool location both Codex CLI and Gemini CLI
natively read from, so it serves both tools from a single copy.

### MCP servers wired

| Name             | Purpose                                          | First-use auth                                              |
| ---------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| `context7`       | Library / framework / API docs lookup            | none                                                        |
| `gdrive`         | Google Drive — list, search, read files          | `npx -y @modelcontextprotocol/server-gdrive auth` once      |
| `lucid`          | Lucidchart / Lucidspark — search, read, generate | browser OAuth on first call                                 |
| `atlassian`      | Jira + Confluence                                | browser OAuth on first call                                 |
| `salesforce-dx`  | Salesforce orgs, metadata, data, users, testing  | `sf org login web` (requires `sf` CLI)                      |
| `knowledge-base` | NeuraFlash shared Knowledge Base                 | none (bearer token wired in)                                |

> The **telemetry MCP** is intentionally not installed here — install it
> separately via [`nf-telemetry-installer`](https://github.com/NeuraFlash/nf-telemetry-installer).

## Telemetry coverage

Each `SKILL.md` includes inline Step 0 (`telemetry.skill_start`) and Step N
(`telemetry.skill_end`) blocks calling the shared telemetry MCP. The blocks
are tool-agnostic and run identically on Claude Code, Codex CLI, and Gemini
CLI.

On **Claude Code only**, the installer also wires `PreToolUse` /
`PostToolUse` hooks that capture every skill invocation — first-party,
third-party, anything — so coverage extends to skills that don't emit
telemetry themselves. Codex and Gemini have no hook system; for them,
telemetry is in-skill only.

Both code paths read the same env vars:

```sh
export TELEMETRY_ENDPOINT="<collector URL>"
export TELEMETRY_TOKEN="<bearer token>"
```

If you've already run [`nf-telemetry-installer`](https://github.com/NeuraFlash/nf-telemetry-installer)
these are typically set for you.

## Requirements

- macOS or Linux
- `curl`, `tar`, `bash` (preinstalled on macOS / most Linux distros)
- Node 18+
- At least one of: Claude Code (`claude` CLI), OpenAI Codex CLI, or Google
  Gemini CLI / Antigravity
- Salesforce CLI (`sf`) — only if you use the `salesforce-dx` MCP

The installer skips any tool whose home directory isn't present. If `node` is
missing, MCP-config writes are skipped with a clear message.

## Verifying the install

```sh
# Claude Code
claude mcp list
ls ~/.claude/skills

# Codex CLI / Gemini CLI (shared)
ls ~/.agents/skills
```

You should see the wired MCP servers and the installed skill folders.

## Pinning a specific version

The current version is in [`VERSION`](./VERSION). Versioned tarballs ship with
every release if you'd rather not always run `latest`:

```sh
VERSION=0.5.0
curl -fsSL "https://github.com/NeuraFlash/nf-assets-installer/raw/main/nf-assets-${VERSION}.tar.gz" -o assets.tar.gz
mkdir -p assets && tar -xzf assets.tar.gz -C assets
bash assets/install.sh
```

## License

UNLICENSED — internal NeuraFlash use only.
