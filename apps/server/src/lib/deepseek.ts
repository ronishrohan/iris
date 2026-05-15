const BASE = process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com';
const KEY = process.env.DEEPSEEK_API_KEY ?? '';

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
