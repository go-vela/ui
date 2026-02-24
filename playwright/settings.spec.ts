/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';

async function openSettingsFromMenu(page: { getByTestId: any }) {
  await page.getByTestId('identity-summary').click();
  await page.getByTestId('settings-link').click();
}

test.describe('My Settings', () => {
  test.beforeEach(async ({ app }) => {
    await app.login('/');
  });

  test('should show settings option in identity dropdown', async ({ page }) => {
    await page.getByTestId('identity-summary').click();
    await expect(page.getByTestId('settings-link')).toBeVisible();
  });

  test('settings option should bring you to settings page', async ({
    page,
  }) => {
    await openSettingsFromMenu(page);
    await expect(page).toHaveURL('/account/settings');
  });

  test('show auth token on page', async ({ page }) => {
    await openSettingsFromMenu(page);
    const token = page.locator('#token');
    await expect(token).toBeVisible();
    await expect(token).toContainText('signature');
  });

  test('theme radio controls are present on settings page', async ({
    page,
  }) => {
    await openSettingsFromMenu(page);

    await expect(
      page.locator('input[data-test=radio-theme-light]'),
    ).toBeVisible();
    await expect(
      page.locator('input[data-test=radio-theme-dark]'),
    ).toBeVisible();
    await expect(
      page.locator('input[data-test=radio-theme-system]'),
    ).toBeVisible();
  });

  test('selecting Light updates localStorage and body class', async ({
    page,
  }) => {
    await openSettingsFromMenu(page);

    await page.locator('input[data-test=radio-theme-light]').click({
      force: true,
    });

    await expect
      .poll(async () =>
        page.evaluate(() => window.localStorage.getItem('vela-theme')),
      )
      .toBe('theme-light');

    await expect(page.locator('body')).toHaveClass(/theme-light/);
  });

  test('selecting Dark updates localStorage and body class', async ({
    page,
  }) => {
    await openSettingsFromMenu(page);

    await page.locator('input[data-test=radio-theme-dark]').click({
      force: true,
    });

    await expect
      .poll(async () =>
        page.evaluate(() => window.localStorage.getItem('vela-theme')),
      )
      .toBe('theme-dark');

    await expect(page.locator('body')).toHaveClass(/theme-dark/);
  });

  test('selecting System preference stores system choice and applies a concrete theme', async ({
    page,
  }) => {
    await openSettingsFromMenu(page);

    await page.locator('input[data-test=radio-theme-system]').click({
      force: true,
    });

    await expect
      .poll(async () =>
        page.evaluate(() => window.localStorage.getItem('vela-theme')),
      )
      .toBe('theme-system');

    await expect(page.locator('body')).toHaveClass(/theme-(light|dark)/);
  });
});
