/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsList } from './utils/buildMocks';

test.describe('Contextual Help', () => {
  test.describe('error loading resource', () => {
    test.beforeEach(async ({ app }) => {
      await app.login();
    });

    test('should show the help button', async ({ page }) => {
      await expect(page.getByTestId('help-trigger')).toBeVisible();
    });

    test.describe('clicking help button', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('help-trigger').click();
      });

      test('should show the dropdown', async ({ page }) => {
        await expect(page.getByTestId('help-tooltip')).toBeVisible();
      });
    });
  });

  test.describe('successfully loading resource with cli support', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsList(page, 'builds_5.json');
      await app.login('/github/octocat');
    });

    test('should show the help button', async ({ page }) => {
      await expect(page.getByTestId('help-trigger')).toBeVisible();
    });

    test.describe('clicking help button', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('help-trigger').click();
      });

      test('should show the dropdown', async ({ page }) => {
        await expect(page.getByTestId('help-tooltip')).toBeVisible();
      });

      test('cmd header should contain docs link', async ({ page }) => {
        await expect(page.getByTestId('help-cmd-header')).toContainText(
          '(docs)',
        );
      });

      test('cmd should contain cli command', async ({ page }) => {
        await expect(page.getByTestId('help-row').locator('input')).toHaveValue(
          'vela get builds --org github --repo octocat',
        );
      });

      test('dropdown footer should contain installation and authentication docs', async ({
        page,
      }) => {
        const footer = page.getByTestId('help-footer');
        await expect(footer).toContainText('CLI Installation Docs');
        await expect(footer).toContainText('CLI Authentication Docs');
      });

      test.describe('clicking copy button', () => {
        test('should show copied alert', async ({ page }) => {
          await page.getByTestId('help-copy').click();
          await expect(page.getByTestId('alerts')).toContainText('copied');
        });
      });
    });
  });
});
