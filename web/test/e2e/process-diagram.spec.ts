import { expect, test } from '@playwright/test';

test('process diagram shows its full content without expansion controls', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Examples', exact: true }).click();
  await page
    .getByRole('dialog', { name: 'Canvas examples' })
    .getByRole('button', { name: 'Process diagram' })
    .click();
  const diagram = page.getByRole('figure', { name: 'Concept mechanism' });
  await expect(diagram).toBeVisible();
  await expect(diagram).toContainText('Check that the implementation follows the model.');
  await expect(diagram).toContainText(
    'Compare predictions with observations for the intended use.',
  );
  await expect(diagram).toContainText('Implement and check');
  await expect(diagram.getByRole('button')).toHaveCount(0);
  await page.reload();
  await expect(diagram).toBeVisible();
  await expect(diagram.locator('.mechanism-node')).toHaveCount(3);
});
