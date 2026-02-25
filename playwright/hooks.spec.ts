/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsByNumber } from './utils/buildMocks';
import { mockRepoDetail } from './utils/repoMocks';
import {
  mockHooksError,
  mockHooksList,
  mockHooksListPaged,
  mockRedeliverHook,
} from './utils/hookMocks';

test.describe('Hooks', () => {
  test.describe('server returning hooks error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockHooksError(page, 500);
      await app.login('/github/octocat/hooks');
    });

    test('hooks table should not show rows', async ({ page }) => {
      await expect(page.getByTestId('hooks-row')).toHaveCount(0);
    });

    test('error should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });

    test('error banner should show', async ({ page }) => {
      await expect(page.getByTestId('hooks-error')).toContainText(
        'there was an error',
      );
    });
  });

  test.describe('server returning 5 hooks', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockHooksList(page, 'hooks_5.json');
      await mockBuildsByNumber(page, {
        1: 'build_success.json',
        2: 'build_failure.json',
        3: 'build_running.json',
      });
      await mockRepoDetail(page, 'repository.json');
      await app.login('/github/octocat/hooks');
    });

    test('hooks table should show', async ({ page }) => {
      await expect(page.getByTestId('hooks-table')).toBeVisible();
    });

    test('hooks table should show 5 hooks', async ({ page }) => {
      await expect(page.getByTestId('hooks-row')).toHaveCount(5);
    });

    test('pagination controls should not show', async ({ page }) => {
      await expect(page.getByTestId('pager-previous').first()).toBeDisabled();
    });

    test.describe('hook', () => {
      test.beforeEach(async ({ page }) => {
        await expect(page.getByTestId('hooks-row')).toHaveCount(5);
      });

      test('should show source id', async ({ page }) => {
        const firstHook = page.getByTestId('hooks-row').first();
        await expect(firstHook.locator('.source-id')).toContainText(
          '7bd477e4-4415-11e9-9359-0d41fdf9567e',
        );
      });

      test('should show event', async ({ page }) => {
        const firstHook = page.getByTestId('hooks-row').first();
        await expect(firstHook).toContainText('push');
      });

      test('should show host', async ({ page }) => {
        const firstHook = page.getByTestId('hooks-row').first();
        await expect(firstHook).toContainText('github.com');
      });

      test('should show redeliver hook', async ({ page }) => {
        const firstHook = page.getByTestId('hooks-row').first();
        await expect(firstHook.getByTestId('redeliver-hook-5')).toBeVisible();
      });

      test.describe('failure', () => {
        test.beforeEach(async ({ page }) => {
          const lastHook = page.getByTestId('hooks-row').last();
          await expect(lastHook).toHaveClass(/status-error/);
        });

        test('should show error', async ({ page }) => {
          await expect(page.getByTestId('hooks-error')).toContainText(
            'github/octocat does not have tag events enabled',
          );
        });
      });

      test.describe('skipped', () => {
        test.beforeEach(async ({ page }) => {
          const skipHook = page.getByTestId('hooks-row').nth(3);
          await expect(skipHook).toHaveClass(/status-skipped/);
        });

        test('should show skip message', async ({ page }) => {
          await expect(page.getByTestId('hooks-skipped')).toContainText(
            'skipping build since only init and clone steps found',
          );
        });
      });

      test.describe('successful redeliver hook', () => {
        test.beforeEach(async ({ page }) => {
          await mockRedeliverHook(page, {
            status: 200,
            body: 'hook * redelivered',
          });
        });

        test('should show alert', async ({ page }) => {
          await page.getByTestId('redeliver-hook-1').click();
          await expect(page.getByTestId('alerts')).toContainText(
            'Hook #1 redelivered successfully.',
          );
        });
      });

      test.describe('unsuccessful redeliver hook', () => {
        test.beforeEach(async ({ page }) => {
          await mockRedeliverHook(page, {
            status: 500,
            body: 'unable to redeliver hook',
          });
        });

        test('should show error', async ({ page }) => {
          await page.getByTestId('redeliver-hook-1').click();
          await expect(page.getByTestId('alerts')).toContainText('Error');
        });
      });
    });
  });

  test.describe('server returning 10 hooks', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockHooksListPaged(page);
      await app.login('/github/octocat/hooks');
    });

    test('hooks table should show 10 hooks', async ({ page }) => {
      await expect(page.getByTestId('hooks-row')).toHaveCount(10);
    });

    test('shows page 2 of the hooks', async ({ page }) => {
      await page.goto('/github/octocat/hooks?page=2');
      await expect(page.getByTestId('hooks-row')).toHaveCount(10);
      await expect(page.getByTestId('pager-next').first()).toBeDisabled();
    });

    test("loads the first page when hitting the 'previous' button", async ({
      page,
    }) => {
      await page.goto('/github/octocat/hooks?page=2');
      await page.getByTestId('pager-previous').first().click();
      await expect(page).toHaveURL(/\/github\/octocat\/hooks(\?page=1)?$/);
    });
  });
});
