import { db } from './db.js';
import { usageLogs } from '../schema/usage.js';

export async function recordUsage(args: {
  userId: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
}): Promise<void> {
  await db.insert(usageLogs).values({
    userId: args.userId,
    model: args.model,
    inputTokens: args.inputTokens,
    outputTokens: args.outputTokens,
  });
}
