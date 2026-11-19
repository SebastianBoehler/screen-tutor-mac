import { expect, test } from 'bun:test';
import { emptyWorkspace } from '../../src/domain/models';
import {
  openInvestigation,
  submitInvestigation,
  updateExperiment,
  giveInvestigationHint,
} from '../../src/investigation/workspace';
import { getInvestigation, investigationId, applicationId } from '../../src/investigation/model';
import { runQueueComparison } from '../../src/investigation/experiment';
import { evidenceFor } from '../../src/domain/progress';

function predict() {
  let value = openInvestigation(emptyWorkspace());
  value = submitInvestigation(value, {
    stage: 'explain',
    text: 'Being below capacity should be enough.',
    medium: 'text',
  });
  return submitInvestigation(value, {
    stage: 'predict',
    text: 'The second queue will take longer to clear.',
    medium: 'text',
  });
}

test('preserves existing work and requires explanation and prediction before any experiment', () => {
  const before = emptyWorkspace();
  before.drafts.old = 'Do not replace';
  const value = openInvestigation(before);
  expect(value.drafts).toBe(before.drafts);
  expect(getInvestigation(value)?.stage).toBe('explain');
  expect(getInvestigation(value)?.experiment).toBeNull();
  expect(openInvestigation(value).activities).toBe(value.activities);
  expect(() =>
    submitInvestigation(value, { stage: 'predict', text: 'Skip', medium: 'voice' }),
  ).toThrow();
  expect(() =>
    submitInvestigation(value, { stage: 'explain', text: ' ', medium: 'text' }),
  ).toThrow();
});

test('runs reproducible real comparisons over the same horizon, with theory kept separate', () => {
  const comparison = runQueueComparison();
  expect(runQueueComparison()).toEqual(comparison);
  expect(comparison.runs.map((run) => run.arrivalRate)).toEqual([4, 4.75]);
  for (const run of comparison.runs) {
    expect(run.time).toBe(200);
    expect(run.serviceRate).toBe(5);
    expect(run.events).toBeGreaterThan(1000);
    expect(run.completed).toBeGreaterThan(0);
    expect(run.observedMeanNumber).toBeGreaterThan(0);
    expect(run.points.at(-1)?.x).toBe(200);
  }
  expect(comparison.runs.map((run) => run.theoreticalMeanNumber)).toEqual([4, 19]);
});

test('rejects stale results, records a separate fresh choice check, and never grades the explanation', () => {
  let value = predict();
  const job = getInvestigation(value)!.experiment!;
  expect(
    updateExperiment(value, 'obsolete', { status: 'ready', result: runQueueComparison() }),
  ).toBe(value);
  value = updateExperiment(value, job.id, { status: 'running' });
  value = updateExperiment(value, job.id, { status: 'ready', result: runQueueComparison() });
  expect(getInvestigation(value)?.stage).toBe('revise');
  value = submitInvestigation(value, {
    stage: 'revise',
    text: 'Spare capacity matters; bursts persist.',
    medium: 'voice',
  });
  expect(value.selectedActivityId).toBe(applicationId);
  expect(value.activities.find((a) => a.id === applicationId)?.interactive).toBeNull();
  value = submitInvestigation(value, {
    stage: 'apply',
    text: 'Arrivals exceed capacity.',
    choice: 'no',
    medium: 'voice',
  });
  expect(getInvestigation(value)?.stage).toBe('complete');
  expect(value.interactions.at(-1)).toMatchObject({
    activityId: applicationId,
    verdict: 'correct',
    assisted: false,
  });
  expect(evidenceFor(applicationId, value.interactions).independent).toHaveLength(1);
  expect(evidenceFor(investigationId, value.interactions).independent).toHaveLength(0);
  expect(getInvestigation(value)?.responses.apply?.text).toBe('Arrivals exceed capacity.');
});

test('an explicit hint marks the new application assisted and cancellation rejects late completion', () => {
  let value = predict();
  const job = getInvestigation(value)!.experiment!;
  value = updateExperiment(value, job.id, { status: 'cancelled' });
  expect(updateExperiment(value, job.id, { status: 'ready', result: runQueueComparison() })).toBe(
    value,
  );
  value = updateExperiment(value, job.id, { status: 'queued' });
  expect(updateExperiment(value, job.id, { status: 'ready', result: runQueueComparison() })).toBe(
    value,
  );
  value = updateExperiment(value, getInvestigation(value)!.experiment!.id, {
    status: 'ready',
    result: runQueueComparison(),
  });
  value = submitInvestigation(value, {
    stage: 'revise',
    text: 'Less spare capacity.',
    medium: 'text',
  });
  value = giveInvestigationHint(value);
  value = submitInvestigation(value, {
    stage: 'apply',
    text: 'No capacity to clear demand.',
    choice: 'no',
    medium: 'text',
  });
  expect(evidenceFor(applicationId, value.interactions).independent).toHaveLength(0);
  expect(value.interactions.at(-1)?.assisted).toBe(true);
});

test('version two migration preserves all existing collections and in-progress model state', async () => {
  const { migrateWorkspace } = await import('../../src/domain/migrations');
  const { openCanvasExample } = await import('../../src/domain/canvasExamples');
  const { investigations: _, ...previous } = openCanvasExample(emptyWorkspace());
  const legacy = { ...previous, version: 2 as const };
  const migrated = migrateWorkspace(legacy);
  expect(migrated.version).toBe(3);
  expect(migrated.investigations).toEqual({});
  const opened = openInvestigation(migrated);
  for (const key of [
    'materials',
    'drafts',
    'interactiveStates',
    'messages',
    'memories',
    'settings',
  ] as const)
    expect(opened[key]).toBe(legacy[key]);
  expect(opened.activities.slice(0, legacy.activities.length)).toEqual(legacy.activities);
  expect(opened.courses).toBe(legacy.courses);
});

test('inspection exposes stage and real results only after prediction, within the context limit', async () => {
  const { studyContext } = await import('../../src/domain/retrieval');
  let value = openInvestigation(emptyWorkspace());
  expect(JSON.parse(studyContext(value, '', 'learn').exploration!).experiment).toBeNull();
  value = predict();
  const queued = JSON.parse(studyContext(value, '', 'learn').exploration!);
  expect(queued.experiment.status).toBe('queued');
  expect(studyContext(value, '', 'learn').activity?.question).toContain(
    'Two runs are being compared',
  );
  expect(queued.experiment.runs).toBeUndefined();
  value = updateExperiment(value, getInvestigation(value)!.experiment!.id, {
    status: 'ready',
    result: runQueueComparison(),
  });
  const context = studyContext(value, '', 'learn');
  expect(context.exploration!.length).toBeLessThanOrEqual(2400);
  expect(JSON.parse(context.exploration!).experiment.runs).toHaveLength(2);
  const otherCanvas = { ...value, selectedActivityId: null };
  expect(studyContext(otherCanvas, '', 'learn').exploration).toBeNull();
});

test('voice context fits the schema even when long explanations contain escaped characters', async () => {
  const { studyContext } = await import('../../src/domain/retrieval');
  const { contextSchema } = await import('../../src/domain/schema');
  let value = openInvestigation(emptyWorkspace());
  const text = '\\'.repeat(1200);
  value = submitInvestigation(value, { stage: 'explain', text, medium: 'text' });
  value = submitInvestigation(value, { stage: 'predict', text, medium: 'text' });
  value = updateExperiment(value, getInvestigation(value)!.experiment!.id, {
    status: 'ready',
    result: runQueueComparison(),
  });
  value = submitInvestigation(value, { stage: 'revise', text, medium: 'text' });
  value.drafts[`${investigationId}:apply`] = text;
  expect(contextSchema.safeParse(studyContext(value, '', 'learn')).success).toBe(true);
  value = submitInvestigation(value, { stage: 'apply', text, choice: 'no', medium: 'text' });
  expect(contextSchema.safeParse(studyContext(value, '', 'learn')).success).toBe(true);
  expect(
    openInvestigation({ ...value, selectedActivityId: investigationId }).selectedActivityId,
  ).toBe(applicationId);
  expect(() =>
    submitInvestigation(value, { stage: 'apply', text, choice: 'no', medium: 'text' }),
  ).toThrow();
});
