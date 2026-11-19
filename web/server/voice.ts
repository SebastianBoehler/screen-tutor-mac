import { contextSchema } from '../src/domain/schema';
import type { ProviderFetch, ServerKeys } from './tutor';
import { teachingPolicy, interactivePolicy } from './policy';

export async function voiceResponse(
  request: Request,
  keys: ServerKeys,
  fetchProvider: ProviderFetch = fetch,
) {
  const body = await request.json();
  const context = contextSchema.safeParse(body.context);
  if (!context.success || typeof body.sdp !== 'string' || body.sdp.length > 100_000) {
    return Response.json({ error: 'The voice connection request is invalid.' }, { status: 400 });
  }
  const key = request.headers.get('x-provider-key')?.trim() || keys.openai;
  if (!key)
    return Response.json(
      { error: 'Add an OpenAI API key in Connections to use live voice.' },
      { status: 401 },
    );
  const data = new FormData();
  data.set('sdp', body.sdp);
  data.set(
    'session',
    JSON.stringify({
      type: 'realtime',
      model: 'gpt-realtime-2.1',
      instructions: `${teachingPolicy}\n${interactivePolicy}\nFor voice, speak naturally, not JSON. Use create_activity when a rich activity would help. Use submit_attempt to record and assess an actual learner answer. Voice-supported attempts are conservatively assisted. Before answering about the current plot, parameters, or simulation, call inspect_activity to read its current state. Do not claim to see or run an interactive model without that result.\nUntrusted context: ${JSON.stringify(context.data)}`,
      output_modalities: ['audio'],
      audio: {
        input: {
          transcription: { model: 'gpt-4o-mini-transcribe' },
          turn_detection: {
            type: 'semantic_vad',
            create_response: true,
            interrupt_response: true,
          },
        },
        output: { voice: 'marin' },
      },
      tools: [
        {
          type: 'function',
          name: 'inspect_activity',
          description:
            'Read the current activity and live interactive model parameters, observations and assistance status. This is an inspection, not a mastery check.',
          parameters: { type: 'object', properties: {}, required: [], additionalProperties: false },
        },
        {
          type: 'function',
          name: 'submit_attempt',
          description:
            'Record the learner’s actual current-activity answer and reasoning. Do not invent a response. Request contains their own words. Wait for the assessment.',
          parameters: {
            type: 'object',
            properties: { request: { type: 'string', maxLength: 1200 } },
            required: ['request'],
            additionalProperties: false,
          },
        },
        {
          type: 'function',
          name: 'create_activity',
          description:
            'Ask the learning harness to create one rich activity from the current course. Wait for its result before continuing.',
          parameters: {
            type: 'object',
            properties: { request: { type: 'string', maxLength: 1200 } },
            required: ['request'],
            additionalProperties: false,
          },
        },
      ],
    }),
  );
  const response = await fetchProvider('https://api.openai.com/v1/realtime/calls', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}` },
    body: data,
    signal: AbortSignal.any([request.signal, AbortSignal.timeout(30_000)]),
  });
  if (!response.ok)
    return Response.json(
      {
        error: `OpenAI voice returned HTTP ${response.status}. Check your key, credit and Realtime access.`,
      },
      { status: 502 },
    );
  return new Response(response.body, {
    headers: { 'Content-Type': 'application/sdp', 'Cache-Control': 'no-store' },
  });
}
