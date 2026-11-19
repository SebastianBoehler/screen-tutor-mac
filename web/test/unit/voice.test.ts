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
