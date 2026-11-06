#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Install only this pet. No downloads, application changes, or background jobs.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/install.sh [--pets-dir ABSOLUTE_PATH] [--dry-run]

Install Roxy into the local Codex pet collection.
The default collection is $CODEX_HOME/pets, or ~/.codex/pets.
An existing roxy-desktop-pet installation is kept in a timestamped backup.

  --pets-dir PATH  Use a different pet collection directory.
  --dry-run        Show the destination without creating or changing files.
  -h, --help       Show this help.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

pets_dir="${CODEX_HOME:-${HOME:?HOME must be set}/.codex}/pets"
dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --pets-dir)
      [ "$#" -ge 2 ] || fail '--pets-dir requires an absolute path.'
      [ -n "$2" ] || fail '--pets-dir cannot be empty.'
      pets_dir=$2
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

while [ "$pets_dir" != / ] && [ "${pets_dir%/}" != "$pets_dir" ]; do
  pets_dir=${pets_dir%/}
done

assert_safe_directory() {
  local candidate=$1 component prefix
  local -a path_parts
  case "$candidate" in /*) ;; *) fail 'The pet collection path must be absolute.' ;; esac
  [ "$candidate" != / ] || fail 'The filesystem root is not a pet collection.'
  [ "$candidate" != "${HOME%/}" ] || fail 'Your home directory is not a pet collection.'
  IFS=/ read -r -a path_parts <<< "$candidate"
  prefix=
  for component in "${path_parts[@]}"; do
    [ -n "$component" ] || continue
    case "$component" in .|..) fail 'Dot and parent-directory path components are not allowed.' ;; esac
    prefix="$prefix/$component"
    [ ! -L "$prefix" ] || fail "Refusing a symbolic-link directory: $prefix"
    if [ -e "$prefix" ] && [ ! -d "$prefix" ]; then
      fail "A path component is not a directory: $prefix"
    fi
  done
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
for source_file in "$project_dir/pet.json" "$project_dir/assets/spritesheet.webp"; do
  [ -f "$source_file" ] && [ ! -L "$source_file" ] || fail "Missing or linked source file: $source_file"
done

assert_safe_directory "$pets_dir"
destination="$pets_dir/roxy-desktop-pet"
[ ! -L "$destination" ] || fail "Refusing a symbolic-link installation: $destination"
if [ -e "$destination" ] && [ ! -d "$destination" ]; then
  fail "The installation destination is not a directory: $destination"
fi

printf 'Pet destination: %s\n' "$destination"
if $dry_run; then
  printf 'Dry run: no files were created or changed.\n'
  exit 0
fi

mkdir -p -- "$pets_dir"
assert_safe_directory "$pets_dir"
stage_dir=$(mktemp -d "$pets_dir/.roxy-desktop-pet.install.XXXXXX")
backup_dir=
cleanup() {
  local status=$?
  trap - EXIT
  if [ -n "$stage_dir" ] && [ -d "$stage_dir" ] && [ ! -L "$stage_dir" ]; then
    # Remove only the fixed files created by this installer, never an arbitrary tree.
    rm -f -- "$stage_dir/pet.json" "$stage_dir/assets/spritesheet.webp"
    rmdir -- "$stage_dir/assets" 2>/dev/null || true
    rmdir -- "$stage_dir" 2>/dev/null || true
  fi
  if [ "$status" -ne 0 ] && [ -n "$backup_dir" ] && [ -d "$backup_dir" ] && [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
    mv -- "$backup_dir" "$destination" || true
  fi
  exit "$status"
}
trap cleanup EXIT

mkdir -- "$stage_dir/assets"
cp -- "$project_dir/pet.json" "$stage_dir/pet.json"
cp -- "$project_dir/assets/spritesheet.webp" "$stage_dir/assets/spritesheet.webp"
if [ -d "$destination" ]; then
  backup_dir="$destination.backup.$(date -u +%Y%m%dT%H%M%SZ).$$"
  [ ! -e "$backup_dir" ] && [ ! -L "$backup_dir" ] || fail "Backup already exists: $backup_dir"
  mv -- "$destination" "$backup_dir"
fi
mv -- "$stage_dir" "$destination"
stage_dir=

printf 'Installed Roxy.\n'
if [ -n "$backup_dir" ]; then
  printf 'Previous installation kept at: %s\n' "$backup_dir"
fi
printf 'Refresh the pet list or reopen the app, then choose Roxy / 洛琪希老师.\n'
