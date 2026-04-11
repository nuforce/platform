#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./scripts/nuforce-rebase.sh [--dry-run]

Rebase the platform repository and all configured submodules onto their latest
tracked upstream branches.

Behavior:
- Requires a clean working tree in the platform repo and every submodule
- Pulls the current platform branch with rebase
- Reads each submodule's tracked branch from .gitmodules
- Checks out the tracked branch if the submodule is in detached HEAD
- Pulls the tracked branch if already on it
- Rebases the current feature branch onto the tracked upstream branch otherwise

Options:
  --dry-run   Print the commands that would run without modifying git state
  -h, --help  Show this help text
EOF
}

info() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi

  "$@"
}

ensure_clean_tree() {
  local repo_path="$1"
  local repo_label="$2"
  local status

  status="$(git -C "$repo_path" status --porcelain)"
  if [[ -n "$status" ]]; then
    printf '%s\n' "$status" >&2
    die "$repo_label has uncommitted changes. Commit or stash them before running /nuforce-rebase."
  fi
}

ensure_local_branch() {
  local repo_path="$1"
  local branch_name="$2"

  if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch_name"; then
    run git -C "$repo_path" checkout "$branch_name"
  else
    run git -C "$repo_path" checkout -b "$branch_name" --track "origin/$branch_name"
  fi
}

rebase_platform_repo() {
  local current_branch upstream_branch

  current_branch="$(git -C "$ROOT_DIR" branch --show-current)"
  [[ -n "$current_branch" ]] || die "Platform repository is in detached HEAD state."

  info "Fetching platform branch $current_branch"
  run git -C "$ROOT_DIR" fetch origin "$current_branch"

  upstream_branch="origin/$current_branch"
  info "Rebasing platform branch $current_branch onto $upstream_branch"
  run git -C "$ROOT_DIR" rebase "$upstream_branch"
}

rebase_submodule() {
  local submodule_name="$1"
  local submodule_path="$2"
  local target_branch="$3"
  local current_branch

  [[ -d "$ROOT_DIR/$submodule_path" ]] || die "Submodule path '$submodule_path' does not exist. Run git submodule update --init --recursive first."
  git -C "$ROOT_DIR/$submodule_path" rev-parse --git-dir >/dev/null 2>&1 || die "Submodule '$submodule_path' is not initialized correctly."

  ensure_clean_tree "$ROOT_DIR/$submodule_path" "Submodule '$submodule_path'"

  current_branch="$(git -C "$ROOT_DIR/$submodule_path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

  info "Fetching $submodule_name from origin/$target_branch"
  run git -C "$ROOT_DIR/$submodule_path" fetch origin "$target_branch"

  if [[ -z "$current_branch" ]]; then
    info "$submodule_path is in detached HEAD; checking out $target_branch"
    ensure_local_branch "$ROOT_DIR/$submodule_path" "$target_branch"
    current_branch="$target_branch"
  fi

  if [[ "$current_branch" == "$target_branch" ]]; then
    info "Pulling latest $target_branch in $submodule_path"
    run git -C "$ROOT_DIR/$submodule_path" pull --rebase origin "$target_branch"
  else
    info "Rebasing $submodule_path:$current_branch onto origin/$target_branch"
    run git -C "$ROOT_DIR/$submodule_path" rebase "origin/$target_branch"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

cd "$ROOT_DIR"

[[ -f "$ROOT_DIR/.gitmodules" ]] || die "Run this script from the platform repository root."
git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "Current directory is not a git repository."

ensure_clean_tree "$ROOT_DIR" "Platform repository"

info "Synchronizing submodule metadata"
run git -C "$ROOT_DIR" submodule sync --recursive
run git -C "$ROOT_DIR" submodule update --init --recursive

rebase_platform_repo

while IFS=' ' read -r config_key submodule_path; do
  submodule_name="${config_key#submodule.}"
  submodule_name="${submodule_name%.path}"
  target_branch="$(git -C "$ROOT_DIR" config -f .gitmodules --get "submodule.$submodule_name.branch" || true)"

  [[ -n "$target_branch" ]] || target_branch="main"

  rebase_submodule "$submodule_name" "$submodule_path" "$target_branch"
done < <(git -C "$ROOT_DIR" config -f .gitmodules --get-regexp '^submodule\..*\.path$')

info "Rebase run complete"
info "Platform status:"
run git -C "$ROOT_DIR" status --short
info "Submodule status:"
run git -C "$ROOT_DIR" submodule status
