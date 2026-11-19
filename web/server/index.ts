import { resolve, sep } from 'node:path';
import { createApi } from './app';

const production = process.env.NODE_ENV === 'production';
const api = createApi({
  openai: process.env.OPENAI_API_KEY,
  openrouter: process.env.OPENROUTER_API_KEY,
});
const root = resolve(import.meta.dir, '../dist');
const server = Bun.serve({
  hostname: '127.0.0.1',
  port: 4318,
  maxRequestBodySize: 1_500_000,
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) return api(request);
    if (!production)
      return new Response('Use http://127.0.0.1:5173 for the learning client.', { status: 404 });
    const path =
      url.pathname === '/'
        ? resolve(root, 'index.html')
        : resolve(root, '.' + decodeURIComponent(url.pathname));
    if (!path.startsWith(root + sep)) return new Response('Not found', { status: 404 });
    const file = Bun.file(url.pathname === '/' ? resolve(root, 'index.html') : path);
    if (!(await file.exists())) return new Response('Not found', { status: 404 });
    return new Response(file, {
      headers: {
        'X-Content-Type-Options': 'nosniff',
        'Referrer-Policy': 'no-referrer',
        'Content-Security-Policy':
          "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; worker-src 'self' blob:; connect-src 'self' https://api.openai.com; media-src 'self' blob:; object-src 'none'; frame-ancestors 'none'; base-uri 'self'",
        'Cache-Control': url.pathname.startsWith('/assets/')
          ? 'public, max-age=31536000, immutable'
          : 'no-cache',
      },
    });
  },
});
let vite: { close(): Promise<void> } | undefined;
if (!production) {
  const { createServer } = await import('vite');
  const dev = await createServer();
  await dev.listen();
  vite = dev;
  console.info('Learning client: http://127.0.0.1:5173');
} else console.info('Learning client: http://127.0.0.1:4318');
for (const signal of ['SIGINT', 'SIGTERM'] as const)
  process.on(signal, async () => {
    await vite?.close();
    server.stop(true);
    process.exit(0);
  });
