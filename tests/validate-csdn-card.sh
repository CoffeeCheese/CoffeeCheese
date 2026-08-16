#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-csdn-card.sh"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

headers="$temp_dir/headers"
printf 'HTTP/2 200\ncontent-type: image/svg+xml; charset=utf-8\n' > "$headers"

assert_rejected() {
  local candidate="$1"
  local reason="$2"

  if "$validator" "$candidate" "$headers"; then
    echo "Expected validator to reject $reason" >&2
    exit 1
  fi
}

"$validator" "$repo_root/assets/csdn-stats.svg" "$headers"

placeholder="$temp_dir/placeholder.svg"
sed "s/桌子椅子凳子。's CSDN Stats/username's CSDN Stats/" \
  "$repo_root/assets/csdn-stats.svg" > "$placeholder"
assert_rejected "$placeholder" "a placeholder username"

all_zero="$temp_dir/all-zero.svg"
awk '
  /<text id=.key_(7|8|9|10|11|12)./ {
    sub(/>[^<>]*<\/tspan>/, ">0</tspan>")
  }
  { print }
' "$repo_root/assets/csdn-stats.svg" > "$all_zero"
assert_rejected "$all_zero" "six zero metrics"

echo "CSDN card validation regression tests passed."

