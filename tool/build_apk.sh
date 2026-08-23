#!/usr/bin/env bash
# Release APK build wrapper that stamps the binary with git provenance
# (shown in the About screen's Build details block). Extra arguments are
# passed straight to `flutter build apk`.
set -euo pipefail
cd "$(dirname "$0")/.."

GIT_SHA=$(git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
GIT_DIRTY=false
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  GIT_DIRTY=true
fi
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%MZ)

FLUTTER=${FLUTTER:-fvm flutter}
exec $FLUTTER build apk --release \
  --dart-define=GIT_SHA="$GIT_SHA" \
  --dart-define=GIT_BRANCH="$GIT_BRANCH" \
  --dart-define=GIT_DIRTY="$GIT_DIRTY" \
  --dart-define=BUILD_TIME="$BUILD_TIME" \
  --dart-define=BUILD_SOURCE=local \
  "$@"
