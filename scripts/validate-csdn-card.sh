#!/usr/bin/env bash

set -euo pipefail

candidate="${1:?usage: validate-csdn-card.sh SVG HEADERS}"
headers="${2:?usage: validate-csdn-card.sh SVG HEADERS}"

reject() {
  echo "Rejected CSDN card: $*" >&2
  exit 1
}

[[ -f "$candidate" ]] || reject "SVG file is missing"
[[ -f "$headers" ]] || reject "HTTP headers are missing"

size="$(wc -c < "$candidate")"
(( size >= 500 && size <= 100000 )) || reject "unexpected SVG size: $size bytes"

grep -qi '^content-type: image/svg+xml' "$headers" \
  || reject "response is not image/svg+xml"
grep -q '<svg' "$candidate" && grep -q '</svg>' "$candidate" \
  || reject "response is not a complete SVG"
! grep -Eqi 'GATEWAY_TIMEOUT|FUNCTION_INVOCATION_TIMEOUT|Error Fetching Resource' "$candidate" \
  || reject "upstream returned an error card"

grep -Fq "桌子椅子凳子。's CSDN Stats" "$candidate" \
  || reject "expected CSDN profile was not resolved"

metric_count="$(grep -Ec "<text id=['\"]key_(7|8|9|10|11|12)['\"]" "$candidate" || true)"
zero_metric_count="$(
  grep -E "<text id=['\"]key_(7|8|9|10|11|12)['\"]" "$candidate" \
    | grep -Ec '<tspan[^>]*>0</tspan>' \
    || true
)"

(( metric_count == 6 )) || reject "expected six CSDN metrics, found $metric_count"
(( zero_metric_count < 6 )) || reject "all six CSDN metrics are zero"
