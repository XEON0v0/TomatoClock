#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TomatoClock"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
MODE="${1:-run}"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--build-only|--clean]" >&2
}

build_app() {
  "$ROOT_DIR/script/build_app.sh"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_app
    open_app
    ;;
  --build-only|build)
    build_app
    ;;
  --clean|clean)
    "$ROOT_DIR/script/build_app.sh" --clean
    ;;
  --debug|debug)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_app
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"com.ray.tomatoclock\""
    ;;
  --verify|verify)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_app
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running"
    ;;
  *)
    usage
    exit 2
    ;;
esac
