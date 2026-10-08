#!/usr/bin/env bash
set -euo pipefail

# postStartCommand: runs on every container start as the non-root "vscode" user,
# with the workspace folder as CWD.

# ----------------------------------------------------------------------------
# What to do on start  (edit here)
#   claim_ownership recursive|non-recursive PATH   reown a root-created mount
# ----------------------------------------------------------------------------
start() {
  git config --global --add safe.directory "$PWD"

  # Docker creates these as root, but we run as vscode. mise/zsh need to write
  # into the volumes; ~/.omp must stay vscode-owned (non-recursively, leaving
  # the mounted ~/.omp/agent untouched) so omp can extract its native addon.
  claim_ownership recursive     /mnt/mise-data
  claim_ownership recursive     /mnt/zsh-history
  claim_ownership non-recursive "$HOME/.omp"

  if [ -f mise.toml ]; then
    mise trust mise.toml
    mise install
  fi
}

# ----------------------------------------------------------------------------
# Machinery  (rarely edited)
# ----------------------------------------------------------------------------

# Take ownership of PATH when it is not already ours, so re-runs are no-ops.
claim_ownership() {
  local recurse="$1" path="$2"
  [ -e "$path" ] && [ ! -O "$path" ] || return 0
  if [ "$recurse" = recursive ]; then
    sudo chown -R "$(id -u):$(id -g)" "$path"
  else
    sudo chown "$(id -u):$(id -g)" "$path"
  fi
}

start "$@"
