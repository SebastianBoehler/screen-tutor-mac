import { describe, expect, test } from 'bun:test';
import { emptyWorkspace } from '../../src/domain/models';
import {
  openCanvasExample,
  prefillEmptyCanvas,
  saveExampleReasoning,
} from '../../src/domain/canvasExamples';
import { queueExampleId, exampleContent } from '../../src/domain/exampleContent';
import { activitySchema } from '../../src/domain/schema';
import { evidenceFor, nextReview } from '../../src/domain/progress';
import { studyContext } from '../../src/domain/retrieval';
import { initialInteractiveState } from '../../src/interactive/state';
import { stepQueue } from '../../src/interactive/queueEngine';

describe('illustrative queue example', () => {
  for (const example of exampleContent) {
    test(`${example.label} is valid, idempotent and never grades reasoning`, () => {
      const workspace = openCanvasExample(emptyWorkspace(), example.id);
      expect(activitySchema.safeParse(workspace.activities[0]).success).toBe(true);
      workspace.drafts[example.id] = 'My reasoning';
      const saved = saveExampleReasoning(workspace);
      const reopened = openCanvasExample(saved, example.id);
      expect(reopened.activities).toBe(saved.activities);
      expect(reopened.drafts).toBe(saved.drafts);
      expect(reopened.interactions).toBe(saved.interactions);
      expect(reopened.interactions.at(-1)).toMatchObject({ verdict: 'ungraded', assisted: true });
      expect(evidenceFor(example.id, reopened.interactions).independent).toHaveLength(0);
    });
  }
  test('prefills a valid, unlinked activity without inventing an exam date', () => {
    const workspace = prefillEmptyCanvas(emptyWorkspace());
    const activity = workspace.activities[0];
    expect(activitySchema.safeParse(activity).success).toBe(true);
    expect(activity.id).toBe(queueExampleId);
    expect(activity.sourceIds).toEqual([]);
    expect(workspace.courses[0].examDate).toBe('');
    expect(workspace.selectedActivityId).toBe(activity.id);
    expect(prefillEmptyCanvas(workspace)).toBe(workspace);
    expect(evidenceFor(activity.id, workspace.interactions).independent).toEqual([]);
  });

  test('reuses the course and preserves all existing work, including the example simulation', () => {
    const original = emptyWorkspace();
    original.courses = [
      { id: 'other', name: 'Other course', goal: 'Keep this goal', examDate: '2026-12-10' },
      { id: 'ms', name: 'Modellierung und Simulation', goal: 'My goal', examDate: '' },
    ];
    original.selectedCourseId = 'ms';
    original.drafts = { old: 'Unfinished reasoning' };
    original.interactiveStates = {
      old: initialInteractiveState({ kind: 'exponential', rate: 2, time: 1, unit: 'seconds' }),
    };
    const workspace = openCanvasExample(original);
    expect(workspace.courses).toBe(original.courses);
    expect(workspace.activities[0].courseId).toBe('ms');
    expect(workspace.materials).toBe(original.materials);
    expect(workspace.messages).toBe(original.messages);
    expect(workspace.memories).toBe(original.memories);
    expect(workspace.drafts).toBe(original.drafts);
    expect(workspace.interactiveStates).toBe(original.interactiveStates);
    const state = initialInteractiveState({ kind: 'queue', arrivalRate: 4.75, serviceRate: 5 });
    if (state.kind !== 'queue') throw new Error('Expected queue');
    state.simulation = stepQueue(state.simulation, state.arrivalRate, state.serviceRate);
    workspace.interactiveStates = { ...workspace.interactiveStates, [queueExampleId]: state };
    workspace.drafts = { ...workspace.drafts, [queueExampleId]: 'Less spare capacity.' };
    const reopened = openCanvasExample({
      ...workspace,
      selectedActivityId: null,
      selectedCourseId: 'other',
    });
    expect(reopened.activities).toBe(workspace.activities);
    expect(reopened.interactions).toBe(workspace.interactions);
    expect(reopened.drafts).toBe(workspace.drafts);
    expect(reopened.interactiveStates).toBe(workspace.interactiveStates);
    expect(reopened.selectedCourseId).toBe('ms');
    const context = studyContext(reopened, 'queue', 'learn');
    expect(context.assisted).toBe(true);
    expect(JSON.parse(context.exploration!)).toMatchObject({ arrivalRate: 4.75, events: 1 });
    const saved = saveExampleReasoning(reopened);
    expect(saved.interactions.at(-1)).toMatchObject({
      kind: 'attempt',
      verdict: 'ungraded',
      assisted: true,
    });
    expect(evidenceFor(queueExampleId, saved.interactions).independent).toEqual([]);
    expect(nextReview(saved.activities[0], saved.interactions)).toBeNull();
  });

  test('leaves an occupied canvas and its activity history untouched', () => {
    const workspace = openCanvasExample(emptyWorkspace());
    const other = {
      ...workspace.activities[0],
      id: 'existing-activity',
      title: 'Existing activity',
    };
    workspace.activities = [other];
    workspace.selectedActivityId = other.id;
    expect(prefillEmptyCanvas(workspace)).toBe(workspace);
    const opened = openCanvasExample(workspace);
    expect(opened.activities[0]).toBe(other);
    expect(opened.interactions.slice(0, workspace.interactions.length)).toEqual(
      workspace.interactions,
    );
    expect(opened.activities).toHaveLength(2);
  });
});
