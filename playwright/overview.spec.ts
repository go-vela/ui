/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';

test.describe('Overview/Repositories Page', () => {
  test.describe('logged in - favorites loaded', () => {
    test.beforeEach(async ({ app }) => {
      await app.loginWithUserFixture('favorites_overview.json');
    });

    test('should show two org groups', async ({ page }) => {
      await expect(page.getByTestId('repo-org')).toHaveCount(2);
    });

    test('should have one item in the first org and two in the second', async ({
      page,
    }) => {
      await expect(
        page.getByTestId('repo-org').nth(0).getByTestId('repo-item'),
      ).toHaveCount(1);

      await expect(
        page.getByTestId('repo-org').nth(1).getByTestId('repo-item'),
      ).toHaveCount(2);
    });

    test('should show the Source Repositories button', async ({ page }) => {
      await expect(page.getByTestId('source-repos')).toContainText(
        'Source Repositories',
      );
    });

    test('Source Repositories should take you to the respective page', async ({
      page,
    }) => {
      await page.getByTestId('source-repos').click();
      await expect(page).toHaveURL(/\/account\/source-repos$/);
    });

    test('View button should exist for all repos', async ({ page }) => {
      await expect(page.getByTestId('repo-view')).toHaveCount(3);
    });

    test('it should take you to the repo build page when utilizing the View button', async ({
      page,
    }) => {
      await page.getByTestId('repo-view').first().click();
      await expect(page).toHaveURL(/\/github\/octocat$/);
    });

    test('org should show', async ({ page }) => {
      await expect(
        page.getByTestId('repo-org').filter({ hasText: 'org' }),
      ).toHaveCount(1);
    });

    test('repo_a should show', async ({ page }) => {
      await expect(
        page.getByTestId('repo-item').filter({ hasText: 'repo_a' }),
      ).toHaveCount(1);
    });

    test.describe("type 'octo' into the home search bar", () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('home-search-input').fill('octo');
      });

      test('octocat should show', async ({ page }) => {
        await expect(
          page.getByTestId('repo-item').filter({ hasText: 'octocat' }),
        ).toHaveCount(1);
      });

      test('repo_a should not show', async ({ page }) => {
        await expect(
          page.getByTestId('repo-item').filter({ hasText: 'repo_a' }),
        ).toHaveCount(0);
      });

      test('org should not show', async ({ page }) => {
        await expect(
          page.getByTestId('repo-org').filter({ hasText: 'org' }),
        ).toHaveCount(0);
      });
    });
  });
});
