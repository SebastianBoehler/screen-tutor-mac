import { expect, test } from '@playwright/test';
import { courseSetup } from './helpers';

test('generated blocks work and retain their state in the document', async ({ page }) => {
  const specs = [
    { kind: 'flashcard', front: 'What is slope?', back: 'Change in y per unit x.' },
    {
      kind: 'fill-blank',
      before: 'The line crosses the y-axis at the',
      after: '.',
      answer: 'intercept',
    },
    { kind: 'linear', slope: 1, intercept: 0 },
  ];
  let index = 0;
  await page.route('**/api/tutor', async (route) => {
    const request = route.request().postDataJSON();
    const spec = specs[index++];
    const reply = {
      message: 'Explore this concept.',
      activity: {
        title: `Block ${index}`,
        concept: 'Lines',
        body: '',
        question: 'Explain the idea.',
        choices: [],
        answer: 'An explanation.',
        hint: 'Think about the line.',
        explanation: '',
        diagram: null,
        interactive: spec,
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
  const first = page.getByRole('article', { name: 'Block 1' });
  await first.getByRole('button', { name: 'Expand', exact: true }).click();
  await first.getByRole('button', { name: 'Show answer' }).click();
  await expect(first).toContainText('Change in y per unit x.');
  for (const title of ['Block 2', 'Block 3']) {
    await page.getByRole('textbox', { name: 'Talk to your tutor' }).fill('Next');
    await page.getByRole('button', { name: 'Send to tutor' }).click();
    await expect(page.getByRole('article', { name: title })).toBeVisible();
  }
  const second = page.getByRole('article', { name: 'Block 2' });
  await second.getByRole('button', { name: 'Expand', exact: true }).click();
  await second.getByRole('textbox', { name: 'Missing term' }).fill('intercept');
  await second.getByRole('button', { name: 'Check term' }).click();
  await expect(second).toContainText('Matches the expected term.');
  const third = page.getByRole('article', { name: 'Block 3' });
  await third.getByRole('button', { name: 'Expand', exact: true }).click();
  const slope = third.getByRole('slider', { name: 'Slope' });
  await slope.focus();
  await slope.press('ArrowRight');
  await expect(third.locator('.model-result')).toContainText('1.1');
  await third.getByRole('button', { name: 'Collapse', exact: true }).click();
  await expect(page.locator('.save-status')).toHaveText('Saved locally');
  await page.reload();
  await second.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(second.getByRole('textbox', { name: 'Missing term' })).toHaveValue('intercept');
  await third.getByRole('button', { name: 'Expand', exact: true }).click();
  await expect(third.getByRole('slider', { name: 'Slope' })).toHaveValue('1.1');
});
