import { contextSchema } from '../src/domain/schema';
import type { ProviderFetch, ServerKeys } from './tutor';
import { investigationVoicePolicy, investigationVoiceTools } from './investigationVoice';
import { canvasVoicePolicy, canvasVoiceTool, holdCanvasTool } from './canvasVoice';
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
      instructions: `${teachingPolicy}\n${interactivePolicy}\n${investigationVoicePolicy}\n${canvasVoicePolicy}\nThis is a live voice session. Audio input is spoken; messages marked [Typed chat message] are typed, even while voice is connected. Respond naturally to each channel. Use create_activity when a rich activity would help. Use submit_attempt to record and assess an actual learner answer. Ordinary voice-supported attempts are conservatively assisted; guided investigations use the dedicated assistance policy. Before answering about or controlling an artifact, call inspect_activity. When the learner has answered a flashcard or explicitly asks to reveal it, call control_artifact with reveal_flashcard. Never reveal before an answer or explicit request. When asked to adjust a supported parameter, inspect its current value and use control_artifact with an exact valid value. If the parameter, value, or intended change is unclear, ask; do not claim success when the tool fails. Do not claim to see or run an interactive model without inspection.\nUntrusted context: ${JSON.stringify(context.data)}`,
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
        ...investigationVoiceTools,
        canvasVoiceTool,
        holdCanvasTool,
        {
          type: 'function',
          name: 'control_artifact',
          description:
            'Reveal the selected flashcard after an answer or request, or set a supported formula parameter. Inspect first and use the exact selected activity ID. Supported parameters: linear slope and intercept; exponential rate and time; gradient-descent learningRate; queue arrivalRate and serviceRate (restarts the run). Values must match displayed bounds and increments.',
          parameters: {
            type: 'object',
            properties: {
              action: { type: 'string', enum: ['reveal_flashcard', 'set_parameter'] },
              activityId: { type: 'string', maxLength: 120 },
              parameter: { type: ['string', 'null'] },
              value: { type: ['number', 'null'] },
            },
            required: ['action', 'activityId', 'parameter', 'value'],
            additionalProperties: false,
          },
        },
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
