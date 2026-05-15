# iris

A SwiftUI Siri replacement for macOS. Wake-word + global hotkey activation, on-device speech-to-text, DeepSeek V4 reasoning + tool-use, native macOS voice output.

See [`PLAN.md`](./PLAN.md) for the implementation plan.

## Monorepo

```
apps/
├── mac/        # SwiftUI macOS app
└── server/     # Hono auth + DeepSeek proxy backend
packages/
└── shared-types/
```

## Quick start

```sh
# Mac app
brew install xcodegen
cd apps/mac && xcodegen generate && open Iris.xcodeproj

# Backend
pnpm install
cp apps/server/.env.example apps/server/.env   # fill in values
pnpm server:dev
```
