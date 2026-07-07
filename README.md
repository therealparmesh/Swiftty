# Swiftty

Swiftty is a Quake-style dropdown terminal for macOS. It lives in the menu bar,
stays out of the Dock, and slides down over the current screen when you press
its global shortcut.

Requires macOS 14 or later.

## Features

- Global menu bar terminal with no Dock tile
- Tokyo Night terminal colors out of the box
- Adjustable window height, opacity, shell, font, and shortcut
- Real login shell through a PTY, with Homebrew-friendly PATH defaults
- Bell notifications while the terminal is hidden
- Sparkle updates from GitHub Releases

## Shortcuts

The default global shortcut is `Control` + `Shift` + `` ` ``.

| Shortcut | Action |
| --- | --- |
| `Control` + `Shift` + `` ` `` | Toggle Swiftty |
| `Command` + `C` / `Command` + `V` | Copy / paste |
| `Command` + `A` | Select all |
| `Command` + `K` | Clear buffer |
| `Command` + `Shift` + `R` | Reset session |
| `Command` + `,` | Open Settings |

Right-click the menu bar icon for Settings, updates, and Quit.

## Build

```sh
./Scripts/make-icon.sh --force
./Scripts/bundle.sh --config release
open dist/Swiftty.app
```

For a plain SwiftPM build:

```sh
swift build
```

## Release

Releases are cut from tags:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The GitHub release workflow builds the app, signs it with Developer ID,
notarizes and staples it, signs the Sparkle appcast, and uploads `Swiftty.zip`
plus `appcast.xml`.

Required GitHub Actions secrets:

- `CERT_P12`
- `CERT_PASSWORD`
- `SIGN_IDENTITY`
- `APPLE_ID`
- `TEAM_ID`
- `APP_PASSWORD`
- `SPARKLE_ED_PRIVATE_KEY`

## Sandbox

Swiftty is intentionally not sandboxed. It starts your real shell through a
pseudo-terminal, the same model used by terminal apps. The sandbox would block
that workflow.

## License

[MIT](LICENSE)
