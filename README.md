# Ember

A minimal Pomodoro timer that lives in the macOS menu bar.

[Русская версия](README.ru.md)

> **Status:** early development (v0.1). Core timer and UI are in place.

## Overview

Ember sits in the menu bar and shows the remaining time next to a small status dot:

- orange dot: focus session
- yellow dot: break

Click the menu bar item to open a translucent popover.

### Setup screen

- **Session**: focus length in minutes
- **Break**: short break length in minutes
- **Cycle**: number of short breaks before a long one
- **Long break +N**: how many minutes the long break lasts on top of the short break (long break = short break + N)
- **Repeat cycle**: start a new cycle automatically after the long break (on by default); when off, Ember stops and returns to setup
- **Start**

### Running screen

- A filling orange ring with the countdown in the middle
- **Pause** and **Stop** buttons
- **+5 min**: extend the current session without stopping it

Phases switch automatically: session, break, session, and so on. When a phase ends, a soft chime plays and the menu bar digits change color.

## Design

- Light and dark themes
- Orange accent on dark gray
- Translucent, blurred background
- English-only interface

## Tech

- Swift, SwiftUI popover hosted in an `NSStatusItem` (so the menu bar text can be colored)
- Swift Package Manager, no Xcode project required
- macOS 13 or later

## Build

Requires the Swift toolchain (Xcode or Command Line Tools).

```bash
git clone https://github.com/ZWIYS/Ember-Pomodoro-MacOS.git
cd Ember-Pomodoro-MacOS
./scripts/build-app.sh
open build/Ember.app
```

To run without bundling: `swift run`.

## License

MIT, see [LICENSE](LICENSE).
