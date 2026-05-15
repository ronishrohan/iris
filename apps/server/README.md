# @iris/server

Auth + DeepSeek proxy backend for Iris.

## Setup

```sh
cp .env.example .env
pnpm install
pnpm --filter @iris/server dev
```

## Routes

- `GET  /health`
- `POST /auth/signup`             `{ email, password }`
- `POST /auth/login`              `{ email, password }`
- `GET  /me`                      bearer-protected
- `GET  /me/usage`                bearer-protected
- `POST /v1/chat/completions`     bearer-protected, streams DeepSeek
