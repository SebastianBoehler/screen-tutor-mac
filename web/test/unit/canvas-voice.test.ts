import { expect, test } from 'bun:test';
import { emptyWorkspace } from '../../src/domain/models';
import { openCanvasExample } from '../../src/domain/canvasExamples';
import { canvasVoiceEvents } from '../../src/canvas/voiceEvents';
import { guidanceSchema, guideCanvas, registerCanvasGuide } from '../../src/canvas/guidance';
import { registerArtifactControl, applyArtifactControl } from '../../src/interactive/control';
import {
  initialInteractiveState,
  setLiveInteractive,
  clearLiveInteractive,
} from '../../src/interactive/state';

test('voice preparation acknowledges immediately, deduplicates in-flight work and preserves provider errors', async () => {
  const current = { current: openCanvasExample(emptyWorkspace()) };
  const errors: string[] = [];
  let calls = 0;
  let reject!: (error: Error) => void;
  const pending = new Promise<string>((_, fail) => {
    reject = fail;
  });
  const callbacks = canvasVoiceEvents({
    current,
    hold() {},
    error: (message) => errors.push(message),
    turn() {},
    investigation: () => '{}',
    send: {
      current: async (_request, options) => {
        calls++;
        expect(options?.presentation).toBe('defer');
        return pending;
      },
    },
  });
  expect(await callbacks.activity('Show a new representation', false)).toContain('background');
  expect(await callbacks.activity('Show it again', false)).toContain('already being prepared');
  expect(calls).toBe(1);
  expect(JSON.parse(callbacks.inspect()).presentation.preparing).toBe(true);
  reject(new Error('Provider failed.'));
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(errors).toEqual(['Provider failed.']);
  expect(JSON.parse(callbacks.inspect()).presentation.preparing).toBe(false);
});

test('a spoken answer waits for view preparation without losing its activity', async () => {
  const current = { current: openCanvasExample(emptyWorkspace()) };
  let finish!: (value: string) => void;
  const pending = new Promise<string>((resolve) => {
    finish = resolve;
  });
  const calls: boolean[] = [];
  const callbacks = canvasVoiceEvents({
    current,
    hold() {},
    error() {},
    turn() {},
    investigation: () => '{}',
    send: {
      current: async (_request, options) => {
        calls.push(!!options?.attempt);
        return options?.attempt ? 'Answer saved' : pending;
      },
    },
  });
  await callbacks.activity('Prepare', false);
  const answer = callbacks.activity('My answer', true);
  expect(calls).toEqual([false]);
  finish('Prepared');
  expect(await answer).toBe('Answer saved');
  expect(calls).toEqual([false, true]);
});

test('queue control keeps the activity, restarts the real run and gives an exact visual change receipt', async () => {
  const current = { current: openCanvasExample(emptyWorkspace()) };
  const active = current.current.activities[0];
  const spec = active.interactive!;
  let state = initialInteractiveState(spec);
  setLiveInteractive(active.id, state);
  const unregister = registerArtifactControl(active.id, (command) => {
    state = applyArtifactControl(spec, state, command);
    setLiveInteractive(active.id, state);
    return JSON.stringify(state);
  });
  const cue = registerCanvasGuide(active.id, async (command, change) => {
    expect(command).toMatchObject({ action: 'point', target: 'parameter:arrivalRate' });
    expect(change).toEqual({ parameter: 'arrivalRate', before: 4, after: 4.75, restarted: true });
    return 'shown';
  });
  const callbacks = canvasVoiceEvents({
    current,
    hold() {},
    send: { current: async () => '' },
    investigation: () => '{}',
    turn() {},
    error() {},
  });
  try {
    const result = await callbacks.controlArtifact!({
      action: 'set_parameter',
      activityId: active.id,
      parameter: 'arrivalRate',
      value: 4.75,
    });
    expect(JSON.parse(result)).toMatchObject({ arrivalRate: 4.75, simulation: { events: 0 } });
    expect(current.current.selectedActivityId).toBe(active.id);
    current.current = { ...current.current, selectedActivityId: 'different' };
    await expect(
      callbacks.controlArtifact!({
        action: 'set_parameter',
        activityId: active.id,
        parameter: 'arrivalRate',
        value: 5,
      }),
    ).rejects.toThrow('changed');
  } finally {
    unregister();
    cue();
    clearLiveInteractive(active.id);
  }
});

test('guidance accepts only bounded canvas anchors and rejects unavailable artifacts', async () => {
  expect(
    guidanceSchema.safeParse({
      action: 'point',
      activityId: 'a',
      target: 'plot',
      label: 'Notice the curve',
    }).success,
  ).toBe(true);
  expect(
    guidanceSchema.safeParse({
      action: 'point',
      activityId: 'a',
      target: 'body > input',
      label: 'Click',
      x: 1,
    }).success,
  ).toBe(false);
  expect(() => guideCanvas({ action: 'clear', activityId: 'missing' })).toThrow('not available');
});
