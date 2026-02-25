/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockWorkersError,
  mockWorkersList,
  mockWorkersListPaged,
} from './utils/workerMocks';

test.describe('Workers', () => {
  test.describe('server returning workers error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockWorkersError(page, 500, 'server error');
      await app.login('/status/workers');
    });

    test('workers table should not show rows', async ({ page }) => {
      await expect(page.getByTestId('workers-error')).toBeVisible();
      await expect(page.getByTestId('workers-row')).toHaveCount(0);
    });

    test('error should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });

    test('error banner should show', async ({ page }) => {
      await expect(page.getByTestId('workers-error')).toContainText(
        'there was an error',
      );
    });
  });

  test.describe('server returning 5 workers', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockWorkersList(page, 'workers_5.json');
      await app.login('/status/workers');
    });

    test('workers table should show', async ({ page }) => {
      await expect(page.getByTestId('workers-table')).toBeVisible();
    });

    test('workers table should show 5 workers', async ({ page }) => {
      await expect(page.getByTestId('workers-row')).toHaveCount(5);
    });

    test('pagination controls should not show', async ({ page }) => {
      await expect(page.getByTestId('pager-previous')).toHaveCount(2);
      await expect(page.getByTestId('pager-previous').first()).toBeDisabled();
      await expect(page.getByTestId('pager-previous').last()).toBeDisabled();
    });

    test.describe('worker', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('workers-row').first().waitFor();
      });

      test('should show status', async ({ page }) => {
        const firstWorker = page.getByTestId('workers-row').first();
        await expect(firstWorker.getByTestId('cell-status')).toContainText(
          'busy',
        );
        await expect(
          firstWorker.getByTestId('cell-running-builds'),
        ).toContainText('github/octocat/1');
      });

      test('should have error styles', async ({ page }) => {
        const lastWorker = page.getByTestId('workers-row').last();
        await expect(lastWorker).toHaveClass(/status-error/);
      });
    });
  });

  test.describe('server returning 10 workers', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockWorkersListPaged(page);
      await app.login('/status/workers');
    });

    test('workers table should show 10 workers', async ({ page }) => {
      await expect(page.getByTestId('workers-row')).toHaveCount(10);
    });

    test('shows page 2 of the workers', async ({ page }) => {
      await page.goto('/status/workers?page=2');
      await expect(page.getByTestId('workers-row')).toHaveCount(10);
      await expect(page.getByTestId('pager-next')).toHaveCount(2);
      await expect(page.getByTestId('pager-next').first()).toBeDisabled();
      await expect(page.getByTestId('pager-next').last()).toBeDisabled();
    });

    test("loads the first page when hitting the 'previous' button", async ({
      page,
    }) => {
      await page.goto('/status/workers?page=2');
      await expect(page.getByTestId('pager-previous')).toHaveCount(2);
      await page.getByTestId('pager-previous').first().click();
      await expect(page).toHaveURL(/\/status\/workers(\?page=1)?$/);
    });
  });
});
