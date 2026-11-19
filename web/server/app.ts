import { tutorResponse, type ProviderFetch, type ServerKeys } from './tutor';
import { voiceResponse } from './voice';

const hosts = new Set(['localhost', '127.0.0.1']);
const origins = new Set([
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:4318',
  'http://127.0.0.1:4318',
]);
export function createApi(keys: ServerKeys, fetchProvider: ProviderFetch = fetch) {
  return async (request: Request): Promise<Response> => {
    const url = new URL(request.url);
    const origin = request.headers.get('origin');
    if (!hosts.has(url.hostname) || (origin && !origins.has(origin))) {
      return Response.json(
        {
          error: 'This local API accepts only the ScreenTutor client on this machine.',
        },
        { status: 403 },
      );
    }
    if (url.pathname === '/api/status' && request.method === 'GET') {
      return Response.json(
        { openai: !!keys.openai, openrouter: !!keys.openrouter },
        { headers: { 'Cache-Control': 'no-store' } },
      );
    }
    if (
      request.method !== 'POST' ||
      request.headers.get('x-screentutor-client') !== 'web' ||
      !request.headers.get('content-type')?.startsWith('application/json')
    ) {
      return Response.json({ error: 'Unsupported request.' }, { status: 405 });
    }
    try {
      if (url.pathname === '/api/tutor') return await tutorResponse(request, keys, fetchProvider);
      if (url.pathname === '/api/voice') return await voiceResponse(request, keys, fetchProvider);
      return Response.json({ error: 'Unknown study endpoint.' }, { status: 404 });
    } catch (error) {
      if (error instanceof SyntaxError)
        return Response.json({ error: 'The request is not valid JSON.' }, { status: 400 });
      return Response.json(
        {
          error: 'The provider request failed or timed out. Your saved work is still available.',
        },
        { status: 502 },
      );
    }
  };
}
