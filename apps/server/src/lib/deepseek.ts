const BASE = process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com';
const KEY = process.env.DEEPSEEK_API_KEY ?? '';

export type UsageSummary = {
  model: string;
  promptTokens: number;
  completionTokens: number;
};

export async function streamDeepSeek(body: unknown): Promise<Response> {
  return fetch(`${BASE}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${KEY}`,
      Accept: 'text/event-stream',
    },
    body: JSON.stringify(body),
  });
}

/**
 * Tees an SSE response into the client while parsing `usage` chunks to call
 * `onUsage` exactly once when the stream completes.
 */
export function teeWithUsageTracking(
  upstream: ReadableStream<Uint8Array>,
  onUsage: (u: UsageSummary | null) => void
): ReadableStream<Uint8Array> {
  const decoder = new TextDecoder();
  let buffer = '';
  let usage: UsageSummary | null = null;

  const transformer = new TransformStream<Uint8Array, Uint8Array>({
    transform(chunk, controller) {
      controller.enqueue(chunk);
      buffer += decoder.decode(chunk, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';
      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const payload = line.slice(6).trim();
        if (!payload || payload === '[DONE]') continue;
        try {
          const json = JSON.parse(payload) as {
            model?: string;
            usage?: { prompt_tokens?: number; completion_tokens?: number };
          };
          if (json.usage) {
            usage = {
              model: json.model ?? 'unknown',
              promptTokens: json.usage.prompt_tokens ?? 0,
              completionTokens: json.usage.completion_tokens ?? 0,
            };
          }
        } catch {
          // ignore non-JSON keepalives
        }
      }
    },
    flush() {
      onUsage(usage);
    },
  });

  return upstream.pipeThrough(transformer);
}
