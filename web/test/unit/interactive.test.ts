import { expect, test } from 'bun:test';
import { survivalProbability, gradientStep } from '../../src/interactive/mathematics';
import { createQueue, stepQueue, queueSummary } from '../../src/interactive/queueEngine';
import { interactiveSchema } from '../../src/interactive/schema';

test('exponential survival and gradient descent match their analytic definitions', () => {
  expect(survivalProbability(2, 0.5)).toBeCloseTo(Math.exp(-1), 12);
  expect(survivalProbability(3, 0)).toBe(1);
  expect(gradientStep(2, 0.05)).toBeCloseTo(1.8, 12);
  expect(gradientStep(2, 1.2) ** 2).toBeGreaterThan(2 ** 2);
  expect(gradientStep(2, 0.5)).toBe(0);
});

test('queue events conserve customers and simulation time never reverses', () => {
  let state = createQueue(4, 5);
  for (let i = 0; i < 2000; i++) {
    const next = stepQueue(state, 4, 5);
    expect(next.clock).toBeGreaterThanOrEqual(state.clock);
    expect(next.customers.length).toBe(next.arrived - next.completed);
    expect(next.areaNumber).toBeGreaterThanOrEqual(state.areaNumber);
    state = next;
  }
  expect(state.completed).toBeGreaterThan(0);
  expect(state.history.length).toBeLessThanOrEqual(160);
});

test('a departure accounts for system time and the area under N(t)', () => {
  const state = {
    ...createQueue(1, 2),
    clock: 0,
    nextArrival: 2,
    nextDeparture: 1,
    customers: [-1],
    arrived: 1,
    completed: 0,
    areaNumber: 0,
    totalSystemTime: 0,
  };
  const next = stepQueue(state, 1, 2);
  expect(next.clock).toBe(1);
  expect(next.lastEvent).toBe('departure');
  expect(next.customers).toEqual([]);
  expect(next.totalSystemTime).toBe(2);
  expect(next.areaNumber).toBe(1);
  expect(next.nextDeparture).toBeNull();
});

test('saved queue state resumes the same stochastic sequence', () => {
  let state = createQueue(2, 3);
  for (let i = 0; i < 30; i++) state = stepQueue(state, 2, 3);
  expect(stepQueue(JSON.parse(JSON.stringify(state)), 2, 3)).toEqual(stepQueue(state, 2, 3));
});

test('queue summaries distinguish finite-run observations from steady-state theory', () => {
  expect(queueSummary(createQueue(4, 5), 4, 5).theoreticalMeanNumber).toBe(4);
  expect(queueSummary(createQueue(5, 5), 5, 5).theoreticalMeanNumber).toBeNull();
  expect(queueSummary(createQueue(6, 5), 6, 5).theoreticalMeanNumber).toBeNull();
  expect(queueSummary(createQueue(4, 5), 4, 5).observedMeanTime).toBeNull();
});

test('interactive artifacts reject executable content and invalid model parameters', () => {
  expect(
    interactiveSchema.safeParse({ kind: 'queue', arrivalRate: 0, serviceRate: 5 }).success,
  ).toBe(false);
  expect(
    interactiveSchema.safeParse({ kind: 'javascript', code: 'fetch("/api/voice")' }).success,
  ).toBe(false);
  expect(
    interactiveSchema.safeParse({ kind: 'exponential', rate: 2, time: 0.5, unit: 'seconds' })
      .success,
  ).toBe(true);
});

test('live exploration context cannot be mistaken for a saved independent answer', async () => {
  const { emptyWorkspace } = await import('../../src/domain/models');
  const { studyContext } = await import('../../src/domain/retrieval');
  const { setLiveInteractive, clearLiveInteractive } = await import('../../src/interactive/state');
  const value = emptyWorkspace();
  value.selectedCourseId = 'c';
  value.selectedActivityId = 'a';
  value.courses = [{ id: 'c', name: 'Models', goal: '', examDate: '' }];
  value.activities = [
    {
      id: 'a',
      courseId: 'c',
      title: '',
      concept: '',
      body: '',
      question: '?',
      answer: '',
      hint: '',
      explanation: '',
      choices: [],
      diagram: null,
      interactive: { kind: 'exponential', rate: 2, time: 0.5, unit: 'seconds' },
      sourceIds: [],
      createdAt: '',
      mode: 'learn',
    },
  ];
  value.interactions = [
    {
      id: 'e',
      activityId: 'a',
      courseId: 'c',
      at: '',
      kind: 'explore',
      text: '',
      assisted: true,
      verdict: 'ungraded',
    },
  ];
  setLiveInteractive('a', { kind: 'exponential', rate: 3, time: 1, explored: true });
  const context = studyContext(value, '', 'learn');
  expect(JSON.parse(context.exploration!).rate).toBe(3);
  expect(context.assisted).toBe(true);
  clearLiveInteractive('a');
});

test('version-one workspaces preserve existing activities while gaining interactive state', async () => {
  const { emptyWorkspace } = await import('../../src/domain/models');
  const { migrateWorkspace } = await import('../../src/domain/migrations');
  const { interactiveStates: _, ...old } = emptyWorkspace();
  const legacyActivity = {
    id: 'old-activity',
    courseId: 'old-course',
    createdAt: '',
    mode: 'learn' as const,
    title: 'Existing recall',
    concept: 'A model',
    body: '',
    question: 'Why?',
    answer: 'Because',
    hint: '',
    explanation: '',
    choices: [],
    diagram: null,
    sourceIds: [],
  };
  const upgraded = migrateWorkspace({
    ...old,
    version: 1,
    activities: [legacyActivity],
    selectedActivityId: 'old-activity',
    drafts: { 'old-activity': 'My existing reasoning' },
  });
  expect(upgraded.version).toBe(2);
  expect(upgraded.interactiveStates).toEqual({});
  expect(upgraded.courses).toEqual(old.courses);
  expect(upgraded.activities[0].interactive).toBeNull();
  expect(upgraded.activities[0].title).toBe('Existing recall');
  expect(upgraded.drafts['old-activity']).toBe('My existing reasoning');
});

test('a long finite queue run agrees with the known stable M/M/1 averages', () => {
  let state = createQueue(4, 5);
  for (let i = 0; i < 100000; i++) state = stepQueue(state, 4, 5);
  const summary = queueSummary(state, 4, 5);
  expect(Math.abs(summary.observedMeanNumber! - 4)).toBeLessThan(0.15);
  expect(Math.abs(summary.observedMeanTime! - 1)).toBeLessThan(0.05);
});
