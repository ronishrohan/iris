// Usage accounting now lives in lib/usage.ts and is invoked by routes/proxy.ts
// via the tee transform exported from lib/deepseek.ts. This file is kept as a
// placeholder so a future per-request quota check can hang off the middleware
// chain.
export {};
