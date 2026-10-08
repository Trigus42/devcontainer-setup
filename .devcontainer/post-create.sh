#!/usr/bin/env bash
set -euo pipefail

# postCreateCommand: one-time container setup. Configures git and, from
# GIT_CREDENTIALS (see dev.env.example), a per-entry HTTPS credential helper
# that reads its token env var at git-invocation time, so no token is ever
# written to git config.

# ----------------------------------------------------------------------------
# What to set up  (edit here)
# ----------------------------------------------------------------------------
setup() {
  touch ~/.gitconfig
  git config --global worktree.useRelativePaths true

  configure_git_credentials "${GIT_CREDENTIALS:-}"
}

# ----------------------------------------------------------------------------
# Machinery  (rarely edited)
# ----------------------------------------------------------------------------

# Parse GIT_CREDENTIALS (space-separated URL_PREFIX=TOKEN_ENV_VAR entries) and
# configure one helper per entry.
configure_git_credentials() {
  local credentials="$1" entry url_prefix token_var

  # Docker's --env-file is not a shell: it keeps surrounding quotes literally.
  # Strip one leading/trailing quote pair so GIT_CREDENTIALS="a=b c=d" parses.
  credentials="${credentials#[\"\']}"
  credentials="${credentials%[\"\']}"

  for entry in $credentials; do
    url_prefix="${entry%%=*}"
    token_var="${entry#*=}"
    if [ -n "$url_prefix" ] && [ -n "$token_var" ] && [ "$url_prefix" != "$entry" ]; then
      configure_git_credential "$url_prefix" "$token_var"
    else
      echo "git: ignoring malformed GIT_CREDENTIALS entry: '${entry}'" >&2
    fi
  done
}

configure_git_credential() {
  local url_prefix="$1" token_var="$2"

  # Both values are embedded into a git config key and a credential-helper shell
  # snippet below, so reject anything that could inject shell or extra config:
  # token_var must be a shell variable name; url_prefix a plain HTTPS
  # host[:port][/path] with no whitespace, quotes, metacharacters, or ?/#/@.
  if ! printf '%s' "$token_var" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
    echo "git: refusing credential entry with invalid token var name: '${token_var}'" >&2
    return 0
  fi
  if ! printf '%s' "$url_prefix" | grep -qE '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]+)?(/[A-Za-z0-9._~-]+)*$'; then
    echo "git: refusing credential entry with invalid URL prefix: '${url_prefix}'" >&2
    return 0
  fi

  # An empty/unset token var is a harmless no-op, not a broken helper.
  if [ -z "$(printenv "$token_var" 2>/dev/null || true)" ]; then
    echo "git: skipping ${url_prefix} (\$${token_var} is empty/unset)" >&2
    return 0
  fi

  local url="https://${url_prefix}"
  # useHttpPath maps path prefixes on the same host to different tokens
  # (most-specific wins); the helper expands the token only at invocation time.
  git config --global credential."${url}".useHttpPath true
  git config --global credential."${url}".helper \
    "!f() { echo username=x-access-token; echo \"password=\${${token_var}}\"; }; f"
  echo "git: configured HTTPS credential helper for ${url} (via \$${token_var})"
}

setup "$@"
