#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: xcodebuild is unavailable. Run this on macOS with Xcode 27.3 beta selected.' >&2
  exit 2
fi
printf '%s\n' 'Active Xcode:'
xcodebuild -version
printf '%s\n' 'Build scheme:'
xcodebuild -list -project "$ROOT/PromptStudio.xcodeproj"
printf '%s\n' 'Compiling app (unsigned, for diagnostics only):'
xcodebuild \
  -project "$ROOT/PromptStudio.xcodeproj" \
  -scheme PromptStudio \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/.DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build
