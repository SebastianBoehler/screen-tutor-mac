import { describe, expect, test } from 'bun:test';
import { emptyWorkspace, type Activity, type Interaction } from '../../src/domain/models';
import { evidenceFor, isRestWindow, nextReview } from '../../src/domain/progress';
import { retrieve, studyContext } from '../../src/domain/retrieval';

const activity: Activity = {
  id: 'a',
  courseId: 'c',
  createdAt: '2026-11-18T12:00:00Z',
  mode: 'learn',
  title: 'A step',
  concept: 'Gradient',
  body: '',
  question: 'Why?',
  choices: [],
  answer: '',
  hint: '',
  explanation: '',
  diagram: null,
  interactive: null,
  sourceIds: [],
};
function event(
  kind: Interaction['kind'],
  assisted: boolean,
  verdict: Interaction['verdict'] = 'correct',
): Interaction {
  return {
    id: crypto.randomUUID(),
    courseId: 'c',
    activityId: 'a',
    at: '2026-11-18T12:00:00Z',
    kind,
    assisted,
    verdict,
    text: 'Because…',
  };
}
describe('evidence is distinct from completion', () => {
  test('reveals and assisted answers never count as independent checks', () => {
    const events = [event('reveal', true), event('attempt', true), event('attempt', false)];
    expect(evidenceFor('a', events).independent).toHaveLength(1);
    expect(evidenceFor('other', events).independent).toHaveLength(0);
    expect(nextReview(activity, [event('reveal', true)])).toBeNull();
  });
  test('an incorrect or assisted attempt schedules a short review', () => {
    expect(nextReview(activity, [event('attempt', false, 'incorrect')])?.toISOString()).toBe(
      '2026-11-19T12:00:00.000Z',
    );
    expect(nextReview(activity, [event('attempt', true)])?.toISOString()).toBe(
      '2026-11-19T12:00:00.000Z',
    );
  });
  test('overnight rest window handles both sides of midnight', () => {
    expect(isRestWindow(new Date(2026, 10, 18, 23), '22:00', '08:00')).toBe(true);
    expect(isRestWindow(new Date(2026, 10, 19, 7), '22:00', '08:00')).toBe(true);
    expect(isRestWindow(new Date(2026, 10, 19, 12), '22:00', '08:00')).toBe(false);
  });
  test('retrieval uses exact page IDs and never crosses courses', () => {
    const workspace = emptyWorkspace();
    workspace.selectedCourseId = 'c';
    workspace.courses = [{ id: 'c', name: 'Optimization', goal: 'Gradient descent', examDate: '' }];
    workspace.materials = ['c', 'other'].map((courseId, i) => ({
      id: `m${i}`,
      courseId,
      name: 'Lecture',
      hash: '',
      kind: 'document',
      createdAt: '',
      pages: [{ number: 4, text: 'Gradient descent subtracts a local gradient.' }],
    }));
    const context = studyContext(workspace, 'Gradient', 'learn');
    expect(context.sources).toHaveLength(1);
    expect(context.sources[0].id).toBe('m0:4:0');
    expect(retrieve([], 'Gradient')).toEqual([]);
  });
});
