#!/bin/bash
# Runs the YTMusicApp test suite and writes a persisted summary report to
# test-results/latest.md (pass/fail counts, timestamp, failures listed).
#
# Usage: scripts/run_tests.sh
#
# Requires xcodegen and Xcode/xcodebuild to be installed, and
# Config/Secrets.xcconfig to exist (copy from Config/Secrets.example.xcconfig).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RESULTS_DIR="test-results"
RAW_LOG="$RESULTS_DIR/raw.log"
SUMMARY_MD="$RESULTS_DIR/latest.md"

mkdir -p "$RESULTS_DIR"

echo "==> xcodegen generate"
xcodegen generate

# Pick whatever iPhone simulator the machine actually has installed, rather
# than hardcoding a device name that may not exist on every Xcode version.
SIM_NAME=$(xcrun simctl list devices available | grep -m1 -E "iPhone (1[4-9]|[2-9][0-9])" | sed -E 's/^[[:space:]]*([^(]+) \(.*/\1/' | sed -E 's/[[:space:]]+$//')
if [ -z "$SIM_NAME" ]; then
  SIM_NAME="iPhone 16"
fi
echo "==> Using simulator: $SIM_NAME"

echo "==> xcodebuild test"
START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

xcodebuild \
  -scheme YTMusicApp \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  test 2>&1 | tee "$RAW_LOG"

BUILD_EXIT_CODE=${PIPESTATUS[0]}
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# xcodebuild prints one line per test result, e.g.:
#   Test Case '-[YTMusicAppTests.EqualizerEngineTests testFoo]' passed (0.001 seconds).
#   Test Case '-[YTMusicAppTests.EqualizerEngineTests testBar]' failed (0.002 seconds).
PASS_COUNT=$(grep -cE "^Test Case '.*' passed " "$RAW_LOG" || true)
FAIL_COUNT=$(grep -cE "^Test Case '.*' failed " "$RAW_LOG" || true)
TOTAL_COUNT=$((PASS_COUNT + FAIL_COUNT))

FAILURE_LINES=$(grep -E "^Test Case '.*' failed " "$RAW_LOG" | sed -E "s/^Test Case '(-\[[^]]*\])' failed.*/\1/" || true)

if [ "$FAIL_COUNT" -eq 0 ] && [ "$BUILD_EXIT_CODE" -eq 0 ]; then
  STATUS_LINE="PASSED"
elif [ "$BUILD_EXIT_CODE" -ne 0 ] && [ "$TOTAL_COUNT" -eq 0 ]; then
  STATUS_LINE="BUILD FAILED (no tests ran)"
else
  STATUS_LINE="FAILED"
fi

{
  echo "# Test Results"
  echo ""
  echo "- **Status**: $STATUS_LINE"
  echo "- **Run started**: $START_TIME"
  echo "- **Run finished**: $END_TIME"
  echo "- **Simulator**: $SIM_NAME"
  echo "- **Passed**: $PASS_COUNT"
  echo "- **Failed**: $FAIL_COUNT"
  echo "- **Total**: $TOTAL_COUNT"
  echo "- **xcodebuild exit code**: $BUILD_EXIT_CODE"
  echo ""
  if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "## Failures"
    echo ""
    while IFS= read -r line; do
      [ -n "$line" ] && echo "- $line"
    done <<< "$FAILURE_LINES"
    echo ""
  fi
  if [ "$BUILD_EXIT_CODE" -ne 0 ] && [ "$TOTAL_COUNT" -eq 0 ]; then
    echo "## Build/Test Errors"
    echo ""
    echo '```'
    grep -E "error:" "$RAW_LOG" | head -50
    echo '```'
    echo ""
  fi
  echo "Full raw xcodebuild log: \`$RESULTS_DIR/raw.log\`"
} > "$SUMMARY_MD"

echo "==> Wrote summary to $SUMMARY_MD"
cat "$SUMMARY_MD"

exit "$BUILD_EXIT_CODE"
