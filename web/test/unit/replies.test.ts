import { expect, test } from 'bun:test';
import { applyReply } from '../../src/domain/applyReply';
import { emptyWorkspace, type Activity } from '../../src/domain/models';
import { nextReview } from '../../src/domain/progress';
import type { TutorReply } from '../../src/domain/schema';

const reply: TutorReply = {
  message: 'Check the direction of the derivative.',
  activity: null,
  assessment: { verdict: 'correct', feedback: 'The reasoning follows.' },
  memory: 'A hypothesis from this attempt.',
};
function fixture(mode: 'learn' | 'exam' = 'learn') {
  const value = emptyWorkspace();
  value.activities = [
    {
      id: 'a',
      courseId: 'c',
      mode,
      title: '',
      concept: '',
      body: '',
      question: '?',
      answer: '',
      hint: '',
      explanation: '',
      choices: [],
      diagram: null,
      interactive: null,
      sourceIds: [],
      createdAt: '',
    },
  ];
  value.interactions = [
    {
      id: 'attempt',
      activityId: 'a',
      courseId: 'c',
      kind: 'attempt',
      text: 'Reasoning',
      at: '2026-11-18T12:00:00Z',
      assisted: false,
      verdict: 'ungraded',
    },
  ];
  return value;
}
test('only the submitted attempt can receive a grade and ground a memory', () => {
  const original = fixture();
  expect(applyReply(original, reply, 'c').memories).toHaveLength(0);
  expect(applyReply(original, reply, 'c').interactions[0].verdict).toBe('ungraded');
  const result = applyReply(original, reply, 'c', 'attempt');
  expect(result.interactions[0].verdict).toBe('correct');
  expect(result.memories[0].evidenceId).toBe('attempt');
  expect(original.interactions[0].verdict).toBe('ungraded');
});
test('exam attempts stay ungraded even when the provider tries to grade them', () => {
  expect(applyReply(fixture('exam'), reply, 'c', 'attempt').interactions[0].verdict).toBe(
    'ungraded',
  );
});
test('repeated same-day correct answers cannot inflate the spacing interval', () => {
  const value = fixture();
  const attempts = Array.from({ length: 10 }, (_, i) => ({
    ...value.interactions[0],
    id: String(i),
    verdict: 'correct' as const,
  }));
  expect(nextReview(value.activities[0] as Activity, attempts)?.toISOString()).toBe(
    '2026-11-19T12:00:00.000Z',
  );
});
