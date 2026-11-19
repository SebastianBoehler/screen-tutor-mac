import { test, expect, type Page } from '@playwright/test';
import { courseSetup, navigation } from './helpers';
import type { InteractiveSpec } from '../../src/interactive/schema';

async function prepare(page: Page, spec: InteractiveSpec) {
  await page.route('**/api/tutor', async (route) => {
    const request = route.request().postDataJSON();
    const attempt = request.messages.at(-1).content.startsWith('My attempt:');
    if (attempt) {
      expect(request.context.assisted).toBe(true);
      expect(JSON.parse(request.context.exploration).explored).toBe(true);
    }
    const reply = {
      message: attempt
        ? 'Now test the same idea in a different setting.'
        : 'Predict a change, then test it with the model.',
      activity: attempt
        ? null
        : {
            title:
              spec.kind === 'queue'
                ? 'What makes a queue grow?'
                : spec.kind === 'exponential'
                  ? 'How long until the next arrival?'
                  : 'When does a step overshoot?',
            concept: 'Interactive model',
            body: 'Change one parameter and explain what happens.',
            question: 'What changes when you increase the first parameter? Explain why.',
            choices: [],
            answer: 'Use the assumptions of the model to explain the observed change.',
            hint: 'Compare a single change with the initial settings.',
            explanation: '',
            diagram: null,
            interactive: spec,
            sourceIds: [request.context.sources[0].id],
          },
      assessment: { verdict: attempt ? 'correct' : 'ungraded', feedback: '' },
      memory: null,
    };
    await route.fulfill({
      contentType: 'text/event-stream',
      body: `data: ${JSON.stringify({ choices: [{ delta: { content: JSON.stringify(reply) } }] })}\n\ndata: [DONE]\n\n`,
    });
  });
  await courseSetup(page);
}

test('sliders update the curve, exploration is assisted, and values survive reload', async ({
  page,
}, info) => {
  await prepare(page, { kind: 'exponential', rate: 2, time: 0.5, unit: 'seconds' });
  await page.getByRole('button', { name: 'Start with a question' }).click();
  await expect(page.locator('.artifact-preview')).toContainText('chance of waiting');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  const rate = page.getByRole('slider', { name: 'Arrival rate λ (per s)' });
  await expect(rate).toHaveValue('2');
  await rate.focus();
  await rate.press('ArrowRight');
  await expect(rate).toHaveValue('2.1');
  const originalViewport = page.viewportSize()!;
  await page.setViewportSize({ width: 2000, height: 1000 });
  await page.getByRole('button', { name: 'Canvas view', exact: true }).click();
  await expect(page.locator('.topbar')).toBeVisible();
  await expect(page.locator('.sidebar')).toBeAttached();
  await expect(page.locator('.prediction')).toBeHidden();
  await expect(rate).toHaveValue('2.1');
  const canvasLayout = await page.evaluate(() => {
    const panel = document.querySelector('.main-content')!.getBoundingClientRect();
    const card = document.querySelector('.is-canvas-view')!;
    const cardBox = card.getBoundingClientRect();
    const composer = document.querySelector('.composer-dock')!.getBoundingClientRect();
    return {
      border: getComputedStyle(card).borderTopWidth,
      sameTop: Math.abs(panel.top - cardBox.top) < 2,
      sameWidth: Math.abs(panel.width - cardBox.width) < 20,
      contentWidth: card.querySelector('.artifact-content')!.getBoundingClientRect().width,
      overlaps: composer.top < panel.bottom && composer.bottom <= panel.bottom + 1,
    };
  });
  expect(canvasLayout).toMatchObject({
    border: '0px',
    sameTop: true,
    sameWidth: true,
    overlaps: true,
  });
  expect(canvasLayout.contentWidth).toBeGreaterThan(1400);
  await page.getByRole('button', { name: 'Exit canvas view', exact: true }).click();
  await page.setViewportSize(originalViewport);
  await expect(page.locator('.prediction')).toBeVisible();
  await expect(page.locator('.model-result')).toContainText('0.3499');
  await expect(page.getByText('Assisted practice', { exact: true })).toBeVisible();
  await page
    .getByRole('textbox', { name: 'Your answer or reasoning', exact: true })
    .fill('The survival probability falls because arrivals happen more often.');
  await page.getByRole('button', { name: 'Check my reasoning' }).click();
  await expect(page.getByText(/Assisted success/)).toBeVisible();
  await expect(page.getByText(/Successful independent check/)).toHaveCount(0);
  await navigation(page, 'Materials');
  await navigation(page, 'Study');
  await page.reload();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(page.getByRole('slider', { name: 'Arrival rate λ (per s)' })).toHaveValue('2.1');
  await expect(page.getByText('Your turn', { exact: true })).toHaveCount(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({
    path: info.outputPath('exponential-explorer.png'),
    animations: 'disabled',
  });
  await page.locator('.interactive-artifact').screenshot({
    path: info.outputPath('exponential-explorer-detail.png'),
    animations: 'disabled',
  });
});

test('queue simulation steps, plays, pauses and distinguishes an unstable system', async ({
  page,
}, info) => {
  await prepare(page, { kind: 'queue', arrivalRate: 4, serviceRate: 5 });
  await page.getByRole('button', { name: 'Start with a question' }).click();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(page.locator('.model-result')).toContainText('Event 0');
  await page.getByRole('button', { name: 'Step event', exact: true }).click();
  await expect(page.locator('.model-result')).toContainText('Event 1');
  await page.getByRole('button', { name: 'Play simulation', exact: true }).click();
  await expect
    .poll(async () =>
      Number((await page.locator('.model-result strong').first().textContent()) ?? 0),
    )
    .toBeGreaterThan(7);
  await page.getByRole('button', { name: 'Pause simulation', exact: true }).click();
  const stopped = await page.locator('.model-result').textContent();
  await page.waitForTimeout(350);
  await expect(page.locator('.model-result')).toHaveText(stopped!);
  await page.screenshot({ path: info.outputPath('queue-simulation.png'), animations: 'disabled' });
  await page
    .locator('.interactive-artifact')
    .screenshot({ path: info.outputPath('queue-simulation-detail.png'), animations: 'disabled' });
  const rate = page.getByRole('slider', { name: 'Arrival rate λ (per min)' });
  await rate.focus();
  await rate.press('End');
  await expect(rate).toHaveValue('20');
  await expect(page.locator('.model-result')).toContainText('Event 0');
  await expect(page.locator('.model-comparison')).toContainText('no finite mean');
  await expect(page.locator('.model-note[role=status]')).toContainText(
    'no stationary distribution',
  );
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('gradient steps respond to learning rate and remain stable across viewport changes', async ({
  page,
}, info) => {
  await prepare(page, { kind: 'gradient-descent', position: 2, learningRate: 0.05 });
  await page.getByRole('button', { name: 'Start with a question' }).click();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await page.getByRole('button', { name: 'Take one step', exact: true }).click();
  await expect(page.locator('.model-actions output')).toContainText('x = 1.800');
  const rate = page.getByRole('slider', { name: 'Learning rate η' });
  await rate.focus();
  await rate.press('End');
  await page.getByRole('button', { name: 'Take one step', exact: true }).click();
  await expect(page.locator('.model-actions output')).toContainText('x = -2.520');
  if (info.project.use.hasTouch) {
    const box = await rate.boundingBox();
    await rate.tap({ position: { x: box!.width / 2, y: box!.height / 2 } });
    await expect(rate).not.toHaveValue('1.2');
  }
  const original = page.viewportSize()!;
  await page.setViewportSize({ width: 360, height: 800 });
  await expect(page.locator('.model-actions output')).toContainText('loss = 6.350');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.setViewportSize(original);
  await page.screenshot({ path: info.outputPath('gradient-explorer.png'), animations: 'disabled' });
  await page
    .locator('.interactive-artifact')
    .screenshot({ path: info.outputPath('gradient-explorer-detail.png'), animations: 'disabled' });
});

test('an exam exploration requires an explicit transition to assisted practice', async ({
  page,
}) => {
  await prepare(page, { kind: 'queue', arrivalRate: 4, serviceRate: 5 });
  await page.getByRole('button', { name: 'Practice exam', exact: true }).click();
  await expect(page.getByText('Unaided practice', { exact: true })).toBeVisible();
  await expect(page.getByRole('slider')).toHaveCount(0);
  await page.getByRole('button', { name: 'Open exploration (assisted)', exact: true }).click();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(page.getByRole('slider')).toHaveCount(2);
  await expect(page.getByText('Practice exam · assisted', { exact: true })).toBeVisible();
});
