#!/usr/bin/env bash
#
# validate.sh
#
# Validates every skills/<name>/SKILL.md against the open Agent Skills
# specification at https://agentskills.io/specification.
#
# Checks per skill:
#   - SKILL.md exists in the folder
#   - Frontmatter has required `name` and `description`
#   - `name` matches the parent directory name
#   - `name` is 1-64 chars and matches /^[a-z0-9]+(-[a-z0-9]+)*$/
#   - `description` is 1-1024 chars and non-empty

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { printf '\033[1;31m[validate] FAIL\033[0m %s\n' "$*" >&2; failed=1; }
pass() { printf '\033[1;32m[validate] OK\033[0m   %s\n' "$*"; }

failed=0
checked=0

read_fm_field() {
  awk -v f="$2" '
    BEGIN { in_fm=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm {
      if (match($0, "^[[:space:]]*"f":[[:space:]]*")) {
        val = substr($0, RLENGTH+1)
        # Strip surrounding double-quotes if present
        if (val ~ /^".*"$/) {
          val = substr(val, 2, length(val) - 2)
          # Unescape \" -> " and \\ -> \ (so we count semantic chars)
          gsub(/\\"/, "\"", val)
          gsub(/\\\\/, "\\", val)
        }
        print val
        exit
      }
    }
  ' "$1"
}

for skill_dir in "$ROOT"/skills/*/; do
  name="$(basename "$skill_dir")"
  [ "$name" = "_template" ] && continue
  checked=$((checked + 1))

  skill_md="$skill_dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    fail "$name: missing SKILL.md"
    continue
  fi

  fm_name="$(read_fm_field "$skill_md" name)"
  fm_desc="$(read_fm_field "$skill_md" description)"

  if [ -z "$fm_name" ]; then
    fail "$name: frontmatter missing required field 'name'"
    continue
  fi
  if [ "$fm_name" != "$name" ]; then
    fail "$name: frontmatter name '$fm_name' does not match folder name '$name'"
    continue
  fi
  if ! [[ "$fm_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    fail "$name: 'name' must match /^[a-z0-9]+(-[a-z0-9]+)*\$/ (lowercase + hyphens, no leading/trailing/consecutive hyphens)"
    continue
  fi
  if [ "${#fm_name}" -gt 64 ]; then
    fail "$name: 'name' exceeds 64 chars"
    continue
  fi
  if [ -z "$fm_desc" ]; then
    fail "$name: frontmatter missing required field 'description'"
    continue
  fi
  if [ "${#fm_desc}" -gt 1024 ]; then
    fail "$name: 'description' exceeds 1024 chars (${#fm_desc})"
    continue
  fi

  pass "$name"
done

echo
echo "checked $checked skill(s); failed=$failed"
exit "$failed"
