#!/bin/sh
# Reads the real receipts in TestData/Real/ (not in git) with the rules and with
# Apple's model, and prints a field-by-field report (also in TestData/Real/report.md).
# Usage: Tools/receipts/read-real.sh [simulator id]   (default: first booted iPhone)
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SIM="${1:-$(xcrun simctl list devices booted | grep -m1 -oE '[0-9A-F-]{36}' || true)}"
[ -n "$SIM" ] || { echo "Boot an iPhone simulator first (or pass its id)." >&2; exit 1; }
ls "$ROOT/TestData/Real" | grep -qiE '\.(jpe?g|png|heic|pdf)$' || { echo "Put receipts (JPEG, PNG, HEIC or PDF) in TestData/Real/ first." >&2; exit 1; }
cd "$ROOT/BifazKit"
xcodebuild test -scheme BifazKit-Package -destination "platform=iOS Simulator,id=$SIM" \
  -only-testing:BifazReadingTests/RealReceiptsTests >/dev/null 2>&1 || true
cat "$ROOT/TestData/Real/report.md"
