/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import { mockBuildsByNumber, mockBuildsList } from './utils/buildMocks';
import { mockHooksListPaged } from './utils/hookMocks';
import { mockSecretsList } from './utils/secretMocks';
import { mockRepoEnable, mockRepoEnableError } from './utils/repoMocks';
import { mockUserUpdate } from './utils/userMocks';
import { buildListPattern, repoEnablePattern } from './utils/routes';

async function clickAndWaitForEnable(page: Page) {
  await Promise.all([
    page.waitForResponse(
      response =>
        repoEnablePattern.test(response.url()) &&
        response.request().method() === 'POST',
    ),
    page.getByTestId('enable-repo-button').click(),
  ]);
}

test.describe('Repo', () => {
  test.describe('logged in and server returning 5 builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsList(page, 'builds_5.json');
      await mockBuildsByNumber(page);
      await mockHooksListPaged(page);
      await app.login('/github/octocat');

      await page.getByTestId('builds').waitFor();
    });

    test('repo jump tabs should show', async ({ page }) => {
      await expect(page.getByTestId('jump-bar-repo')).toBeVisible();
    });

    test.describe('click audit in nav tabs', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('jump-Audit').click();
      });

      test('loads the first page of hooks', async ({ page }) => {
        await expect(page).toHaveURL(/\/github\/octocat\/hooks$/);
      });

      test.describe('click next page of hooks', () => {
        test.beforeEach(async ({ page }) => {
          const pagerNext = page.getByTestId('pager-next');
          await expect(pagerNext).toHaveCount(2);
          await pagerNext.first().click();
        });

        test('loads the second page of hooks', async ({ page }) => {
          await expect(page).toHaveURL(/\/github\/octocat\/hooks\?page=2$/);
        });

        test.describe('click settings in nav tabs', () => {
          test.beforeEach(async ({ page }) => {
            await page.getByTestId('jump-Settings').click();
          });

          test('loads repo settings', async ({ page }) => {
            await expect(page).toHaveURL(/\/github\/octocat\/settings$/);
          });
        });

        test.describe('click schedules in nav tabs', () => {
          test.beforeEach(async ({ page }) => {
            await page.getByTestId('jump-Schedules').click();
          });

          test('loads repo schedules', async ({ page }) => {
            await expect(page).toHaveURL(/\/github\/octocat\/schedules$/);
          });
        });

        test.describe('click audit in nav tabs, again', () => {
          test.beforeEach(async ({ page }) => {
            await page.getByTestId('jump-Audit').click();
          });

          test('retains pagination, loads the second page of hooks', async ({
            page,
          }) => {
            await expect(page).toHaveURL(/\/github\/octocat\/hooks\?page=2$/);
          });
        });

        test.describe('click secrets in nav tabs', () => {
          test.beforeEach(async ({ page }) => {
            await mockSecretsList(page, []);
            await page.getByTestId('jump-Secrets').click();
          });

          test('loads repo secrets page', async ({ page }) => {
            await expect(page).toHaveURL(
              /\/-\/secrets\/native\/repo\/github\/octocat$/,
            );
            await expect(page.getByTestId('repo-secrets-table')).toBeVisible();
          });

          test('also loads org secrets', async ({ page }) => {
            await expect(page.getByTestId('org-secrets-table')).toBeVisible();
          });

          test('link to manage org secrets shows', async ({ page }) => {
            await expect(page.getByTestId('manage-org-secrets')).toBeVisible();
          });

          test('click link to manage org secrets should redirect to org secrets', async ({
            page,
          }) => {
            await page.getByTestId('manage-org-secrets').click();
            await expect(page).toHaveURL(/\/-\/secrets\/native\/org\/github$/);
          });
        });
      });
    });
  });

  test.describe('logged in and repo not enabled (404 error)', () => {
    test.beforeEach(async ({ page, app }) => {
      await page.route(buildListPattern, route =>
        route.fulfill({
          status: 404,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'repo github/octocat not found' }),
        }),
      );
      await mockRepoEnable(page, 'enable_repo_response.json');
      await mockUserUpdate(page, 'user.json');
      await app.login('/github/octocat');
    });

    test('should not show the generic error message', async ({ page }) => {
      await expect(page.getByTestId('builds-error')).toBeVisible();
      await expect(page.getByTestId('builds-error')).not.toContainText(
        'There was an error fetching builds.',
      );
    });

    test('should show the enable repo message and button', async ({ page }) => {
      await expect(page.getByTestId('builds-error')).toContainText(
        'This repository may not be enabled yet',
      );
      await expect(page.getByTestId('enable-repo-button')).toBeVisible();
      await expect(page.getByTestId('enable-repo-button')).toContainText(
        'Enable Repository',
      );
    });

    test('should not show alert for 404 error', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toBeHidden();
    });

    test.describe('click enable repo button', () => {
      test('should call enable repo API', async ({ page }) => {
        await clickAndWaitForEnable(page);
      });

      test('should show success alert and builds after enabling', async ({
        page,
      }) => {
        await clickAndWaitForEnable(page);

        await expect(page.getByTestId('alerts')).toContainText(
          'github/octocat has been enabled',
        );

        await page.unroute(buildListPattern);
        await mockBuildsList(page, 'builds_5.json');
        await page.reload();
        await expect(page.getByTestId('builds')).toBeVisible();
      });
    });

    test.describe('enable repo fails', () => {
      test('should show error alert and keep enable button available', async ({
        page,
      }) => {
        await page.unroute(repoEnablePattern);
        await mockRepoEnableError(
          page,
          500,
          JSON.stringify({
            error:
              'unable to create webhook for github/octocat: something went wrong',
          }),
        );

        await clickAndWaitForEnable(page);
        await expect(page.getByTestId('alerts')).toContainText(
          'unable to create webhook',
        );
        await expect(page.getByTestId('enable-repo-button')).toBeVisible();
        await expect(page.getByTestId('enable-repo-button')).toBeEnabled();
      });
    });
  });
});
