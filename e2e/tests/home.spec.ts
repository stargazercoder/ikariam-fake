import { test, expect } from '@playwright/test';

test('app loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);
});

test('flutter root mounts', async ({ page }) => {
  await page.goto('/');
  // Flutter web mounts into <flutter-view> or <flt-glass-pane>
  await page.waitForSelector('flutter-view, flt-glass-pane, flt-scene-host', { timeout: 30_000 });
});
