import { replySchema, type TutorReply, type TutorRequest } from '../domain/schema';

import { apiHeaders, responseError } from './http';

export async function requestTutor(
  input: TutorRequest,
  key: string,
  signal: AbortSignal,
  onProgress: () => void,
): Promise<TutorReply> {
  const response = await fetch('/api/tutor', {
    method: 'POST',
    headers: apiHeaders(key),
    body: JSON.stringify(input),
    signal,
  });
  if (!response.ok) throw await responseError(response);
  if (!response.body) throw new Error('The tutor returned no response stream.');
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let pending = '',
    content = '',
    done = false;
  try {
    while (!done) {
      const chunk = await reader.read();
      if (chunk.done) break;
      pending = (pending + decoder.decode(chunk.value, { stream: true })).replace(/\r\n/g, '\n');
      if (pending.length > 1_000_000)
        throw new Error('The provider stream exceeded the allowed size.');
      let end: number;
      while ((end = pending.indexOf('\n\n')) >= 0) {
        const frame = pending.slice(0, end);
        pending = pending.slice(end + 2);
        const data = frame
          .split('\n')
          .filter((line) => line.startsWith('data:'))
          .map((line) => line.slice(5).trimStart())
          .join('\n');
        if (!data) continue;
        if (data === '[DONE]') {
          done = true;
          break;
        }
        const event = JSON.parse(data);
        if (event.error) throw new Error('The tutor provider interrupted the response. Try again.');
        const delta = event.choices?.[0]?.delta?.content;
        if (typeof delta === 'string') {
          content += delta;
          onProgress();
        }
        if (content.length > 50_000)
          throw new Error('The generated activity exceeded the allowed size.');
      }
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  if (!done)
    throw new Error('The tutor connection ended before the activity was complete. Try again.');
  let json: unknown;
  try {
    json = JSON.parse(content);
  } catch {
    throw new Error('The tutor returned an incomplete activity. Try again.');
  }
  const parsed = replySchema.safeParse(json);
  if (!parsed.success)
    throw new Error('The tutor returned an unsupported activity. Your previous work is unchanged.');
  const reply = parsed.data;
  const validSources = new Set(input.context.sources.map((source) => source.id));
  if (reply.activity?.sourceIds.some((id) => !validSources.has(id)))
    throw new Error('The tutor cited a source outside the supplied material. Please retry.');
  if (
    reply.activity?.diagram?.links.some(
      (link) =>
        link.from >= reply.activity!.diagram!.nodes.length ||
        link.to >= reply.activity!.diagram!.nodes.length,
    )
  ) {
    throw new Error('The tutor returned a diagram with an invalid connection. Please retry.');
  }
  return reply;
}
