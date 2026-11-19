import { test, expect } from '@playwright/test';
import { navigation } from './helpers';

test('empty canvas opens an offline example and preserves its work across reload and reopening', async ({
  page,
}) => {
  let tutorRequests = 0;
  await page.route('**/api/status', (route) =>
    route.fulfill({ json: { openai: false, openrouter: false } }),
  );
  await page.route('**/api/tutor', (route) => {
    tutorRequests++;
    return route.abort();
  });
  await page.goto('/');
  await expect(
    page.getByRole('heading', { name: 'Why do queues grow near capacity?' }),
  ).toBeVisible();
  await expect(page.getByText(/Illustrative example/)).toBeVisible();
  await expect(page.getByText('Assisted practice', { exact: true })).toBeVisible();
  await expect(page.getByRole('slider')).toHaveCount(0);
  expect((await page.locator('.interactive-artifact').boundingBox())!.height).toBeLessThan(230);
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  const arrival = page.getByRole('slider', { name: 'Arrival rate λ (per min)' });
  await expect(arrival).toHaveValue('4');
  await arrival.focus();
  await arrival.press('ArrowRight');
  await expect(arrival).toHaveValue('4.25');
  await page.getByRole('button', { name: 'Step event', exact: true }).click();
  await expect(page.locator('.model-result')).toContainText('Event 1');
  const reasoning = page.getByRole('textbox', { name: 'Your answer or reasoning', exact: true });
  await reasoning.fill('Random arrivals leave less time to clear the queue as capacity fills.');
  await page.getByRole('button', { name: 'Save my reasoning', exact: true }).click();
  await expect(
    page.getByRole('status').filter({ hasText: 'Reasoning saved locally' }),
  ).toBeVisible();
  await expect(page.locator('.save-status')).toHaveText('Saved locally');
  await page.reload();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(arrival).toHaveValue('4.25');
  await expect(page.locator('.model-result')).toContainText('Event 1');
  await expect(reasoning).toHaveValue(/Random arrivals/);
  await page.getByRole('button', { name: 'Queue example', exact: true }).click();
  await page.getByRole('button', { name: 'Queue example', exact: true }).click();
  await expect(arrival).toHaveValue('4.25');
  await expect(page.locator('.model-result')).toContainText('Event 1');
  await expect(reasoning).toHaveValue(/Random arrivals/);
  await page.getByRole('button', { name: 'Collapse', exact: true }).click();
  await expect(page.getByRole('slider')).toHaveCount(0);
  await expect(page.locator('.artifact-preview')).toContainText('Event 1');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(arrival).toHaveValue('4.25');
  await expect(page.locator('.model-result')).toContainText('Event 1');
  await expect(page.locator('details')).toHaveCount(0);
  await navigation(page, 'Study');
  const open = page.getByRole('button', { name: 'Open navigation', exact: true });
  if (await open.isVisible()) await open.click();
  await expect(
    page.getByRole('navigation', { name: 'Saved activities' }).getByRole('button'),
  ).toHaveCount(1);
  await expect(page.getByRole('navigation', { name: 'Courses' }).getByRole('button')).toHaveCount(
    1,
  );
  if (await open.isVisible())
    await page
      .getByRole('navigation', { name: 'Workspace', exact: true })
      .getByRole('button', { name: 'Study', exact: true })
      .click();
  expect(tutorRequests).toBe(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('examples demonstrate supported rich displays and keep separate drafts and simulation state', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.route('**/api/status', (route) =>
    route.fulfill({ json: { openai: false, openrouter: false } }),
  );
  await page.goto('/');
  const choose = async (name: string) => {
    await page.getByRole('button', { name: 'Examples', exact: true }).click();
    await page
      .getByRole('dialog', { name: 'Canvas examples' })
      .getByRole('button', { name, exact: false })
      .click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
  };
  await choose('Probability curve');
  await expect(page.getByRole('img', { name: 'Exponential survival curve preview' })).toBeVisible();
  const reasoning = page.getByRole('textbox', { name: 'Your answer or reasoning', exact: true });
  await reasoning.fill('More frequent arrivals reduce the chance of a long wait.');
  await page.getByRole('button', { name: 'Save my reasoning', exact: true }).click();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  const rate = page.getByRole('slider', { name: 'Arrival rate λ (per min)' });
  await rate.focus();
  await rate.press('ArrowRight');
  await expect(rate).toHaveValue('2.1');
  await page.getByRole('button', { name: 'Collapse', exact: true }).click();
  await choose('Gradient descent');
  await expect(page.getByRole('img', { name: 'Quadratic loss curve preview' })).toBeVisible();
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await page.getByRole('button', { name: 'Take one step', exact: true }).click();
  await expect(page.locator('.model-actions output')).toContainText('x = 1.600');
  await page.getByRole('button', { name: 'Collapse', exact: true }).click();
  await expect(page.locator('.artifact-preview')).toContainText('x = 1.600');
  await choose('Process diagram');
  await expect(page.locator('.preview-process')).toContainText('Validation');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(page.getByRole('figure', { name: 'Concept mechanism' })).toBeVisible();
  await expect(page.locator('.mechanism-node')).toHaveCount(3);
  await choose('Math & table');
  await expect(page.locator('.katex-display')).toBeVisible();
  await expect(page.getByRole('table')).toBeVisible();
  await expect(page.getByRole('row')).toHaveCount(4);
  await expect(page.locator('details')).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('math-and-table.png'), animations: 'disabled' });
  await choose('Probability curve');
  await expect(reasoning).toHaveValue('More frequent arrivals reduce the chance of a long wait.');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(rate).toHaveValue('2.1');
  await page.reload();
  await expect(
    page.getByRole('heading', { name: 'How long until the next arrival?' }),
  ).toBeVisible();
  await expect(reasoning).toHaveValue('More frequent arrivals reduce the chance of a long wait.');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(rate).toHaveValue('2.1');
  await page.getByRole('button', { name: 'Queue example', exact: true }).click();
  await expect(
    page.getByRole('heading', { name: 'Why do queues grow near capacity?' }),
  ).toBeVisible();
  await page.screenshot({ path: info.outputPath('compact-queue.png'), animations: 'disabled' });
  const open = page.getByRole('button', { name: 'Open navigation', exact: true });
  if (await open.isVisible()) await open.click();
  await expect(
    page.getByRole('navigation', { name: 'Saved activities' }).getByRole('button'),
  ).toHaveCount(5);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
