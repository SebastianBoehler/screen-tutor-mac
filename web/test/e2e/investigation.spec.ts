import { test, expect, type Page, type Route } from '@playwright/test';
import { readFile } from 'node:fs/promises';

async function saved(page: Page) {
  await expect(page.locator('.save-status')).toHaveText('Saved locally');
}
async function snapshot(page: Page) {
  const downloading = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export learning workspace' }).click();
  const download = await downloading;
  return JSON.parse(await readFile((await download.path())!, 'utf8'));
}
async function explainAndPredict(page: Page) {
  await page.getByRole('button', { name: 'Guided investigation', exact: true }).click();
  await page
    .getByRole('textbox', { name: 'Your reasoning', exact: true })
    .fill('Below capacity should leave enough time to clear demand.');
  await page.getByRole('button', { name: 'Save and predict', exact: true }).click();
  await page
    .getByRole('textbox', { name: 'Your reasoning', exact: true })
    .fill('The system at 4.75 will have more customers because less spare capacity remains.');
  await page.getByRole('button', { name: 'Save prediction and run', exact: true }).click();
}

test('real offline investigation preserves old work, reloads stages, and records one fresh choice', async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  let tutorRequests = 0;
  await page.route('**/api/tutor', (route) => {
    tutorRequests++;
    return route.abort();
  });
  await page.goto('/');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await page.getByRole('button', { name: 'Step event', exact: true }).click();
  await page
    .getByRole('textbox', { name: 'Your answer or reasoning', exact: true })
    .fill('Keep my existing queue reasoning.');
  await page.getByRole('button', { name: 'Guided investigation', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Talk to tutor', exact: true })).toBeEnabled();
  await expect(page.getByText('Queue comparison', { exact: true })).toHaveCount(0);
  await page
    .getByRole('textbox', { name: 'Your reasoning', exact: true })
    .fill('My unfinished initial explanation.');
  await saved(page);
  await page.reload();
  await expect(page.getByRole('textbox', { name: 'Your reasoning', exact: true })).toHaveValue(
    'My unfinished initial explanation.',
  );
  await explainAndPredict(page);
  await expect(page.getByText('Queue comparison', { exact: true })).toBeVisible();
  await expect(
    page.getByRole('img', { name: 'Cumulative mean customers in the system' }),
  ).toHaveCount(0);
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(
    page.getByRole('img', { name: 'Cumulative mean customers in the system' }),
  ).toBeVisible();
  await expect(page.getByRole('table')).toContainText('19.00');
  await page.getByRole('button', { name: 'Canvas view', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Exit canvas view', exact: true })).toBeVisible();
  await expect(page.locator('.investigation-question')).toBeHidden();
  await page.getByRole('button', { name: 'Exit canvas view', exact: true }).click();
  await expect(page.locator('.investigation-question')).toBeVisible();
  await page.screenshot({
    path: info.outputPath('investigation-comparison.png'),
    animations: 'disabled',
  });
  await saved(page);
  const beforeReload = await snapshot(page);
  await page.reload();
  await expect(page.getByText('Queue comparison', { exact: true })).toBeVisible();
  const afterReload = await snapshot(page);
  expect(afterReload.investigations).toEqual(beforeReload.investigations);
  await page
    .getByRole('textbox', { name: 'Your reasoning', exact: true })
    .fill('Less spare capacity lets bursts persist. One finite run is not the steady-state mean.');
  await page
    .getByRole('button', { name: 'Save revision and try a fresh question', exact: true })
    .click();
  await expect(
    page.getByRole('heading', { name: 'Apply it: demand beyond capacity', exact: true }),
  ).toBeVisible();
  await expect(page.getByText('Queue comparison', { exact: true })).toHaveCount(0);
  await page.getByRole('radio', { name: 'No', exact: true }).check();
  await page
    .getByRole('textbox', { name: 'Explain your answer', exact: true })
    .fill('Demand exceeds service capacity, so the backlog cannot settle.');
  await page.getByRole('button', { name: 'Check my choice', exact: true }).click();
  await expect(page.getByText('Choice correct.', { exact: true })).toBeVisible();
  await expect(
    page.getByText(/Explanation saved, not assessed. Retention not checked/),
  ).toBeVisible();
  await saved(page);
  await page.reload();
  await page.getByRole('button', { name: 'Guided investigation', exact: true }).click();
  await page.getByRole('button', { name: 'Guided investigation', exact: true }).click();
  const value = await snapshot(page);
  expect(
    value.activities.filter((item: { id: string }) => item.id.startsWith('guided-mm1')),
  ).toHaveLength(2);
  expect(
    value.interactions.filter(
      (item: { kind: string; activityId: string }) =>
        item.kind === 'attempt' && item.activityId === 'guided-mm1-investigation:application',
    ),
  ).toMatchObject([{ verdict: 'correct', assisted: false }]);
  expect(value.courses).toHaveLength(1);
  await page.getByRole('button', { name: 'Queue example', exact: true }).click();
  await expect(
    page.getByRole('textbox', { name: 'Your answer or reasoning', exact: true }),
  ).toHaveValue('Keep my existing queue reasoning.');
  await page.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(page.locator('.model-result')).toContainText('Event 1');
  expect(tutorRequests).toBe(0);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('cancelling and reloading a worker preserves prediction; retry runs and hints mark assistance', async ({
  page,
}) => {
  let blocked: Route | undefined;
  let workerRequests = 0;
  await page.route('**/experiment.worker.ts*', (route) => {
    workerRequests++;
    if (workerRequests === 1) {
      blocked = route;
      return;
    }
    return route.continue();
  });
  await page.goto('/');
  await explainAndPredict(page);
  await expect(page.getByRole('button', { name: 'Cancel experiment', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Cancel experiment', exact: true }).click();
  await blocked?.abort().catch(() => {});
  await expect(page.getByText('Experiment cancelled. Your prediction is saved.')).toBeVisible();
  await saved(page);
  await page.reload();
  await expect(page.getByText('Experiment cancelled. Your prediction is saved.')).toBeVisible();
  await page.getByRole('button', { name: 'Retry experiment', exact: true }).click();
  await expect(page.getByText('Queue comparison', { exact: true })).toBeVisible();
  await page
    .getByRole('textbox', { name: 'Your reasoning', exact: true })
    .fill('I revised my view after comparing the two queues.');
  await page
    .getByRole('button', { name: 'Save revision and try a fresh question', exact: true })
    .click();
  await page.getByRole('button', { name: 'Get a hint', exact: true }).click();
  await page.getByRole('radio', { name: 'Yes', exact: true }).check();
  await page
    .getByRole('textbox', { name: 'Explain your answer', exact: true })
    .fill('I think a finite mean is possible.');
  await page.getByRole('button', { name: 'Check my choice', exact: true }).click();
  await expect(page.getByText('Choice incorrect.', { exact: true })).toBeVisible();
  const value = await snapshot(page);
  expect(value.interactions.at(-1)).toMatchObject({ verdict: 'incorrect', assisted: true });
  expect(value.investigations['guided-mm1-investigation'].responses.predict.text).toContain('4.75');
});

test('reload resumes running work and a late result leaves the selected canvas alone', async ({
  page,
}) => {
  const requests: Route[] = [];
  await page.route('**/experiment.worker.ts*', (route) => {
    requests.push(route);
  });
  await page.goto('/');
  await explainAndPredict(page);
  await expect.poll(() => requests.length).toBe(1);
  await saved(page);
  const queued = await snapshot(page);
  await page.reload();
  await expect.poll(() => requests.length).toBe(2);
  await expect(page.getByRole('button', { name: 'Cancel experiment', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Queue example', exact: true }).click();
  await requests[0].abort().catch(() => {});
  await requests[1].continue();
  await expect
    .poll(async () => (await snapshot(page)).investigations['guided-mm1-investigation'].stage)
    .toBe('revise');
  await expect(
    page.getByRole('heading', { name: 'Why do queues grow near capacity?', exact: true }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Guided investigation', exact: true }).click();
  await expect(page.getByText('Queue comparison', { exact: true })).toBeVisible();
  const completed = await snapshot(page);
  expect(completed.investigations['guided-mm1-investigation'].experiment.id).toBe(
    queued.investigations['guided-mm1-investigation'].experiment.id,
  );
});
