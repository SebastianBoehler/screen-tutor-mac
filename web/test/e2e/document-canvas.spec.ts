import { test, expect } from '@playwright/test';
import { courseSetup } from './helpers';

test('new activities append and earlier answers remain editable after reload', async ({ page }) => {
  let count = 0;
  await page.route('**/api/tutor', async (route) => {
    const request = route.request().postDataJSON();
    count += 1;
    const reply = {
      message: 'Consider the next idea.',
      activity: {
        title: `Concept ${count}`,
        concept: `Concept ${count}`,
        body: 'A short explanation.',
        question: 'What do you think?',
        choices: [],
        answer: 'An answer.',
        hint: 'A hint.',
        explanation: '',
        diagram: null,
        interactive: null,
        sourceIds: [request.context.sources[0].id],
      },
      assessment: { verdict: 'ungraded', feedback: '' },
      memory: null,
    };
    await route.fulfill({
      contentType: 'text/event-stream',
      body: `data: ${JSON.stringify({ choices: [{ delta: { content: JSON.stringify(reply) } }] })}\n\ndata: [DONE]\n\n`,
    });
  });
  await courseSetup(page);
  await page.getByRole('button', { name: 'Start with a question' }).click();
  const first = page.getByRole('article', { name: 'Concept 1' });
  await first.getByRole('textbox', { name: 'Your answer or reasoning' }).fill('My first idea');
  await page.getByRole('textbox', { name: 'Talk to your tutor' }).fill('Continue');
  await page.getByRole('button', { name: 'Send to tutor' }).click();
  const second = page.getByRole('article', { name: 'Concept 2' });
  await expect(second).toBeVisible();
  await expect(first).toBeAttached();
  await first.getByRole('button', { name: 'A small hint' }).click();
  await expect(first).toContainText('A hint.');
  await expect(second).not.toContainText('A hint.');
  await page.reload();
  await expect(first.getByRole('textbox', { name: 'Your answer or reasoning' })).toHaveValue(
    'My first idea',
  );
  await expect(first).toContainText('A hint.');
  await expect(second).toBeAttached();
});
