import { expect, test } from 'bun:test';
import { emptyWorkspace } from '../../src/domain/models';
import { openCanvasExample } from '../../src/domain/canvasExamples';
import { applyReply } from '../../src/domain/applyReply';
import { canPresent, presentView, setCanvasHeld } from '../../src/canvas/pacing';
import type { TutorReply } from '../../src/domain/schema';

test('a prepared view preserves selection, drafts and models until presented exactly once', () => {
  const before = openCanvasExample(emptyWorkspace());
  const content = before.activities[0];
  const reply: TutorReply = {
    message: 'Prepared.',
    activity: content,
    assessment: { verdict: 'ungraded', feedback: '' },
    memory: null,
  };
  const queued = applyReply(before, reply, before.selectedCourseId!, undefined, 'defer');
  const id = queued.activities.at(-1)!.id;
  expect(queued.selectedActivityId).toBe(before.selectedActivityId);
  expect(queued.canvas?.pendingActivityIds).toEqual([id]);
  expect(queued.drafts).toBe(before.drafts);
  expect(queued.interactiveStates).toBe(before.interactiveStates);
  const shown = presentView(queued, id);
  expect(shown.selectedActivityId).toBe(id);
  expect(shown.canvas?.pendingActivityIds).toEqual([]);
  expect(presentView(shown, id)).toBe(shown);
  expect(presentView({ ...queued, selectedCourseId: 'other-course' }, id).selectedActivityId).toBe(
    before.selectedActivityId,
  );
});

test('Hold view defers even a normal reply, while quiet and dwell gates protect comprehension', () => {
  const before = setCanvasHeld(openCanvasExample(emptyWorkspace()), true);
  const reply: TutorReply = {
    message: 'Prepared.',
    activity: before.activities[0],
    assessment: { verdict: 'ungraded', feedback: '' },
    memory: null,
  };
  expect(applyReply(before, reply, before.selectedCourseId!).selectedActivityId).toBe(
    before.selectedActivityId,
  );
  const quiet = {
    held: false,
    speaking: false,
    interacting: false,
    visibleFor: 9000,
    quietFor: 2000,
  };
  expect(canPresent(quiet)).toBe(true);
  for (const change of [
    { held: true },
    { speaking: true },
    { interacting: true },
    { visibleFor: 1000 },
    { quietFor: 200 },
  ])
    expect(canPresent({ ...quiet, ...change })).toBe(false);
});

test('quiet-turn tracking handles learner interruptions and disconnects', async () => {
  const { SpeechTurns } = await import('../../src/canvas/turns');
  const states: boolean[] = [];
  const turns = new SpeechTurns((speaking) => states.push(speaking));
  turns.event('output_audio_buffer.started');
  turns.event('input_audio_buffer.speech_started');
  turns.event('output_audio_buffer.stopped');
  expect(states.at(-1)).toBe(true);
  turns.event('input_audio_buffer.speech_stopped');
  expect(states.at(-1)).toBe(false);
  turns.event('input_audio_buffer.speech_started');
  turns.reset();
  expect(states.at(-1)).toBe(false);
});

test('a guided comparison can be computed without showing its answer-bearing view yet', async () => {
  const { openInvestigation, submitInvestigation, updateExperiment } =
    await import('../../src/investigation/workspace');
  const { getInvestigation, presentedInvestigation, investigationContext, investigationId } =
    await import('../../src/investigation/model');
  const { queueView } = await import('../../src/canvas/pacing');
  const { runQueueComparison } = await import('../../src/investigation/experiment');
  let value = openInvestigation(emptyWorkspace());
  value = submitInvestigation(value, {
    stage: 'explain',
    text: 'Waiting may be small.',
    medium: 'voice',
  });
  value = submitInvestigation(value, {
    stage: 'predict',
    text: 'More customers with less spare capacity.',
    medium: 'voice',
  });
  value = updateExperiment(value, getInvestigation(value)!.experiment!.id, {
    status: 'ready',
    result: runQueueComparison(),
  });
  value = queueView(value, investigationId);
  expect(presentedInvestigation(value)?.stage).toBe('experiment');
  expect(JSON.parse(investigationContext(value)!).experiment.runs).toBeUndefined();
  expect(() =>
    submitInvestigation(value, {
      stage: 'revise',
      text: 'The comparison supports my prediction.',
      medium: 'voice',
    }),
  ).toThrow('not yet shown');
  value = presentView(value, investigationId);
  expect(presentedInvestigation(value)?.stage).toBe('revise');
  expect(JSON.parse(investigationContext(value)!).experiment.presented).toBe(true);
});
