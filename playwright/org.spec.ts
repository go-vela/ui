/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockOrgBuildsList, mockOrgBuildsListPaged } from './utils/buildMocks';
import { mockOrgReposList, mockOrgReposListPaged } from './utils/repoMocks';
import { mockSecretsList } from './utils/secretMocks';

test.describe('Org', () => {
  test.describe('Tabs', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockOrgReposList(page, 'repositories_5.json');
      await app.login('/vela');
    });

    test('should show 3 tabs', async ({ page }) => {
      await expect(page.getByTestId('jump-Repositories')).toBeVisible();
      await expect(page.getByTestId('jump-Builds')).toBeVisible();
      await expect(page.getByTestId('jump-Secrets')).toBeVisible();
    });
  });

  test.describe('Repositories Tab', () => {
    test.describe('logged in and server returning 5 repos', () => {
      test.beforeEach(async ({ page, app }) => {
        await mockOrgReposList(page, 'repositories_5.json');
        await app.login('/vela');
      });

      test('should show 5 repos', async ({ page }) => {
        await expect(page.getByTestId('repo-item')).toHaveCount(5);
      });

      test('should show 5 action buttons for each item', async ({ page }) => {
        const repos = page.getByTestId('repo-item');
        const count = await repos.count();

        for (let index = 0; index < count; index += 1) {
          await expect(repos.nth(index).locator('.button')).toHaveCount(5);
        }
      });
    });

    test.describe('logged in and server returning > 10 repos', () => {
      test.beforeEach(async ({ page, app }) => {
        await mockOrgReposListPaged(page);
        await app.login('/vela');
      });

      test('should show the repos', async ({ page }) => {
        await expect(page.getByTestId('repo-item')).toHaveCount(10);
      });

      test('should show the pager', async ({ page }) => {
        await expect(page.getByTestId('pager-previous')).toHaveCount(2);
        await expect(page.getByTestId('pager-previous').first()).toBeDisabled();
        await expect(page.getByTestId('pager-next')).toHaveCount(2);
        await expect(page.getByTestId('pager-next').first()).toBeEnabled();
      });

      test('should contain the page number on page 2', async ({ page }) => {
        await page.goto('/vela?page=2');
        await expect(page).toHaveTitle(/page 2/);
      });

      test('should still show the pager on page 2', async ({ page }) => {
        await page.goto('/vela?page=2');
        await expect(page.getByTestId('pager-previous')).toHaveCount(2);
        await expect(page.getByTestId('pager-previous').first()).toBeEnabled();
        await expect(page.getByTestId('pager-next')).toHaveCount(2);
        await expect(page.getByTestId('pager-next').first()).toBeDisabled();
      });
    });
  });

  test.describe('Builds Tab', () => {
    test.describe('logged in and returning 5 builds', () => {
      test.beforeEach(async ({ page, app }) => {
        await mockOrgBuildsList(page, 'builds_5.json');
        await app.login('/vela/builds');
      });

      test('should show 5 builds', async ({ page }) => {
        await expect(page.getByTestId('builds')).toBeVisible();
      });

      test('should show the filter control', async ({ page }) => {
        await expect(page.getByTestId('build-filter')).toBeVisible();
      });
    });

    test.describe('logged in and returning 20 builds', () => {
      test.beforeEach(async ({ page, app }) => {
        await mockOrgBuildsListPaged(page);
        await app.login('/vela/builds');
      });

      test('should show builds', async ({ page }) => {
        await expect(page.getByTestId('builds')).toBeVisible();
      });

      test('should show the pager', async ({ page }) => {
        await expect(page.getByTestId('pager-previous')).toHaveCount(2);
        await expect(page.getByTestId('pager-previous').first()).toBeDisabled();
        await expect(page.getByTestId('pager-next')).toHaveCount(2);
        await expect(page.getByTestId('pager-next').first()).toBeEnabled();
      });

      test('should update page title for page 2', async ({ page }) => {
        await page.goto('/vela/builds?page=2');
        await expect(page).toHaveTitle(/page 2/);
      });
    });
  });

  test.describe('Secrets Tab', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockOrgReposList(page, 'repositories_5.json');
      await mockSecretsList(page, 'secrets_org_5.json');
      await app.login('/vela');
    });

    test('should navigate to the org secrets page', async ({ page }) => {
      await page.getByTestId('jump-Secrets').click();
      await expect(page).toHaveURL(/\/\-\/secrets\/native\/org\/vela(\?.*)?$/);
    });
  });
});
