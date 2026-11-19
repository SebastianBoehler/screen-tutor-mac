import { afterEach, expect, test } from 'bun:test';
import { requestTutor } from '../../src/services/tutor';
import { emptyWorkspace } from '../../src/domain/models';
import { studyContext } from '../../src/domain/retrieval';
import type { TutorReply, TutorRequest } from '../../src/domain/schema';

const originalFetch = globalThis.fetch;
afterEach(() => {
  globalThis.fetch = originalFetch;
});
const reply: TutorReply = {
  message: 'Explain the distinction in your own words.',
  activity: null,
  assessment: { verdict: 'ungraded', feedback: '' },
  memory: null,
};
function input(): TutorRequest {
  const workspace = emptyWorkspace();
  workspace.courses = [{ id: 'c', name: 'Models', goal: '', examDate: '' }];
  workspace.selectedCourseId = 'c';
  return {
    provider: 'openai',
    context: studyContext(workspace, 'model', 'learn'),
    messages: [{ role: 'user', content: 'Teach me.' }],
  };
}
function serve(data: string, splitEvery = 7) {
  const encoded = new TextEncoder().encode(data);
  globalThis.fetch = Object.assign(
    async () =>
      new Response(
        new ReadableStream({
          start(controller) {
            for (let index = 0; index < encoded.length; index += splitEvery)
              controller.enqueue(encoded.slice(index, index + splitEvery));
            controller.close();
          },
        }),
      ),
    { preconnect: originalFetch.preconnect },
  );
}
function frame(value: unknown, ending = '\n') {
  return `data: ${JSON.stringify({ choices: [{ delta: { content: JSON.stringify(value) } }] })}${ending}${ending}data: [DONE]${ending}${ending}`;
}
test('handles fragmented UTF-8 and CRLF across network chunks', async () => {
  const unicode = { ...reply, message: 'Erkläre die Überprüfung: 模型.' };
  serve(frame(unicode, '\r\n'), 1);
  expect(
    (await requestTutor(input(), 'test-key', new AbortController().signal, () => {})).message,
  ).toBe(unicode.message);
});
test('rejects an interrupted response instead of constructing a partial activity', async () => {
  serve('data: {"choices":[{"delta":{"content":"{\\"message\\":"}}]}\n\n');
  await expect(requestTutor(input(), '', new AbortController().signal, () => {})).rejects.toThrow(
    'ended before',
  );
});
test('rejects fabricated source references', async () => {
  serve(
    frame({
      ...reply,
      activity: {
        title: 'A source',
        concept: 'Models',
        body: '',
        question: '?',
        answer: 'x',
        hint: '',
        explanation: '',
        choices: [],
        diagram: null,
        interactive: null,
        sourceIds: ['not-supplied:1:0'],
      },
    }),
  );
  await expect(requestTutor(input(), '', new AbortController().signal, () => {})).rejects.toThrow(
    'outside the supplied material',
  );
});
