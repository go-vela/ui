/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import { mockRepoSchedule } from './utils/scheduleMocks';

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

async function openAddSchedule(
  page: Page,
  app: { login: (path?: string) => Promise<void> },
  allowlist: string,
): Promise<void> {
  await setScheduleAllowlist(page, allowlist);
  await mockRepoSchedule(page, 'schedule.json');
  await app.login('/github/octocat/schedules/add');
}

async function openViewSchedule(
  page: Page,
  app: { login: (path?: string) => Promise<void> },
  allowlist: string,
): Promise<void> {
  await setScheduleAllowlist(page, allowlist);
  await mockRepoSchedule(page, 'schedule.json');
  await app.login('/github/octocat/schedules/Daily');
}

test.describe('Add Schedule', () => {
  test.describe('allowlist contains github/octocat', () => {
    test.beforeEach(async ({ page, app }) => {
      await openAddSchedule(page, app, 'github/octocat');
    });

    test('default name placeholder should show', async ({ page }) => {
      await expect(page.getByTestId('input-name')).toHaveAttribute(
        'placeholder',
        /Schedule Name/,
      );
    });

    test('default entry value should show', async ({ page }) => {
      await expect(page.getByTestId('textarea-entry')).toHaveAttribute(
        'placeholder',
        /0 0 \* \* \*/,
      );
    });

    test('default branch placeholder should show', async ({ page }) => {
      await expect(page.getByTestId('input-branch-name')).toHaveAttribute(
        'placeholder',
        /Branch Name/,
      );
    });

    test('submit button should show', async ({ page }) => {
      await expect(page.getByTestId('button-submit')).toBeVisible();
    });
  });

  test.describe('allowlist contains *', () => {
    test.beforeEach(async ({ page, app }) => {
      await openAddSchedule(page, app, '*');
    });

    test('default name placeholder should show', async ({ page }) => {
      await expect(page.getByTestId('input-name')).toHaveAttribute(
        'placeholder',
        /Schedule Name/,
      );
    });

    test('default entry value should show', async ({ page }) => {
      await expect(page.getByTestId('textarea-entry')).toHaveAttribute(
        'placeholder',
        /0 0 \* \* \*/,
      );
    });

    test('default branch placeholder should show', async ({ page }) => {
      await expect(page.getByTestId('input-branch-name')).toHaveAttribute(
        'placeholder',
        /Branch Name/,
      );
    });

    test('submit button should show', async ({ page }) => {
      await expect(page.getByTestId('button-submit')).toBeVisible();
    });
  });

  test.describe('allowlist is empty', () => {
    test.beforeEach(async ({ page, app }) => {
      await openAddSchedule(page, app, ' ');
    });

    test('default name should show and be disabled', async ({ page }) => {
      const input = page.getByTestId('input-name');
      await expect(input).toHaveAttribute('placeholder', /Schedule Name/);
      await expect(input).toBeDisabled();
    });

    test('default entry should show and be disabled', async ({ page }) => {
      const input = page.getByTestId('textarea-entry');
      await expect(input).toHaveAttribute('placeholder', /0 0 \* \* \*/);
      await expect(input).toBeDisabled();
    });

    test('default branch placeholder should show and be disabled', async ({
      page,
    }) => {
      const input = page.getByTestId('input-branch-name');
      await expect(input).toHaveAttribute('placeholder', /Branch Name/);
      await expect(input).toBeDisabled();
    });

    test('submit button should show and be disabled', async ({ page }) => {
      await expect(page.getByTestId('button-submit')).toBeDisabled();
    });

    test('should show not allowed warning', async ({ page }) => {
      await expect(page.getByTestId('repo-schedule-not-allowed')).toBeVisible();
    });
  });
});

test.describe('View/Edit Schedule', () => {
  test.describe('allowlist contains github/octocat', () => {
    test.beforeEach(async ({ page, app }) => {
      await openViewSchedule(page, app, 'github/octocat');
    });

    test('default name value should show', async ({ page }) => {
      await expect(page.getByTestId('input-name')).toHaveValue('Daily');
    });

    test('default entry value should show', async ({ page }) => {
      await expect(page.getByTestId('textarea-entry')).toHaveAttribute(
        'placeholder',
        /0 0 \* \* \*/,
      );
    });

    test('default branch value should show', async ({ page }) => {
      await expect(page.getByTestId('input-branch-name')).toHaveValue('main');
    });

    test('submit button should show', async ({ page }) => {
      await expect(page.getByTestId('button-submit')).toBeVisible();
    });

    test('delete button should show', async ({ page }) => {
      await expect(page.getByTestId('button-delete')).toBeVisible();
    });
  });

  test.describe('allowlist contains *', () => {
    test.beforeEach(async ({ page, app }) => {
      await openViewSchedule(page, app, '*');
    });

    test('default name value should show', async ({ page }) => {
      await expect(page.getByTestId('input-name')).toHaveValue('Daily');
    });

    test('default entry value should show', async ({ page }) => {
      await expect(page.getByTestId('textarea-entry')).toHaveAttribute(
        'placeholder',
        /0 0 \* \* \*/,
      );
    });

    test('default branch value should show', async ({ page }) => {
      await expect(page.getByTestId('input-branch-name')).toHaveValue('main');
    });

    test('submit button should show', async ({ page }) => {
      await expect(page.getByTestId('button-submit')).toBeVisible();
    });

    test('delete button should show', async ({ page }) => {
      await expect(page.getByTestId('button-delete')).toBeVisible();
    });
  });

  test.describe('allowlist is empty', () => {
    test.beforeEach(async ({ page, app }) => {
      await openViewSchedule(page, app, ' ');
    });

    test('default name should show and be disabled', async ({ page }) => {
      const input = page.getByTestId('input-name');
      await expect(input).toHaveAttribute('placeholder', /Schedule Name/);
      await expect(input).toBeDisabled();
    });

    test('default entry should show and be disabled', async ({ page }) => {
      const input = page.getByTestId('textarea-entry');
      await expect(input).toHaveAttribute('placeholder', /0 0 \* \* \*/);
      await expect(input).toBeDisabled();
    });

    test('default branch placeholder should show and be disabled', async ({
      page,
    }) => {
      const input = page.getByTestId('input-branch-name');
      await expect(input).toHaveAttribute('placeholder', /Branch Name/);
      await expect(input).toBeDisabled();
    });

    test('submit button should show and be disabled', async ({ page }) => {
      await expect(page.getByTestId('button-submit')).toBeDisabled();
    });

    test('should show not allowed warning', async ({ page }) => {
      await expect(page.getByTestId('repo-schedule-not-allowed')).toBeVisible();
    });
  });
});
