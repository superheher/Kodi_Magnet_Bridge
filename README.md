# Kodi Magnet Bridge (macOS)

Small macOS setup that handles `magnet:` links and forwards them to Kodi web endpoint:

- Endpoint: `http://127.0.0.1:65220/playuri`
- Request format: `multipart/form-data` with:
  - `uri=<magnet-link>`
  - `file=null`

On macOS, before sending request, helper checks whether `Kodi.app` is running.
If Kodi is not running, helper starts it and waits 15 seconds.
After a successful request, helper tries to bring `Kodi.app` to foreground (Darwin-only, best effort).

## Files

- `install_kodi_magnet_bridge.sh` - installs everything
- `uninstall_kodi_magnet_bridge.sh` - removes everything created by installer

## What installer creates

- Helper script: `~/.kodi-magnet-bridge/playuri-magnet.sh`
- App bundle: `~/Applications/Kodi Magnet Bridge.app`
- URL scheme registration in app `Info.plist` for `magnet:`
- LaunchServices registration for the app
- If `duti` is installed: sets default `magnet` handler automatically

## Requirements

- macOS
- `curl` (usually preinstalled)
- `osacompile` and `PlistBuddy` (system tools on macOS)
- [Elementum](https://elementumorg.github.io/) Kodi addon (installed and configured)
- Optional: `duti` for automatic default handler assignment
  - Without `duti`, set default handler manually (for example with SwiftDefaultApps)

## Install

From repository root:

```bash
chmod +x ./install_kodi_magnet_bridge.sh
./install_kodi_magnet_bridge.sh
```

## Test

```bash
open 'magnet:?xt=urn:btih:TEST'
```

## Uninstall

```bash
chmod +x ./uninstall_kodi_magnet_bridge.sh
./uninstall_kodi_magnet_bridge.sh
```

## Custom endpoint

Default endpoint is:

```text
http://127.0.0.1:65220/playuri
```

Override per call:

```bash
KODI_MAGNET_ENDPOINT='http://127.0.0.1:65220/playuri' ~/.kodi-magnet-bridge/playuri-magnet.sh 'magnet:?xt=urn:btih:TEST'
```

## Notes

- Browser-like headers (`Sec-Fetch-*`, fixed boundary, `Content-Length`) are not required.
- On macOS, helper may pause up to 15 seconds when it needs to cold-start Kodi.
- If Kodi focus switch fails, request is still considered successful.
