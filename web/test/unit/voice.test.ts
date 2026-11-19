import { afterEach, beforeEach, expect, test } from 'bun:test';
import { VoiceSession, type VoiceEvents } from '../../src/services/voice';
import { emptyWorkspace } from '../../src/domain/models';
import { studyContext } from '../../src/domain/retrieval';

const saved = new Map<string, PropertyDescriptor | undefined>();
const originalFetch = globalThis.fetch;
class TestAudio {
  srcObject = null;
  onplaying = null;
  play() {
    return Promise.resolve();
  }
  pause() {}
}
class TestChannel {
  readyState = 'open';
  onopen = null;
  onclose: (() => void) | null = null;
  onerror = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  sent: string[] = [];
  send(data: string) {
    this.sent.push(data);
  }
  close() {
    this.readyState = 'closed';
    this.onclose?.();
  }
}
class TestPeer {
  static channels: TestChannel[] = [];
  channel = new TestChannel();
  ontrack = null;
  onconnectionstatechange = null;
  connectionState = 'connected';
  addTrack() {}
  close() {}
  createDataChannel() {
    TestPeer.channels.push(this.channel);
    return this.channel;
  }
  async createOffer() {
    return { type: 'offer', sdp: 'test-offer' };
  }
  async setLocalDescription() {}
  async setRemoteDescription() {}
}
function globals(name: string, value: unknown) {
  if (!saved.has(name)) saved.set(name, Object.getOwnPropertyDescriptor(globalThis, name));
  Object.defineProperty(globalThis, name, { configurable: true, value });
}
function context() {
  const workspace = emptyWorkspace();
  workspace.courses = [{ id: 'c', name: 'Models', goal: '', examDate: '' }];
  workspace.selectedCourseId = 'c';
  return studyContext(workspace, 'model', 'learn');
}
const track = () => ({
  enabled: true,
  stopped: false,
  stop() {
    this.stopped = true;
  },
});
function events(activity: VoiceEvents['activity'] = async () => 'ready') {
  const statuses: string[] = [];
  const errors: string[] = [];
  return {
    statuses,
    errors,
    callbacks: {
      status: (value) => statuses.push(value),
      error: (value) => errors.push(value),
      transcript() {},
      firstAudio() {},
      inspect: () => '{}',
      activity,
    } satisfies VoiceEvents,
  };
}
beforeEach(() => {
  TestPeer.channels = [];
  globals('Audio', TestAudio);
  globals('RTCPeerConnection', TestPeer);
  globalThis.fetch = Object.assign(async () => new Response('test-answer'), {
    preconnect: originalFetch.preconnect,
  });
});
afterEach(() => {
  globalThis.fetch = originalFetch;
  for (const [name, descriptor] of saved) {
    if (descriptor) Object.defineProperty(globalThis, name, descriptor);
    else Reflect.deleteProperty(globalThis, name);
  }
  saved.clear();
});
test('cancelling while microphone permission is pending stops a late media stream', async () => {
  let resolve!: (stream: unknown) => void;
  const media = new Promise((done) => {
    resolve = done;
  });
  const input = track();
  globals('navigator', { mediaDevices: { getUserMedia: () => media } });
  const output = events();
  const voice = new VoiceSession(output.callbacks);
  const connecting = voice.connect('test-key', context());
  voice.disconnect();
  resolve({ getTracks: () => [input] });
  await connecting;
  expect(input.stopped).toBe(true);
  expect(TestPeer.channels).toHaveLength(0);
  expect(output.errors).toHaveLength(0);
});
test('mute affects only local upload, and disconnect releases microphone tracks', async () => {
  const input = track();
  globals('navigator', {
    mediaDevices: {
      getUserMedia: async () => ({ getTracks: () => [input], getAudioTracks: () => [input] }),
    },
  });
  const output = events();
  const voice = new VoiceSession(output.callbacks);
  await voice.connect('test-key', context());
  voice.toggleMute();
  expect(input.enabled).toBe(false);
  expect(input.stopped).toBe(false);
  voice.disconnect();
  expect(input.stopped).toBe(true);
  expect(output.statuses.at(-1)).toBe('off');
});
test('a tool completing after reconnection cannot write into the new voice session', async () => {
  globals('navigator', {
    mediaDevices: { getUserMedia: async () => ({ getTracks: () => [track()] }) },
  });
  let complete!: (result: string) => void;
  const result = new Promise<string>((resolve) => {
    complete = resolve;
  });
  const output = events(() => result);
  const voice = new VoiceSession(output.callbacks);
  await voice.connect('test-key', context());
  TestPeer.channels[0].onmessage!({
    data: JSON.stringify({
      type: 'response.function_call_arguments.done',
      call_id: 'old-call',
      name: 'create_activity',
      arguments: '{"request":"A model activity"}',
    }),
  });
  await voice.connect('test-key', context());
  complete('ready');
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(TestPeer.channels[1].sent).toHaveLength(0);
  voice.disconnect();
});

test('voice inspection returns current model data without generating another activity', async () => {
  globals('navigator', {
    mediaDevices: { getUserMedia: async () => ({ getTracks: () => [track()] }) },
  });
  const output = events(async () => {
    throw new Error('Inspection must not create an activity.');
  });
  output.callbacks.inspect = () => JSON.stringify({ rate: 3, probability: Math.exp(-3) });
  const voice = new VoiceSession(output.callbacks);
  await voice.connect('test-key', context());
  TestPeer.channels[0].onmessage!({
    data: JSON.stringify({
      type: 'response.function_call_arguments.done',
      call_id: 'inspection',
      name: 'inspect_activity',
      arguments: '{}',
    }),
  });
  await new Promise((resolve) => setTimeout(resolve, 0));
  const result = TestPeer.channels[0].sent
    .map((value) => JSON.parse(value))
    .find((value) => value.item?.type === 'function_call_output');
  expect(JSON.parse(result.item.output).rate).toBe(3);
  expect(output.errors).toHaveLength(0);
  voice.disconnect();
});

test('queues typed turns during a response and preserves the connection on recoverable errors', async () => {
  globals('navigator', {
    mediaDevices: {
      getUserMedia: async () => ({ getTracks: () => [track()], getAudioTracks: () => [] }),
    },
  });
  const output = events();
  const voice = new VoiceSession(output.callbacks);
  await voice.connect('test-key', context());
  const channel = TestPeer.channels[0];
  const emit = (event: unknown) => channel.onmessage!({ data: JSON.stringify(event) });
  emit({ type: 'response.created' });
  emit({ type: 'output_audio_buffer.started' });
  voice.toggleMute();
  voice.toggleMute();
  expect(output.statuses.at(-1)).toBe('speaking');
  voice.sendText('A typed question');
  expect(channel.sent.filter((item) => JSON.parse(item).type === 'response.create')).toHaveLength(
    0,
  );
  emit({ type: 'error', error: { code: 'conversation_already_has_active_response' } });
  expect(voice.connected).toBe(true);
  emit({ type: 'response.done' });
  expect(channel.sent.filter((item) => JSON.parse(item).type === 'response.create')).toHaveLength(
    0,
  );
  emit({ type: 'output_audio_buffer.stopped' });
  expect(channel.sent.filter((item) => JSON.parse(item).type === 'response.create')).toHaveLength(
    1,
  );
  voice.updateContext(context());
  voice.updateContext(context());
  const items = channel.sent.map((item) => JSON.parse(item));
  const contexts = items.filter((item) => item.item?.id?.startsWith('context_'));
  expect(contexts).toHaveLength(2);
  expect(items.find((item) => item.type === 'conversation.item.delete')?.item_id).toBe(
    contexts[0].item.id,
  );
  voice.disconnect();
});

test('voice dispatches validated artifact controls and labels typed turns', async () => {
  globals('navigator', {
    mediaDevices: { getUserMedia: async () => ({ getTracks: () => [track()] }) },
  });
  const output = events();
  const commands: unknown[] = [];
  const voice = new VoiceSession({
    ...output.callbacks,
    controlArtifact: (command) => {
      commands.push(command);
      return 'changed';
    },
  });
  await voice.connect('test-key', context());
  const channel = TestPeer.channels[0];
  voice.sendText('Change the slope');
  expect(channel.sent[0]).toContain('[Typed chat message]');
  channel.onmessage!({
    data: JSON.stringify({
      type: 'response.function_call_arguments.done',
      call_id: 'flip',
      name: 'control_artifact',
      arguments: JSON.stringify({
        action: 'reveal_flashcard',
        activityId: 'a',
        parameter: null,
        value: null,
      }),
    }),
  });
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(commands).toEqual([{ action: 'reveal_flashcard', activityId: 'a' }]);
  expect(channel.sent.some((value) => value.includes('changed'))).toBe(true);
  voice.disconnect();
});

test('voice stage tools share typed sequencing, reject stale submissions, and record explicit help', async () => {
  const { openInvestigation, submitInvestigation, giveInvestigationHint, updateExperiment } =
    await import('../../src/investigation/workspace');
  const { getInvestigation } = await import('../../src/investigation/model');
  const { runQueueComparison } = await import('../../src/investigation/experiment');
  globals('navigator', {
    mediaDevices: { getUserMedia: async () => ({ getTracks: () => [track()] }) },
  });
  let workspace = openInvestigation(emptyWorkspace());
  const output = events();
  const voice = new VoiceSession({
    ...output.callbacks,
    investigation: (input) => {
      workspace =
        input === 'hint' ? giveInvestigationHint(workspace) : submitInvestigation(workspace, input);
      return JSON.stringify({ stage: getInvestigation(workspace)?.stage });
    },
  });
  await voice.connect('test-key', context());
  const channel = TestPeer.channels[0];
  const call = async (id: string, name: string, args: unknown) => {
    channel.onmessage!({
      data: JSON.stringify({
        type: 'response.function_call_arguments.done',
        call_id: id,
        name,
        arguments: JSON.stringify(args),
      }),
    });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const result = channel.sent
      .map((value) => JSON.parse(value))
      .find((value) => value.item?.call_id === id)?.item.output;
    channel.onmessage!({ data: JSON.stringify({ type: 'response.done' }) });
    return result;
  };
  const submit = (id: string, stage: string, text: string, choice?: string) =>
    call(id, 'submit_investigation_response', { stage, text, ...(choice ? { choice } : {}) });
  await submit('one', 'explain', 'Less than capacity should suffice.');
  expect(getInvestigation(workspace)?.responses.explain?.medium).toBe('voice');
  expect(await submit('stale', 'explain', 'Old answer')).toContain('moved on');
  expect(await submit('invalid', 'predict', '')).toContain('1–1,200');
  await submit('two', 'predict', 'Closer to capacity means more waiting.');
  expect(getInvestigation(workspace)?.experiment?.status).toBe('queued');
  expect(channel.sent.filter((value) => JSON.parse(value).type === 'response.create')).toHaveLength(
    4,
  );
  workspace = updateExperiment(workspace, getInvestigation(workspace)!.experiment!.id, {
    status: 'ready',
    result: runQueueComparison(),
  });
  await submit('three', 'revise', 'Bursts clear more slowly.');
  await call('hint', 'give_investigation_hint', {});
  await submit('four', 'apply', 'Demand exceeds capacity.', 'no');
  expect(workspace.interactions.at(-1)).toMatchObject({ verdict: 'correct', assisted: true });
  await submit('four', 'apply', 'Demand exceeds capacity.', 'no');
  expect(workspace.interactions.filter((item) => item.kind === 'attempt')).toHaveLength(1);
  const before = channel.sent.length;
  voice.updateContext(context());
  expect(channel.sent.slice(before).map((value) => JSON.parse(value).type)).toEqual([
    'conversation.item.create',
  ]);
  voice.disconnect();
});
