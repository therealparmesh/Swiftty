# Swiftty

A terminal that drops down from the top of the screen when you press a key.

Swiftty lives in the menu bar and has no Dock icon. Press the shortcut and a
terminal slides down over the app you are using. Press it again and the terminal
slides back up. The shell keeps running while the terminal is hidden, so you
always come back to the same session.

Swiftty needs macOS 14 or later.

## Features

- One shortcut shows and hides the terminal, from any app.
- A real login shell, in a pseudo-terminal, with a Homebrew-friendly `PATH`.
- Tokyo Night colors in the terminal and in the settings window.
- Adjustable height, opacity, shell, font, font size, and shortcut.
- A notification when the hidden terminal rings the bell.
- Automatic updates through Sparkle and GitHub Releases.

## Shortcuts

The default global shortcut is `Control` + `Shift` + `` ` ``.

| Shortcut | Action |
| --- | --- |
| `Control` + `Shift` + `` ` `` | Show or hide Swiftty |
| `Command` + `C` / `Command` + `V` | Copy / paste |
| `Command` + `A` | Select all |
| `Command` + `K` | Clear the buffer |
| `Command` + `Shift` + `R` | Start a new session |
| `Command` + `+` / `Command` + `-` | Make the font larger / smaller |
| `Command` + `0` | Reset the font size |
| `Command` + `,` | Open Settings |

Right-click the menu bar icon for Settings, updates, and Quit.

## How it works

Swiftty is a handful of small parts:

| Part | Job |
| --- | --- |
| `AppDelegate` | Starts everything, and slides the window in and out. |
| `DropdownWindow` | The glass panel that slides. It knows where to sit. |
| `TerminalViewController` | The terminal. It starts your shell and keeps it alive. |
| `Preferences` | The memory. It stores settings and announces changes. |
| `SettingsWindowController` | The settings window. It only talks to `Preferences`. |
| `HotKeyValidator` | Says if a shortcut is usable, before Swiftty accepts it. |
| `Updater` | Sparkle, set up for an app with no Dock icon. |

What happens when you press the shortcut:

1. The `HotKey` package catches the key press, even in another app.
2. `AppDelegate` asks `DropdownWindow` for two positions: parked above the
   screen, and open below the menu bar.
3. `AppDelegate` animates the window between the two positions.
4. `TerminalViewController` takes the keyboard focus, so you can type at once.

Settings only move in one direction:

```
SettingsWindowController -> Preferences -> notification -> window and terminal
```

No part reads a setting from a control on screen. Every part reads it from
`Preferences`.

## Develop

```sh
mise run build    # debug build
mise run run      # build the app bundle and start it
mise run lint     # SwiftLint, strict
swift test        # unit tests
```

## Build the app

```sh
./script/make-icon.sh --force      # draw Resources/AppIcon.icns
./script/bundle.sh --config release
open dist/Swiftty.app
```

`bundle.sh` puts the SwiftPM binary into a `.app`, embeds Sparkle, and signs the
result. Without `--sign` the signature is ad-hoc, which is enough to run the app
on your own Mac.

## Release

A release starts from a tag. The tag must match `CFBundleShortVersionString` in
`Sources/Swiftty/Info.plist`.

```sh
git tag v1.0.5
git push origin v1.0.5
```

The release workflow then builds the app, signs it with a Developer ID,
notarizes and staples it, signs the Sparkle appcast, and uploads `Swiftty.zip`
and `appcast.xml`.

These GitHub Actions secrets must exist:

- `CERT_P12`
- `CERT_PASSWORD`
- `SIGN_IDENTITY`
- `APPLE_ID`
- `TEAM_ID`
- `APP_PASSWORD`
- `SPARKLE_ED_PRIVATE_KEY`

## Why there is no sandbox

Swiftty starts your real shell in a pseudo-terminal, the same way other terminal
apps do. The sandbox blocks that, so Swiftty is not sandboxed.

## License

[MIT](LICENSE)
