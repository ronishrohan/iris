# Iris — macOS app

SwiftUI menu-bar app that replaces Siri.

## Prerequisites

- macOS 14+
- Xcode 16+ (Swift 6)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Generate the Xcode project

```sh
cd apps/mac
xcodegen generate
open Iris.xcodeproj
```

## Run

Build and run the `Iris` scheme. The app appears in the menu bar (no Dock icon).

- ⌥-Space toggles the orb.
- Settings → Providers: paste your DeepSeek API key.
- Settings → Wake Word / Tools: configure behavior.

## Layout

- `Iris/App/` — `@main`, MenuBarExtra, AppState.
- `Iris/Features/Orb/` — floating NSPanel UI.
- `Iris/Features/Settings/` — Settings scene.
- `Iris/Core/Audio/`, `STT/`, `TTS/`, `LLM/`, `Tools/`, `Hotkey/`, `Permissions/`, `Storage/`, `Conversation/`.
