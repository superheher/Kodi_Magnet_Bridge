#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/.kodi-magnet-bridge"
APP_NAME="Kodi Magnet Bridge.app"
APP_PATH="${HOME}/Applications/${APP_NAME}"
BUNDLE_ID="local.kodi.magnet.bridge"

log() {
  printf '[uninstall] %s\n' "$*"
}

if [[ -d "${APP_PATH}" ]]; then
  log "removing app: ${APP_PATH}"
  rm -rf "${APP_PATH}"
else
  log "app not found: ${APP_PATH}"
fi

if [[ -d "${BASE_DIR}" ]]; then
  log "removing helper directory: ${BASE_DIR}"
  rm -rf "${BASE_DIR}"
else
  log "helper directory not found: ${BASE_DIR}"
fi

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "${lsregister}" ]]; then
  log "refreshing LaunchServices cache"
  "${lsregister}" -kill -r -domain local -domain system -domain user >/dev/null 2>&1 || true
fi

if command -v duti >/dev/null 2>&1; then
  current_handler="$(duti -x magnet 2>/dev/null | sed -n '1p' || true)"
  if [[ "${current_handler}" == *"${BUNDLE_ID}"* ]]; then
    log "magnet may still point to removed bundle id (${BUNDLE_ID})"
  fi
fi

log "uninstall complete"
log "if magnet links still open incorrectly, set a new handler in SwiftDefaultApps."
