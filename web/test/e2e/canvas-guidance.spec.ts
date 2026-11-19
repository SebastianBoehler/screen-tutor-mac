import { test, expect, type Page, type Route } from '@playwright/test';
import { courseSetup } from './helpers';
import { voiceHarness, voiceTool, voiceEvent } from './voiceHarness';

function reply(route: Route, number: number) {
  const request = route.request().postDataJSON();
  const activity = {
    title: `Shared view ${number}`,
    concept: 'Linear function',
    body: '',
    question: 'Explain how slope changes the line.',
    choices: [],
    answer: '',
    hint: '',
    explanation: '',
    diagram: null,
    interactive: { kind: 'linear', slope: 1, intercept: 0 },
    sourceIds: [request.context.sources[0].id],
  };
  return route.fulfill({
    contentType: 'text/event-stream',
    body: `data: ${JSON.stringify({ choices: [{ delta: { content: JSON.stringify({ message: 'View prepared.', activity, assessment: { verdict: 'ungraded', feedback: '' }, memory: null }) } }] })}\n\ndata: [DONE]\n\n`,
  });
}
async function activeId(page: Page) {
  const raw = await voiceTool(page, 'inspect', 'inspect_activity', {});
  return JSON.parse(raw).activityId;
}

test('voice pointer and parameter animation use the same artifact, respect reduced motion and persist values', async ({
  page,
}, info) => {
  await voiceHarness(page);
  await page.route('**/api/tutor', (route) => reply(route, 1));
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  const view = page.getByRole('article', { name: 'Shared view 1', exact: true });
  await expect(view).toBeVisible();
  await page.getByRole('button', { name: 'Talk to tutor', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Listening', exact: true })).toBeVisible();
  const id = await activeId(page);
  const point = await voiceTool(page, 'point', 'guide_canvas', {
    action: 'point',
    activityId: id,
    target: 'plot',
    label: 'Watch the slope of this line',
  });
  expect(JSON.parse(point).target).toBe('plot');
  await expect(view.locator('.canvas-tutor-pointer')).toBeVisible();
  await view.getByRole('button', { name: 'Canvas view', exact: true }).click();
  await expect(view.locator('.canvas-cue')).toBeVisible();
  await view.getByRole('button', { name: 'Exit canvas view', exact: true }).click();
  const change = await voiceTool(page, 'change', 'control_artifact', {
    action: 'set_parameter',
    activityId: id,
    parameter: 'slope',
    value: 2,
  });
  expect(JSON.parse(change).state.slope).toBe(2);
  await expect(view.getByRole('slider', { name: 'Slope', exact: true })).toHaveValue('2');
  await expect(view.locator('.canvas-cue-label')).toContainText('1 → 2');
  await expect(view.locator('.teaching-plot')).toHaveClass(/canvas-change/);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await voiceTool(page, 'highlight', 'guide_canvas', {
    action: 'highlight',
    activityId: id,
    target: 'result',
    label: 'The updated equation stays here',
  });
  expect(
    await view
      .locator('.canvas-cue')
      .evaluate((element) => getComputedStyle(element).transitionDuration),
  ).toBe('0s');
  await expect(view.locator('.canvas-tutor-pointer')).toHaveCount(0);
  expect(await view.locator('input[type=range]').count()).toBe(2);
  await page.screenshot({ path: info.outputPath('shared-canvas-cue.png'), animations: 'disabled' });
  await voiceTool(page, 'clear', 'guide_canvas', {
    action: 'clear',
    activityId: id,
    target: null,
    label: null,
  });
  await expect(view.locator('.canvas-cue')).toHaveCount(0);
  await expect(page.locator('.save-status')).toHaveText('Saved locally');
  await page.reload();
  await view.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(view.getByRole('slider', { name: 'Slope', exact: true })).toHaveValue('2');
  await expect(view.locator('.canvas-cue')).toHaveCount(0);
});

test('background generation waits for a quiet pause, Hold view, and active student editing', async ({
  page,
}) => {
  await voiceHarness(page);
  let prepared: Route | undefined;
  let count = 0;
  await page.route('**/api/tutor', (route) => {
    count++;
    if (count === 1) return reply(route, 1);
    prepared = route;
  });
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  const first = page.getByRole('article', { name: 'Shared view 1', exact: true });
  await expect(first).toBeVisible();
  await page.getByRole('button', { name: 'Talk to tutor', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Listening', exact: true })).toBeVisible();
  await page.clock.install();
  const held = await voiceTool(page, 'hold', 'set_canvas_hold', { held: true });
  expect(JSON.parse(held).held).toBe(true);
  await expect(page.getByRole('button', { name: 'View held', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  const acknowledgement = await voiceTool(page, 'prepare', 'create_activity', {
    request: 'Show a new linear-function example.',
  });
  expect(acknowledgement).toContain('background');
  await expect.poll(() => !!prepared).toBe(true);
  const reasoning = first.getByRole('textbox', { name: 'Your answer or reasoning', exact: true });
  await expect(reasoning).toBeEnabled();
  await reasoning.fill('Keep this explanation while the tutor prepares the next view.');
  await reply(prepared!, 2);
  await expect(page.getByRole('button', { name: /Show prepared view/ })).toBeVisible();
  const next = page.getByRole('article', { name: 'Shared view 2', exact: true });
  await page.clock.fastForward(10_000);
  await expect(next).toHaveCount(0);
  await voiceEvent(page, { type: 'input_audio_buffer.speech_started' });
  await page.getByRole('button', { name: 'View held', exact: true }).click();
  await page.clock.fastForward(2000);
  await expect(next).toHaveCount(0);
  await voiceEvent(page, { type: 'input_audio_buffer.speech_stopped' });
  await reasoning.focus();
  await page.clock.fastForward(2000);
  await expect(next).toHaveCount(0);
  await first.getByRole('heading', { name: 'Shared view 1', exact: true }).click();
  await page.clock.fastForward(1400);
  await expect(next).toBeVisible();
  await expect(reasoning).toHaveValue(
    'Keep this explanation while the tutor prepares the next view.',
  );
});

test('held views remain queued after reload and can be opened explicitly', async ({ page }) => {
  let count = 0;
  await page.route('**/api/tutor', (route) => reply(route, ++count));
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  const first = page.getByRole('article', { name: 'Shared view 1', exact: true });
  await expect(first).toBeVisible();
  await page.getByRole('button', { name: 'Hold view', exact: true }).click();
  await page
    .getByRole('textbox', { name: 'Talk to your tutor', exact: true })
    .fill('Show a different example.');
  await page.getByRole('button', { name: 'Send to tutor', exact: true }).click();
  await expect(page.getByRole('button', { name: /Show prepared view/ })).toBeVisible();
  await expect(page.locator('.save-status')).toHaveText('Saved locally');
  await page.reload();
  await expect(page.getByRole('button', { name: 'View held', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expect(page.getByRole('article', { name: 'Shared view 2', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: /Show prepared view/ }).click();
  await expect(page.getByRole('article', { name: 'Shared view 2', exact: true })).toBeVisible();
  await expect(first).toBeAttached();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('background view survives selecting earlier work and remains accessible in canvas view', async ({
  page,
}) => {
  await voiceHarness(page);
  let count = 0;
  let pending: Route | undefined;
  await page.route('**/api/tutor', (route) => {
    count++;
    if (count < 3) return reply(route, count);
    pending = route;
  });
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  await page.getByRole('textbox', { name: 'Talk to your tutor' }).fill('Another view');
  await page.getByRole('button', { name: 'Send to tutor' }).click();
  const first = page.getByRole('article', { name: 'Shared view 1', exact: true });
  const second = page.getByRole('article', { name: 'Shared view 2', exact: true });
  await expect(second).toBeVisible();
  await page.getByRole('button', { name: 'Talk to tutor', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Listening', exact: true })).toBeVisible();
  await voiceTool(page, 'prepare-third', 'create_activity', { request: 'Prepare another view' });
  await expect.poll(() => !!pending).toBe(true);
  await first.getByRole('heading', { name: 'Shared view 1' }).click();
  await first.getByRole('button', { name: 'Expand', exact: true }).click();
  await first.getByRole('button', { name: 'Canvas view', exact: true }).click();
  await reply(pending!, 3);
  await expect(page.getByRole('button', { name: /Show prepared view/ })).toBeVisible();
  await page.getByRole('button', { name: /Show prepared view/ }).click();
  await expect(page.getByRole('article', { name: 'Shared view 3', exact: true })).toBeVisible();
});

test('a focused slider does not hold a prepared view indefinitely', async ({ page }) => {
  await voiceHarness(page);
  let count = 0;
  await page.route('**/api/tutor', (route) => reply(route, ++count));
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  const first = page.getByRole('article', { name: 'Shared view 1', exact: true });
  await first.getByRole('button', { name: 'Expand', exact: true }).click();
  await page.getByRole('button', { name: 'Talk to tutor', exact: true }).click();
  await page.clock.install();
  await first.getByRole('slider', { name: 'Slope' }).focus();
  await voiceTool(page, 'prepare-slider', 'create_activity', { request: 'Prepare a new view' });
  await expect(page.getByRole('button', { name: /Show prepared view/ })).toBeVisible();
  await page.clock.fastForward(10_000);
  await expect(page.getByRole('article', { name: 'Shared view 2', exact: true })).toBeVisible();
});

test('the real investigation comparison respects Hold view and supports tutor pointing', async ({
  page,
}) => {
  await voiceHarness(page);
  await courseSetup(page);
  await page.getByRole('button', { name: 'Guided investigation', exact: true }).click();
  await page.getByRole('button', { name: 'Talk to tutor', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Listening', exact: true })).toBeVisible();
  await voiceTool(page, 'hold', 'set_canvas_hold', { held: true });
  await voiceTool(page, 'explain', 'submit_investigation_response', {
    stage: 'explain',
    text: 'Below capacity should mean little waiting.',
  });
  await voiceTool(page, 'predict', 'submit_investigation_response', {
    stage: 'predict',
    text: 'More customers at 4.75 because there is less spare capacity.',
  });
  await expect(page.getByRole('button', { name: 'Show comparison', exact: true })).toBeVisible();
  await expect(page.getByText('Queue comparison', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Show comparison', exact: true }).click();
  const inspection = JSON.parse(await voiceTool(page, 'inspect', 'inspect_activity', {}));
  await voiceTool(page, 'point', 'guide_canvas', {
    action: 'point',
    activityId: inspection.activityId,
    target: 'plot',
    label: 'Compare how the two averages evolve',
  });
  await expect(page.locator('.canvas-tutor-pointer')).toBeVisible();
  await expect(
    page.getByRole('img', { name: 'Cumulative mean customers in the system' }),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: 'View held', exact: true })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
});
