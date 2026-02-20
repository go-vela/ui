/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockReposList } from './utils/repoMocks';
import { mockSourceReposError } from './utils/sourceReposMocks';
import { sourceReposPattern } from './utils/routes';

test.describe('Errors', () => {
  test.describe('logged out', () => {
    test.beforeEach(async ({ app }) => {
      await app.loggedOut('/');
    });

    test('overview should not show the errors tray', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toBeHidden();
    });
  });

  test.describe('logged in', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockReposList(page, 'repositories.json');
      await app.login('/');
    });

    test('stubbed repositories should not show the errors tray', async ({
      page,
    }) => {
      await expect(page.getByTestId('alerts')).toBeHidden();
    });
  });

  test.describe('over 10 errors', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSourceReposError(
        page,
        500,
        'error fetching source repositories',
      );
      await app.login('/account/source-repos');
      for (let i = 0; i < 10; i += 1) {
        const responsePromise = page.waitForResponse(sourceReposPattern);
        await page.getByTestId('refresh-source-repos').click();
        await responsePromise;
      }
    });

    test('should show the errors tray', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Status 500');
    });

    test('clicking alert should clear it', async ({ page }) => {
      const alerts = page.getByTestId('alert');
      const count = await alerts.count();
      expect(count).toBeGreaterThan(0);
      await alerts.first().scrollIntoViewIfNeeded();
      await alerts.first().click({ force: true });
      await expect(alerts).toHaveCount(count - 1);
    });
  });
});
