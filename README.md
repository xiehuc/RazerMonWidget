# RazerMonWidget

English | [简体中文](README.zh-CN.md)

Display Razer mouse and keyboard battery levels in the built-in macOS Batteries widget, without a menu bar app.

**The core logic of this project comes from [ab4317/RazerMon](https://github.com/ab4317/RazerMon).** HID device discovery, the HyperSpeed battery protocol, serial-number identification, battery conversion, and the device catalog are migrated from RazerMon. Thank you to the original project's authors and contributors.

RazerMonWidget builds on that work with IOKit battery publishing adapted from atkctl and a per-user background service managed by launchctl.

## Requirements

- macOS 13 or later; Apple Silicon or Intel.
- No Swift, Xcode, repository checkout, or compilation required for release installation.
- Hardware compatibility follows RazerMon. The catalog contains 42 entries; inclusion does not mean every model has been tested on physical hardware.

## Install

Download a precompiled binary from GitHub Releases and install the service:

```sh
curl -fsSL https://raw.githubusercontent.com/xiehuc/RazerMonWidget/master/install.sh | bash

# Install a specific release
curl -fsSL https://raw.githubusercontent.com/xiehuc/RazerMonWidget/master/install.sh | bash -s -- --version v1.0.0
```

The default repository is `xiehuc/RazerMonWidget`. For a fork, pass `--repo OWNER/REPO` or set `RAZERMONWIDGET_REPO`. Ensure the repository address matches your published project. The installer verifies the SHA-256 checksum and executable signature before installing the service.

Installation runs as the logged-in user. **Do not use sudo.** The LaunchAgent starts immediately, runs at login, and is kept running by launchctl.

| Item | Location |
| --- | --- |
| Executable | `~/.local/bin/RazerMonWidget` |
| LaunchAgent | `~/Library/LaunchAgents/local.razermonwidget.battery.plist` |
| Log | `~/Library/Logs/RazerMonWidget-battery.log` |

### Input Monitoring and the widget

Add the **installed executable** to **System Settings → Privacy & Security → Input Monitoring**, enable it, then restart the service:

```sh
launchctl kickstart -k gui/$(id -u)/local.razermonwidget.battery
```

Receivers expose keyboard-class HID interfaces, which may require Input Monitoring permission. The service reads vendor reports for device information and battery levels; it does not monitor keystrokes. If permission stops working after an ad-hoc-signed update, remove the old entry and add the installed executable again.

Add the built-in **Batteries** widget to your desktop or Notification Center. Wake the device and check the log for a battery percentage. A successful launchctl start alone does not confirm HID access or battery publication.

## Local development

With a Swift 6 toolchain installed, build the executable and install it using the flag with no path argument:

```sh
swift build -c release
bash install.sh --local
```

`--local` searches these project-relative paths in order:

1. `.build/release/RazerMonWidget`
2. `.build/apple/Products/Release/RazerMonWidget`
3. `dist/RazerMonWidget-macos-universal`

It does not download or compile anything and preserves the binary's existing signature. If a local binary is unsigned, sign it first:

```sh
codesign --force --sign - --identifier local.razermonwidget.battery /path/to/RazerMonWidget
```

`scripts/install.sh` forwards the same arguments to the root installer.

## Manage the service

```sh
# Run in the foreground; stop the background service first to avoid concurrent HID access
launchctl bootout gui/$(id -u)/local.razermonwidget.battery
swift run RazerMonWidget

# Reload the installed service
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.razermonwidget.battery.plist

# Check status and logs
launchctl print gui/$(id -u)/local.razermonwidget.battery
tail -f ~/Library/Logs/RazerMonWidget-battery.log

# Uninstall; logs are retained
"$HOME/.local/bin/RazerMonWidget" --uninstall-service

# Run tests
swift test
```

## Behavior and limitations

Battery readings refresh every 60 seconds, with retries after approximately 5 seconds on failure. USB connection changes trigger discovery. Each serial number has a separate widget entry. Sleeping devices and transient read failures retain the last reading; unplugging a receiver removes its entries. A normal SIGTERM/SIGINT shutdown releases all published entries. Avoid running RazerMon or other tools that access the same receiver at the same time.

Battery values are converted from 0–255 to 0–100%. The migrated RazerMon protocol does not read charging status, so charging indicators are not shown.

Publishing uses private IOKit APIs resolved at runtime. A macOS update may change API availability or widget behavior; the service reports an error if the APIs are unavailable. No system widget modification or widget extension is required.

The device catalog is embedded in the executable. The installed copy does not depend on the source directory or SwiftPM resources and survives cleaning the build directory.

## Credits and licenses

- **[RazerMon](https://github.com/ab4317/RazerMon)** provides this project's core logic: HID discovery, the HyperSpeed battery protocol, serial-number identification, battery conversion, and the device catalog. Its original MIT license is preserved in [LICENSE.RazerMon](LICENSE.RazerMon).
- atkctl provides the battery publishing and LaunchAgent management logic. See [LICENSE.atkctl](LICENSE.atkctl).

## Publish a GitHub Release

Maintainers can generate an ad-hoc-signed universal Apple Silicon + Intel executable and its checksum with:

```sh
bash scripts/build-release.sh
```

Release assets:

- `dist/RazerMonWidget-macos-universal`
- `dist/RazerMonWidget-macos-universal.sha256`

Pushing a `v*` tag triggers `.github/workflows/release.yml` to run tests, build both architectures, sign the executable, and upload these assets to the matching GitHub Release. The workflow can also be run manually with an existing tag. Remote installation requires a release containing both assets in the target repository.
