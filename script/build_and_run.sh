#!/usr/bin/env bash
#
# Build a debug Swiftty.app and start it, for use while developing.
#
# Usage:
#   script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify]
#     run          Start the app. This is the default.
#     --debug      Start the binary under lldb instead.
#     --logs       Start the app and follow everything it logs.
#     --telemetry  Start the app and follow only Swiftty's own log subsystem.
#     --verify     Start the app and check that it stays alive.
#
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Swiftty"
BUNDLE_ID="com.parmscript.swiftty"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${REPO_ROOT}/dist/${APP_NAME}.app"
APP_BINARY="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# An older copy would keep the menu bar item and the global shortcut.
pkill -x "${APP_NAME}" >/dev/null 2>&1 || true
"${REPO_ROOT}/script/make-icon.sh"
"${REPO_ROOT}/script/bundle.sh" --config debug

open_app() {
    # -n forces a new instance, even if macOS thinks one is already open.
    /usr/bin/open -n "${APP_BUNDLE}"
}

case "${MODE}" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "${APP_BINARY}"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == '${APP_NAME}'"
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == '${BUNDLE_ID}'"
        ;;
    --verify|verify)
        open_app
        for _ in {1..20}; do
            pgrep -x "${APP_NAME}" >/dev/null && exit 0
            sleep 0.25
        done
        echo "ERROR ${APP_NAME} did not launch" >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
