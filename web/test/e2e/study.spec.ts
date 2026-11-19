import { test, expect } from '@playwright/test';
import { courseSetup, navigation } from './helpers';

const activity = {
  title: 'What makes a model useful?',
  interactive: null,
  concept: 'Model validation',
  body: 'A model simplifies a system for a particular purpose. Its usefulness depends on that purpose.\n\n$$e = y - \\hat{y}$$',
  question:
    'A simulator matches its specification, but its predictions do not match measurements. Which check is missing?',
  choices: [],
  answer: 'Validation against the real system.',
  hint: 'Distinguish the implementation from its intended real-world use.',
  explanation:
    'Verification checks implementation against specification; validation checks fitness for purpose.',
  diagram: {
    nodes: [
      { label: 'Real system', detail: 'Measurements and intended use' },
      { label: 'Conceptual model', detail: 'Purposeful abstraction' },
    ],
    links: [{ from: 0, to: 1, label: 'Compare against observations' }],
  },
  sourceIds: [],
};
test('source → activity → attempt → memory → reveal → review survives reload', async ({
  page,
}, testInfo) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.route('**/api/tutor', async (route) => {
    const request = route.request().postDataJSON();
    expect(request.context.course).toBe('Modellierung und Simulation');
    expect(request.context.sources[0].text).toContain('purposeful abstraction');
    const isAttempt = request.messages.at(-1).content.startsWith('My attempt:');
    const reply = {
      message: isAttempt
        ? 'You distinguished model suitability from implementation correctness.'
        : 'Try distinguishing the model from the system it represents.',
      activity: isAttempt ? null : { ...activity, sourceIds: [request.context.sources[0].id] },
      assessment: { verdict: isAttempt ? 'correct' : 'ungraded', feedback: '' },
      memory: isAttempt
        ? 'The learner distinguishes validation from implementation verification in this example; test transfer next.'
        : null,
    };
    const content = JSON.stringify(reply);
    const frames = [content.slice(0, 75), content.slice(75)]
      .map((chunk) => `data: ${JSON.stringify({ choices: [{ delta: { content: chunk } }] })}\n\n`)
      .join('');
    await route.fulfill({
      contentType: 'text/event-stream',
      body: frames + 'data: [DONE]\n\n',
    });
  });
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  await expect(page.getByRole('heading', { name: activity.title })).toBeVisible();
  await expect(page.getByText(activity.answer, { exact: true })).toHaveCount(0);
  await expect(page.locator('.katex')).toBeVisible();
  await page
    .getByRole('textbox', { name: 'Your answer or reasoning' })
    .fill('Validation: compare predictions with observations of the real system.');
  await page.getByRole('button', { name: 'Check my reasoning' }).click();
  await expect(page.getByText(/Successful independent check/)).toBeVisible();
  await navigation(page, 'Memory');
  await expect(page.getByText(/The learner distinguishes validation/)).toBeVisible();
  await navigation(page, 'Study');
  await page.getByRole('button', { name: 'A small hint' }).click();
  await expect(page.getByText(activity.hint, { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Reveal answer', exact: true }).click();
  await expect(page.getByText(activity.answer, { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByRole('heading', { name: activity.title })).toBeVisible();
  await expect(page.getByText(activity.answer, { exact: true })).toBeVisible();
  await navigation(page, 'Plan');
  await expect(page.getByRole('heading', { name: 'Your next reviews' })).toBeVisible();
  await expect(page.getByText('Model validation', { exact: true })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  expect(errors).toEqual([]);
  await navigation(page, 'Study');
  await page.screenshot({
    path: testInfo.outputPath('learning-canvas.png'),
    fullPage: true,
    animations: 'disabled',
  });
});
test('lecture notes become study sources and provider failures are explicit', async ({ page }) => {
  await courseSetup(page);
  await navigation(page, 'Materials');
  await page.getByRole('button', { name: 'Lecture note', exact: true }).click();
  await page.getByLabel('Lecture or topic', { exact: true }).fill('Lecture questions');
  await page
    .getByLabel('Your notes', { exact: true })
    .fill('Why does a valid implementation not guarantee a valid model?');
  await page.getByRole('button', { name: 'Save as study material' }).click();
  await expect(page.getByText('Lecture questions', { exact: true })).toBeVisible();
  await page.route('**/api/tutor', (route) =>
    route.fulfill({
      status: 502,
      contentType: 'application/json',
      body: JSON.stringify({
        error: 'Provider unavailable. Your work is saved.',
      }),
    }),
  );
  await navigation(page, 'Study');
  await page.getByRole('button', { name: 'Start with a question' }).click();
  await expect(page.getByRole('alert')).toContainText('Provider unavailable');
  await expect(page.getByRole('button', { name: 'Start with a question' })).toBeEnabled();
  await page
    .getByRole('textbox', { name: 'Talk to your tutor', exact: true })
    .fill('Keep this question if the provider fails.');
  await page.getByRole('button', { name: 'Send to tutor', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Provider unavailable');
  await expect(page.getByRole('textbox', { name: 'Talk to your tutor', exact: true })).toHaveValue(
    'Keep this question if the provider fails.',
  );

  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
});

test('imports a supplied real course PDF and rejects a duplicate', async ({ page }) => {
  const path = process.env.STUDY_TEST_PDF;
  test.skip(!path, 'Set STUDY_TEST_PDF to verify a private course PDF locally.');
  await courseSetup(page);
  await navigation(page, 'Materials');
  const input = page.locator('input[type=file][accept=".pdf,.md,.markdown,.txt"]');
  await input.setInputFiles(path!);
  const name = path!.split('/').at(-1)!;
  await expect(page.getByText(name, { exact: true })).toBeVisible({ timeout: 30_000 });
  await input.setInputFiles(path!);
  await expect(page.getByRole('alert')).toContainText('already in this course');
});

test('choice activities withhold answers and exam review is an explicit transition', async ({
  page,
}) => {
  await page.route('**/api/tutor', async (route) => {
    const request = route.request().postDataJSON();
    const text = request.messages.at(-1).content;
    const attempt = text.startsWith('My attempt:');
    const review = text.startsWith('The practice exam is finished.');
    const reply = {
      message: attempt
        ? 'Your response is recorded. Continue when you are ready.'
        : review
          ? 'Review the comparison with the real system.'
          : 'Make a prediction before asking for help.',
      activity:
        attempt || review
          ? null
          : {
              ...activity,
              choices: ['Validation', 'Verification'],
              sourceIds: [request.context.sources[0].id],
              body: '<script>window.badActivity = true</script><img src=x onerror="window.badActivity=true">A model serves a purpose.',
            },
      assessment: {
        verdict: 'correct',
        feedback: 'This correctness feedback must stay hidden during the exam.',
      },
      memory: null,
    };
    const body = `data: ${JSON.stringify({ choices: [{ delta: { content: JSON.stringify(reply) } }] })}\n\ndata: [DONE]\n\n`;
    await route.fulfill({ contentType: 'text/event-stream', body });
  });
  await courseSetup(page);
  await page.getByRole('button', { name: 'Practice exam', exact: true }).click();
  await expect(page.getByText('Unaided practice', { exact: true })).toBeVisible();
  await expect(page.getByText(activity.answer, { exact: true })).toHaveCount(0);
  await page.getByRole('radio', { name: 'Validation', exact: true }).check();
  await page.getByRole('button', { name: 'Save my answer', exact: true }).click();
  await expect(page.getByText('Answer saved. Ask for a review when you finish.')).toBeVisible();
  await expect(page.getByText(/Successful independent check/)).toHaveCount(0);
  await expect(page.getByText(/This correctness feedback must stay hidden/)).toHaveCount(0);
  expect(
    await page.evaluate(() => (window as unknown as { badActivity?: boolean }).badActivity),
  ).toBeUndefined();
  await page.getByRole('button', { name: 'Review exam', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Check my reasoning', exact: true })).toBeVisible();
  await expect(page.getByText('Unaided practice', { exact: true })).toHaveCount(0);
});
