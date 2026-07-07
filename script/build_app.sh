#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TomatoClock.xcodeproj"
SCHEME="TomatoClock"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/TomatoClock.app"

ACTION="build"
if [[ "${1:-}" == "--clean" || "${1:-}" == "clean" ]]; then
  ACTION="clean build"
fi

echo "Building $SCHEME ($CONFIGURATION) into $BUILD_DIR"

xcodebuild $ACTION \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Expected app bundle was not created: $APP_BUNDLE" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
