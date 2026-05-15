# Iris — Implementation Plan

A native macOS Siri replacement built in SwiftUI.

## Current status: PoC

The repo is currently scoped to a proof of concept:

- Menu-bar SwiftUI app, global hotkey ⌥-Space
- Floating orb (NSPanel, blur, animated gradient)
- On-device speech-to-text via Apple `SFSpeechRecognizer`
- DeepSeek V4 (BYOK) streaming chat with function calling
- Two tools: `open_app`, `web_search` (DuckDuckGo instant answer)
- macOS native TTS (`AVSpeechSynthesizer`)
- Settings: API key, model picker, tool toggles

Backend (`apps/server`) is scaffolded but not used by the PoC.

## Out of PoC scope (deferred)

- Wake-word listening (openWakeWord)
- WhisperKit STT
- Auth + subscription proxy
- Conversation history (SwiftData)
- Launch-at-login (SMAppService)
- Additional tools (reminders, messages, spotify, music, system control, screenshot, shell)

These pieces existed in commit `e2e5f1b` and can be brought back when the PoC is validated.

## Build

```sh
brew install xcodegen
cd apps/mac && xcodegen generate
open Iris.xcodeproj
```

Add your DeepSeek key in Settings → Provider, then press ⌥-Space.
