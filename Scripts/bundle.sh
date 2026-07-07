#!/usr/bin/env bash
#
# Assemble a runnable Swiftty.app from a SwiftPM build.
#
# Usage:
#   Scripts/bundle.sh [options]
#     --sign <identity>   codesign identity. Default "-" (ad-hoc).
#                         Pass a "Developer ID Application: ..." name for release.
#     --config <cfg>      release (default) or debug.
#     --version <v>       Marketing version stamped into Info.plist (e.g. 1.2.0).
#                         Defaults to $SWIFTTY_VERSION, else "0.0.0".
#     --build <n>         CFBundleVersion (build number). Defaults to 0.
#     --zip               Also produce dist/Swiftty.zip (ditto, signature-safe).
#
# With no --sign the app is ad-hoc signed: enough to run and be granted
# Accessibility / Notification permissions on this machine. For a distributable
# build, pass a Developer ID identity (the workflow does) and notarize after.
#
set -euo pipefail

# ---- Configuration -----------------------------------------------------------

APP_NAME="Swiftty"
CONFIG="release"
SIGN_IDENTITY="-"                                 # "-" == ad-hoc
VERSION="${SWIFTTY_VERSION:-0.0.0}"
BUILD_NUMBER="0"
MAKE_ZIP="false"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST_SRC="${REPO_ROOT}/Sources/${APP_NAME}/Info.plist"
DIST_DIR="${REPO_ROOT}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"

# ---- Argument parsing --------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign)    SIGN_IDENTITY="$2"; shift 2 ;;
        --config)  CONFIG="$2";        shift 2 ;;
        --version) VERSION="$2";       shift 2 ;;
        --build)   BUILD_NUMBER="$2";  shift 2 ;;
        --zip)     MAKE_ZIP="true";    shift ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# Strip a leading "v" so a "v1.2.0" tag yields a valid CFBundleShortVersionString.
VERSION="${VERSION#v}"

# ---- Build -------------------------------------------------------------------

echo "> Building ${APP_NAME} ${VERSION} (${CONFIG})..."
swift build --configuration "${CONFIG}" --package-path "${REPO_ROOT}"

BIN_DIR="$(swift build --configuration "${CONFIG}" --package-path "${REPO_ROOT}" --show-bin-path)"
EXECUTABLE="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "${EXECUTABLE}" ]]; then
    echo "ERROR Executable not found at ${EXECUTABLE}" >&2
    exit 1
fi

# ---- Assemble the .app -------------------------------------------------------

echo "> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${INFO_PLIST_SRC}" "${APP_DIR}/Contents/Info.plist"
printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

# Stamp the version into the bundled Info.plist.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" \
    "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" \
    "${APP_DIR}/Contents/Info.plist"

# Bundle an app icon if one has been generated (see Scripts/make-icon.sh).
if [[ -f "${REPO_ROOT}/Resources/AppIcon.icns" ]]; then
    cp "${REPO_ROOT}/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" \
        "${APP_DIR}/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "${APP_DIR}/Contents/Info.plist"
fi

# SwiftTerm also stages a resource bundle for its Metal renderer. Swiftty uses
# the CoreGraphics renderer, so the bundle is not needed in the app package.

# ---- Embed Sparkle.framework (autoupdater) -----------------------------------
# SwiftPM stages Sparkle.framework next to the executable; the app finds it via
# the @executable_path/../Frameworks rpath set in Package.swift.
FRAMEWORK_SRC="${BIN_DIR}/Sparkle.framework"
if [[ -d "${FRAMEWORK_SRC}" ]]; then
    echo "> Embedding Sparkle.framework..."
    mkdir -p "${APP_DIR}/Contents/Frameworks"
    cp -R "${FRAMEWORK_SRC}" "${APP_DIR}/Contents/Frameworks/"
fi

# ---- Code signing ------------------------------------------------------------

echo "> Signing with identity: ${SIGN_IDENTITY}"
SIGN_ARGS=(--force --sign "${SIGN_IDENTITY}")

if [[ "${SIGN_IDENTITY}" == "-" ]]; then
    # Ad-hoc: no secure timestamp, no hardened runtime, so the local shell runs.
    SIGN_ARGS+=(--timestamp=none)
else
    # Developer ID: hardened runtime + secure timestamp are REQUIRED to notarize.
    SIGN_ARGS+=(--options runtime --timestamp)
fi

# Sparkle bundles nested helpers (an updater app, a self-update tool, and XPC
# services) that must be signed inside-out - deepest first, then the framework
# that wraps them - or the outer signature is rejected as invalid.
FRAMEWORK="${APP_DIR}/Contents/Frameworks/Sparkle.framework"
if [[ -d "${FRAMEWORK}" ]]; then
    echo "> Signing Sparkle's nested helpers..."
    VERSIONED="${FRAMEWORK}/Versions/Current"
    for nested in \
        "${VERSIONED}/XPCServices/Downloader.xpc" \
        "${VERSIONED}/XPCServices/Installer.xpc" \
        "${VERSIONED}/Autoupdate" \
        "${VERSIONED}/Updater.app"; do
        codesign "${SIGN_ARGS[@]}" "${nested}"
    done
    codesign "${SIGN_ARGS[@]}" "${FRAMEWORK}"
fi

# The app last.
codesign "${SIGN_ARGS[@]}" "${APP_DIR}"

echo "> Verifying signature..."
codesign --verify --strict --verbose=2 "${APP_DIR}"

# ---- Optional zip (signature-preserving) -------------------------------------

if [[ "${MAKE_ZIP}" == "true" ]]; then
    echo "> Creating ${ZIP_PATH}..."
    rm -f "${ZIP_PATH}"
    # ditto is the only archiver Apple guarantees preserves bundle signatures.
    /usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"
fi

echo ""
echo "OK Built ${APP_DIR} (v${VERSION}, build ${BUILD_NUMBER})"
[[ "${MAKE_ZIP}" == "true" ]] && echo "OK Zipped ${ZIP_PATH}"
echo "  Run it with:  open \"${APP_DIR}\""
echo "  Look for the terminal icon in your menu bar (no Dock tile - it's an agent)."
