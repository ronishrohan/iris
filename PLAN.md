# Iris — Implementation Plan

A native macOS Siri replacement built in SwiftUI. Wake-word activated, on-device speech-to-text, DeepSeek V4 as the reasoning + tool-use brain, native macOS TTS. BYOK by default; optional subscription via a Hono proxy backend.

---

## High-level decisions (locked in)

| Area | Choice |
| --- | --- |
| UI | SwiftUI (macOS 14+), AppKit bridges for NSPanel/global hotkey |
| Wake word | openWakeWord (Core ML) + global hotkey (default ⌥-Space) |
| STT default | Apple `SFSpeechRecognizer` on-device |
| STT opt-in | WhisperKit (higher accuracy mode) |
| LLM default | `deepseek-v4-flash` (OpenAI-compatible function calling) |
| LLM "deep think" | `deepseek-v4-pro` toggle |
| TTS | macOS native `AVSpeechSynthesizer` neural voices |
| Tools v1 | open apps, web search, shell (whitelisted), reminders, iMessage, Spotify, Music.app, system volume/brightness, screenshot |
| Backend | Node + Hono + Supabase (Postgres + Auth), Drizzle ORM |
| Billing | deferred (BYOK only for v1; backend has auth + proxy + usage logging only) |
| Secrets storage | macOS Keychain |
| Distribution | notarized DMG (App Store deferred) |

## Repo layout

```
iris/
├── apps/
│   ├── mac/                  # SwiftUI macOS app
│   └── server/               # Node + Hono backend
├── packages/
│   └── shared-types/         # cross-language schemas
├── PLAN.md
└── README.md
```

## Build order

1. Scaffold monorepo (this commit)
2. Mac app: MenuBarExtra shell, Settings scene, global hotkey
3. Permissions manager, audio engine, Apple STT (hotkey-triggered "tap to talk")
4. Orb UI (NSPanel, blur, animated)
5. DeepSeek V4 client (BYOK), streaming chat (no tools)
6. Tool registry + first 3 tools (OpenApp, WebSearch, Reminders) + tool-call loop
7. Remaining tools (Shell, Messages, Spotify, Music, SystemControl, Screenshot)
8. Native TTS pipeline
9. Wake word (openWakeWord Core ML)
10. WhisperKit STT opt-in
11. Backend: Hono, Supabase auth, proxy, usage logging
12. Mac app: auth + BYOK/proxy switch
13. Polish: launch-at-login, conversation history, onboarding

## Out of scope for v1

- Stripe / billing
- iOS companion app
- Cloud sync of conversation history
- Multi-language UI (STT itself is multi-lingual)
- App Store distribution

---

See per-package READMEs (when added) for build/run instructions.
