/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import { mockRepoSchedules } from './utils/scheduleMocks';

async function setScheduleAllowlist(
  page: Page,
  allowlist: string,
): Promise<void> {
  await page.addInitScript(value => {
    (window as any).__velaEnv = {
      VELA_SCHEDULE_ALLOWLIST: value,
    };
  }, allowlist);
}

async function openSchedules(
  page: Page,
  app: { login: (path?: string) => Promise<void> },
  allowlist: string,
): Promise<void> {
  await setScheduleAllowlist(page, allowlist);
  await mockRepoSchedules(page, 'schedules.json');
  await app.login('/github/octocat/schedules');
}

test.describe('Schedules', () => {
  test.describe('server returning schedules', () => {
    test.describe('allowlist contains github/octocat', () => {
      test.beforeEach(async ({ page, app }) => {
        await openSchedules(page, app, 'github/octocat');
      });

      test('Schedules tab should exist', async ({ page }) => {
        await expect(page.getByTestId('jump-Schedules')).toBeVisible();
        await expect(page.getByTestId('jump-Schedules')).toContainText(
          'Schedules',
        );
      });

      test('Add Schedule button should exist', async ({ page }) => {
        await expect(page.getByTestId('add-repo-schedule')).toBeVisible();
        await expect(page.getByTestId('add-repo-schedule')).toContainText(
          'Add',
        );
      });

      test('schedules table should show 2 rows', async ({ page }) => {
        await expect(page.getByTestId('schedules-row')).toHaveCount(2);
      });
    });

    test.describe('allowlist contains *', () => {
      test.beforeEach(async ({ page, app }) => {
        await openSchedules(page, app, '*');
      });

      test('Schedules tab should exist', async ({ page }) => {
        await expect(page.getByTestId('jump-Schedules')).toBeVisible();
        await expect(page.getByTestId('jump-Schedules')).toContainText(
          'Schedules',
        );
      });

      test('Add Schedule button should exist', async ({ page }) => {
        await expect(page.getByTestId('add-repo-schedule')).toBeVisible();
        await expect(page.getByTestId('add-repo-schedule')).toContainText(
          'Add',
        );
      });

      test('schedules table should show 2 rows', async ({ page }) => {
        await expect(page.getByTestId('schedules-row')).toHaveCount(2);
      });
    });

    test.describe('allowlist is empty', () => {
      test.beforeEach(async ({ page, app }) => {
        await openSchedules(page, app, ' ');
      });

      test('Schedules tab should not exist', async ({ page }) => {
        await expect(page.getByTestId('jump-Schedules')).toHaveCount(0);
      });

      test('Add Schedule button should not exist', async ({ page }) => {
        await expect(page.getByTestId('add-repo-schedule')).toHaveCount(0);
      });

      test('should show not allowed warning', async ({ page }) => {
        await expect(
          page.getByTestId('repo-schedule-not-allowed'),
        ).toBeVisible();
      });

      test('schedules table should not show rows', async ({ page }) => {
        await expect(page.getByTestId('schedules-row')).toHaveCount(0);
      });
    });

    test.describe('schedule', () => {
      test.beforeEach(async ({ page, app }) => {
        await openSchedules(page, app, '*');
        await page.getByTestId('schedules-row').first().waitFor();
      });

      test('should show name', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('.name')).toContainText('Daily');
      });

      test('should show entry', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=cron-expression]')).toContainText(
          '0 0 * * *',
        );
      });

      test('should show enabled', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=enabled]')).toContainText('yes');
      });

      test('should show branch', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=branch]')).toContainText('main');
      });

      test('should show last scheduled at', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=scheduled-at]')).toBeVisible();
      });

      test('should show next run', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=next-run]')).toBeVisible();
      });

      test('should show updated by', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=updated-by]')).toContainText(
          'CookieCat',
        );
      });

      test('should show updated at', async ({ page }) => {
        const row = page.getByTestId('schedules-row').first();
        await expect(row.locator('[data-label=updated-at]')).toBeVisible();
      });

      test('should show schedule error', async ({ page }) => {
        await expect(page.getByTestId('schedules-error')).toContainText(
          'unable to trigger build for schedule Hourly: unable to schedule build: unable to compile pipeline configuration for github/octocat: 1 error occurred: * no "version:" YAML property provided',
        );
      });
    });
  });
});
