#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

test_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
project_dir=$(CDPATH= cd -- "$test_dir/.." && pwd -P)
installer="$project_dir/scripts/install.sh"
fixture_parent=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
fixture_dir=$(mktemp -d "$fixture_parent/roxy-install-test.XXXXXX")
cleanup() {
  case "$fixture_dir" in
    "$fixture_parent"/roxy-install-test.*) rm -rf -- "$fixture_dir" ;;
  esac
}
trap cleanup EXIT

assert_fails() {
  if bash "$installer" "$@" >"$fixture_dir/rejected.log" 2>&1; then
    printf 'Expected installation to fail: %s\n' "$*" >&2
    exit 1
  fi
}

bash "$installer" --help >/dev/null
pets_dir="$fixture_dir/pet collection with spaces"
bash "$installer" --pets-dir "$pets_dir" --dry-run >/dev/null
[ ! -e "$pets_dir" ]

bash "$installer" --pets-dir "$pets_dir" >/dev/null
destination="$pets_dir/roxy-desktop-pet"
cmp "$project_dir/pet.json" "$destination/pet.json"
cmp "$project_dir/assets/spritesheet.webp" "$destination/assets/spritesheet.webp"
mkdir "$pets_dir/unrelated-pet"
printf 'Keep this pet.\n' >"$pets_dir/unrelated-pet/keep.txt"

printf 'Previous local installation marker.\n' >"$destination/keep-local.txt"
bash "$installer" --pets-dir "$pets_dir" >/dev/null
cmp "$project_dir/pet.json" "$destination/pet.json"
cmp "$project_dir/assets/spritesheet.webp" "$destination/assets/spritesheet.webp"
[ ! -e "$destination/keep-local.txt" ]
backup_count=0
for backup in "$pets_dir"/roxy-desktop-pet.backup.*; do
  [ -d "$backup" ] || continue
  backup_count=$((backup_count + 1))
  [ -f "$backup/keep-local.txt" ]
  cmp "$project_dir/assets/spritesheet.webp" "$backup/assets/spritesheet.webp"
done
[ "$backup_count" -eq 1 ]
[ "$(cat "$pets_dir/unrelated-pet/keep.txt")" = 'Keep this pet.' ]

bash "$installer" --pets-dir "$pets_dir" --dry-run >/dev/null
backup_count_after=0
for backup in "$pets_dir"/roxy-desktop-pet.backup.*; do
  [ -d "$backup" ] || continue
  backup_count_after=$((backup_count_after + 1))
done
[ "$backup_count_after" -eq 1 ]

assert_fails --pets-dir / --dry-run
assert_fails --pets-dir "$HOME" --dry-run
assert_fails --pets-dir relative/path --dry-run
assert_fails --pets-dir "$fixture_dir/a/../pets" --dry-run
assert_fails --pets-dir
assert_fails --unknown

mkdir "$fixture_dir/real-parent"
ln -s "$fixture_dir/real-parent" "$fixture_dir/linked-parent"
assert_fails --pets-dir "$fixture_dir/linked-parent/pets" --dry-run
[ ! -e "$fixture_dir/real-parent/pets" ]

mkdir "$fixture_dir/linked-pet-collection" "$fixture_dir/victim"
printf 'Do not touch.\n' >"$fixture_dir/victim/keep.txt"
ln -s "$fixture_dir/victim" "$fixture_dir/linked-pet-collection/roxy-desktop-pet"
assert_fails --pets-dir "$fixture_dir/linked-pet-collection"
[ "$(cat "$fixture_dir/victim/keep.txt")" = 'Do not touch.' ]

mkdir "$fixture_dir/file-collection"
printf 'Do not replace.\n' >"$fixture_dir/file-collection/roxy-desktop-pet"
assert_fails --pets-dir "$fixture_dir/file-collection"
[ "$(cat "$fixture_dir/file-collection/roxy-desktop-pet")" = 'Do not replace.' ]

printf 'Installer tests passed.\n'
