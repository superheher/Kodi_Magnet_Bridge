#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/.kodi-magnet-bridge"
HELPER_SCRIPT="${BASE_DIR}/playuri-magnet.sh"
APP_NAME="Kodi Magnet Bridge.app"
APP_PATH="${HOME}/Applications/${APP_NAME}"
BUNDLE_ID="local.kodi.magnet.bridge"
ENDPOINT_DEFAULT="http://127.0.0.1:65220/playuri"

log() {
  printf '[install] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[install] missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

plist_set() {
  local plist="$1"
  local key="$2"
  local value="$3"
  local type="${4:-string}"

  if /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$plist" >/dev/null 2>&1; then
    return 0
  fi
  /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "$plist"
}

require_cmd osacompile
require_cmd /usr/libexec/PlistBuddy
require_cmd curl

mkdir -p "${BASE_DIR}"
mkdir -p "${HOME}/Applications"

log "writing helper script to ${HELPER_SCRIPT}"
cat > "${HELPER_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${1:-}"
endpoint="${KODI_MAGNET_ENDPOINT:-http://127.0.0.1:65220/playuri}"

if [[ -z "$url" ]]; then
  printf '[kodi-magnet] usage: %s <magnet-link>\n' "$0" >&2
  exit 64
fi

if [[ "$url" != magnet:\?* ]]; then
  printf '[kodi-magnet] expected magnet link, got: %s\n' "$url" >&2
  exit 65
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! pgrep -x "Kodi" >/dev/null 2>&1; then
    if ! open -a "Kodi" >/dev/null 2>&1; then
      printf '[kodi-magnet] warning: failed to launch Kodi.app\n' >&2
    fi
    sleep 8
  fi
fi

curl --fail-with-body --silent --show-error \
  "$endpoint" \
  --form-string "uri=$url" \
  --form-string "file=null"

if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
  if ! osascript -e 'tell application "Kodi" to activate' >/dev/null 2>&1; then
    printf '[kodi-magnet] warning: failed to activate Kodi.app\n' >&2
  fi
fi
EOF

chmod 755 "${HELPER_SCRIPT}"

SCRIPT_PATH_ESCAPED="${HELPER_SCRIPT//\\/\\\\}"
SCRIPT_PATH_ESCAPED="${SCRIPT_PATH_ESCAPED//\"/\\\"}"

tmp_applescript="$(mktemp /tmp/kodi-magnet-bridge.XXXXXX.applescript)"
cleanup() {
  rm -f "${tmp_applescript}"
}
trap cleanup EXIT

log "building app bundle at ${APP_PATH}"
rm -rf "${APP_PATH}"
cat > "${tmp_applescript}" <<EOF
on open location theURL
  my sendMagnet(theURL)
end open location

on run argv
  if (count of argv) > 0 then
    my sendMagnet(item 1 of argv)
  end if
end run

on sendMagnet(theURL)
  set helperScript to "${SCRIPT_PATH_ESCAPED}"
  do shell script quoted form of helperScript & space & quoted form of theURL
end sendMagnet
EOF

osacompile -o "${APP_PATH}" "${tmp_applescript}"

INFO_PLIST="${APP_PATH}/Contents/Info.plist"
plist_set "${INFO_PLIST}" "CFBundleIdentifier" "${BUNDLE_ID}"
plist_set "${INFO_PLIST}" "CFBundleName" "Kodi Magnet Bridge"
plist_set "${INFO_PLIST}" "CFBundleDisplayName" "Kodi Magnet Bridge"

if /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "${INFO_PLIST}" >/dev/null 2>&1; then
  :
fi
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string magnet-handler" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string magnet" "${INFO_PLIST}"

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "${lsregister}" ]]; then
  log "registering app in LaunchServices"
  "${lsregister}" -f "${APP_PATH}" >/dev/null 2>&1 || true
fi

if command -v duti >/dev/null 2>&1; then
  log "setting default magnet handler via duti"
  duti -s "${BUNDLE_ID}" magnet all
  log "default handler for magnet is set to ${APP_NAME}"
else
  log "duti is not installed; auto-assign skipped"
  log "set magnet handler manually (SwiftDefaultApps) to: ${APP_PATH}"
fi

log "installation complete"
log "test with: open 'magnet:?xt=urn:btih:TEST'"
log "endpoint is configurable via env KODI_MAGNET_ENDPOINT (default: ${ENDPOINT_DEFAULT})"
