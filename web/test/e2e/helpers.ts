import { expect, type Page } from '@playwright/test';

export async function navigation(page: Page, title: string) {
  const open = page.getByRole('button', {
    name: 'Open navigation',
    exact: true,
  });
  if (await open.isVisible()) await open.click();
  await page
    .getByRole('navigation', { name: 'Workspace', exact: true })
    .getByRole('button', { name: title, exact: true })
    .click();
  if (await open.isVisible())
    await expect(page.getByRole('complementary', { name: 'Learning navigation' })).toBeHidden();
}
export async function courseSetup(page: Page) {
  await page.goto('/');
  const open = page.getByRole('button', { name: 'Open navigation', exact: true });
  if (await open.isVisible()) await open.click();
  await page.getByRole('button', { name: 'Add course', exact: true }).click();
  await page.getByLabel('Course name', { exact: true }).fill('Modellierung und Simulation');
  await page
    .getByLabel('What do you want to be able to do?')
    .fill('Distinguish verification and validation.');
  await page.getByRole('button', { name: 'Create course', exact: true }).click();
  await navigation(page, 'Materials');
  await page.locator('input[type=file][accept=".pdf,.md,.markdown,.txt"]').setInputFiles({
    name: 'model-systems.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from(
      'A model is a purposeful abstraction of a real system. Verification checks its implementation; validation checks fitness for its intended use.',
    ),
  });
  await expect(page.getByText('model-systems.txt', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Open connections', exact: true }).click();
  await page.getByLabel('Text and activity provider').selectOption('openai');
  await page.getByLabel('OpenAI API key', { exact: true }).fill('test-only-key');
  await page.getByRole('button', { name: 'Use these connections' }).click();
  await navigation(page, 'Study');
}
