// Study room entry point: `bun run dev` (or `bun server.ts`).
// Bun loads .env and .env.local from this directory automatically.

import { configFromEnv, startServer } from "./src/server/app";
import { resolveObserverModel } from "./src/server/observer";

const config = configFromEnv();
const port = Number(process.env.PORT ?? 3000);
const { server } = startServer({
  ...config,
  port,
  hostname: process.env.HOST,
  development: process.env.NODE_ENV !== "production",
});

console.log(`Study room on ${server.url}`);
console.log(`  tutor voice: ${config.openaiKey ? config.tutorModel : "off (set OPENAI_API_KEY)"}`);
const observer = resolveObserverModel(config.observer);
console.log(`  desk observer: ${observer ? `${observer.model} via ${observer.provider}` : "off (needs OPENAI_API_KEY or OPENROUTER_API_KEY)"}`);
