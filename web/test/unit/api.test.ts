import { describe, expect, test } from 'bun:test';
import { createApi } from '../../server/app';
import { emptyWorkspace } from '../../src/domain/models';
import { studyContext } from '../../src/domain/retrieval';
import { teachingPolicy } from '../../server/policy';

function context() {
  const workspace = emptyWorkspace();
  workspace.courses = [{ id: 'c', name: 'Model systems', goal: 'Understand models', examDate: '' }];
  workspace.selectedCourseId = 'c';
  return studyContext(workspace, 'Models', 'learn');
}
function request(
  path = '/api/tutor',
  body: unknown = {
    provider: 'openai',
    context: context(),
    messages: [{ role: 'user', content: 'Teach me.' }],
  },
) {
  return new Request(`http://127.0.0.1:4318${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-screentutor-client': 'web',
      origin: 'http://127.0.0.1:5173',
    },
    body: JSON.stringify(body),
  });
}
describe('local provider boundary', () => {
  test('rejects cross-origin and DNS-rebinding requests before provider use', async () => {
    let calls = 0;
    const api = createApi({ openai: 'server-secret' }, async () => {
      calls++;
      return new Response();
    });
    const foreign = request();
    foreign.headers.set('origin', 'https://attacker.invalid');
    expect((await api(foreign)).status).toBe(403);
    const rebinding = new Request('http://attacker.invalid:4318/api/status');
    expect((await api(rebinding)).status).toBe(403);
    expect(calls).toBe(0);
  });
  test('requires an explicit client request and reports missing keys', async () => {
    const api = createApi({});
    const simple = request();
    simple.headers.delete('x-screentutor-client');
    expect((await api(simple)).status).toBe(405);
    expect((await api(request())).status).toBe(401);
    const invalid = request('/api/tutor', { provider: 'untrusted-url' });
    expect((await api(invalid)).status).toBe(400);
  });
  test('streams through a fixed provider URL with validated source context', async () => {
    let captured: RequestInit | undefined;
    const api = createApi({}, async (url, init) => {
      expect(url).toBe('https://api.openai.com/v1/chat/completions');
      captured = init;
      return new Response('data: [DONE]\n\n', {
        headers: { 'content-type': 'text/event-stream' },
      });
    });
    const req = request();
    req.headers.set('x-provider-key', 'test-key');
    const response = await api(req);
    expect(await response.text()).toBe('data: [DONE]\n\n');
    const payload = JSON.parse(captured!.body as string);
    expect(payload.stream).toBe(true);
    expect(payload.response_format.json_schema.strict).toBe(true);
    expect(payload.messages[0].content).toContain(teachingPolicy);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
  test('never reflects provider error bodies or credentials', async () => {
    const api = createApi(
      { openai: 'secret-key' },
      async () => new Response('private text and secret-key', { status: 429 }),
    );
    const response = await api(request());
    const text = await response.text();
    expect(response.status).toBe(502);
    expect(text).toContain('429');
    expect(text).not.toContain('private text');
    expect(text).not.toContain('secret-key');
  });
  test('voice uses multipart WebRTC with OpenAI, independent of text provider', async () => {
    const api = createApi({ openai: 'test-key' }, async (url, init) => {
      expect(url).toBe('https://api.openai.com/v1/realtime/calls');
      const form = init!.body as FormData;
      expect(form.get('sdp')).toBe('v=0');
      const session = JSON.parse(form.get('session') as string);
      expect(session.tools.map((tool: { name: string }) => tool.name)).toContain('create_activity');
      expect(session.audio.input.turn_detection.interrupt_response).toBe(true);
      return new Response('v=0\nanswer');
    });
    const response = await api(request('/api/voice', { sdp: 'v=0', context: context() }));
    expect(response.headers.get('content-type')).toBe('application/sdp');
    expect(await response.text()).toBe('v=0\nanswer');
  });
});
