import { expect, test } from 'bun:test';
import { applyArtifactControl, controlSchema } from '../../src/interactive/control';
import { initialInteractiveState } from '../../src/interactive/state';

test('flashcard reveal and formula changes validate the selected model and bounds', () => {
  const card = { kind: 'flashcard', front: 'Question?', back: 'Answer' } as const;
  const revealed = applyArtifactControl(card, initialInteractiveState(card), {
    action: 'reveal_flashcard',
    activityId: 'a',
  });
  expect(revealed).toMatchObject({ revealed: true, explored: true });
  const line = { kind: 'linear', slope: 1, intercept: 0 } as const;
  const state = initialInteractiveState(line);
  expect(
    applyArtifactControl(line, state, {
      action: 'set_parameter',
      activityId: 'a',
      parameter: 'slope',
      value: 2,
    }),
  ).toMatchObject({ slope: 2 });
  expect(() =>
    applyArtifactControl(line, state, {
      action: 'set_parameter',
      activityId: 'a',
      parameter: 'gamma',
      value: 2,
    }),
  ).toThrow('not available');
  expect(() =>
    applyArtifactControl(line, state, {
      action: 'set_parameter',
      activityId: 'a',
      parameter: 'slope',
      value: 6,
    }),
  ).toThrow('range');
  expect(
    controlSchema.safeParse({
      action: 'set_parameter',
      activityId: 'a',
      parameter: 'slope',
      value: 2,
      extra: true,
    }).success,
  ).toBe(false);
});
