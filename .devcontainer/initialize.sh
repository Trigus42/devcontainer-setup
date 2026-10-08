#!/usr/bin/env bash
set -euo pipefail

# Host-side devcontainer.json "initializeCommand": seeds the bind-mounted
# staging dirs with the host's opencode/omp/Claude Code config on first init, so
# container starts from the host model config but keeps its own container-local
# state (sessions, caches, dbs). API keys are never copied; they come from
# dev.env via --env-file.

data_root="${HOME}/.devcontainer-data/.config"

# ----------------------------------------------------------------------------
# What to seed  (edit here: one call per target)
#   seed_files SRC DST FILE...   named files, only if each is absent
# Afterwards every seeded config file is scanned once for loopback base URLs.
# ----------------------------------------------------------------------------
seed() {
  seed_files "${HOME}/.config/opencode" "${data_root}/opencode" opencode.json opencode.jsonc tui.jsonc
  seed_files "${HOME}/.omp/agent"       "${data_root}/omp"       config.yml models.yml
  seed_files "${HOME}/.claude"          "${data_root}/claude"    settings.json
}

# ----------------------------------------------------------------------------
# Machinery  (rarely edited)
# ----------------------------------------------------------------------------

# Container-visible host that forwards to the host machine's loopback.
readonly PROXY_HOST="host.docker.internal"

# Config files seeded this run; URL rewriting only touches these.
SEEDED_FILES=()

main() {
  mkdir -p "${HOME}/.config/git"
  seed
  local f
  for f in "${SEEDED_FILES[@]:-}"; do
    rewrite_base_url_host "$f"
  done
}


# Copy each named file into DST only when absent, so an existing file is never
# overwritten. Records copied files in SEEDED_FILES.
seed_files() {
  local src="$1" dst="$2"
  shift 2

  mkdir -p "$dst"
  if [ ! -d "$src" ]; then
    echo "init: no host config at ${src}; nothing to seed into ${dst}" >&2
    return 0
  fi

  local f
  for f in "$@"; do
    if [ -e "${dst}/${f}" ]; then
      echo "init: ${dst}/${f} already exists; leaving it untouched" >&2
    elif [ -f "${src}/${f}" ]; then
      cp "${src}/${f}" "${dst}/${f}"
      SEEDED_FILES+=("${dst}/${f}")
      echo "init: seeded ${dst}/${f} from ${src}/${f}" >&2
    else
      echo "init: ${src}/${f} not found on host; left ${dst}/${f} unseeded" >&2
    fi
  done
}

# Point the provider base URL at the host proxy: inside the container a loopback
# host is the container's own loopback, not the host's. Only the base-URL field
# is rewritten (other localhost URLs are left intact), via format-specific
# patterns for JSON ("baseURL": "...") and unquoted YAML (baseUrl: ...).
rewrite_base_url_host() {
  local file="$1" changed=0 loopback='(127\.0\.0\.1|localhost)'

  case "$file" in
    *.json | *.jsonc)
      # Both the opencode/omp "baseURL" field and Claude Code's env-block
      # ANTHROPIC_BASE_URL point a loopback provider at the host proxy.
      local json_key='("baseURL"|"ANTHROPIC_BASE_URL")'
      if grep -qE "${json_key}[[:space:]]*:[[:space:]]*\"https?://${loopback}" "$file"; then
        sed -i.bak -E "s#(${json_key}[[:space:]]*:[[:space:]]*\"https?://)${loopback}#\1${PROXY_HOST}#g" "$file"
        changed=1
      fi
      ;;
    *.yml | *.yaml)
      if grep -qE "baseUrl[[:space:]]*:[[:space:]]*https?://${loopback}" "$file"; then
        sed -i.bak -E "s#(baseUrl[[:space:]]*:[[:space:]]*https?://)${loopback}#\1${PROXY_HOST}#g" "$file"
        changed=1
      fi
      ;;
  esac

  if [ "$changed" -eq 1 ]; then
    rm -f "${file}.bak"
    echo "init: rewrote loopback base URL -> ${PROXY_HOST} in ${file}" >&2
  fi
}

main "$@"
