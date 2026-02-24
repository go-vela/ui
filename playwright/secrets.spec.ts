/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import { jsonResponse, resolvePayload } from './utils/http';
import { mockSecretDetail, mockSecretsList } from './utils/secretMocks';
import { secretDetailPattern, secretsListPattern } from './utils/routes';

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

async function mockSecretDetails(page: Page): Promise<void> {
  await page.route(secretDetailPattern, route => {
    if (route.request().method() !== 'GET') {
      return route.fallback();
    }

    const url = route.request().url();
    if (url.includes('/api/v1/secrets/native/repo/')) {
      return jsonResponse(route, { body: resolvePayload('secret_repo.json') });
    }

    if (
      url.includes('github%2Fdeployment') ||
      url.includes('github/deployment')
    ) {
      return jsonResponse(route, {
        body: resolvePayload('secret_org_path.json'),
      });
    }

    return jsonResponse(route, { body: resolvePayload('secret_org.json') });
  });
}

async function mockSecretDelete(
  page: Page,
  options: { status?: number; body: string },
): Promise<void> {
  await page.route(secretDetailPattern, route => {
    if (route.request().method() !== 'DELETE') {
      return route.fallback();
    }

    return route.fulfill({
      status: options.status ?? 200,
      headers: { 'content-type': 'text/plain' },
      body: options.body,
    });
  });
}

test.describe('Secrets', () => {
  test.describe('server returning repo secret', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSecretDetails(page);
      await mockSecretDelete(page, {
        body: 'Secret repo/github/octocat/password deleted from native service',
      });
      await app.login('/-/secrets/native/repo/github/octocat/password');
    });

    test('delete button should show', async ({ page }) => {
      await expect(page.getByTestId('button-delete')).toBeVisible();
      await expect(page.getByTestId('button-delete')).toContainText('Delete');
    });

    test.describe('allowlist contains *', () => {
      test.beforeEach(async ({ page, app }) => {
        await setScheduleAllowlist(page, '*');
        await mockSecretDetails(page);
        await mockSecretDelete(page, {
          body: 'Secret repo/github/octocat/password deleted from native service',
        });
        await app.login('/-/secrets/native/repo/github/octocat/password');
      });

      test('submit button should show', async ({ page }) => {
        await expect(page.getByTestId('button-submit')).toBeVisible();
      });
    });

    test.describe('allowlist is empty', () => {
      test.beforeEach(async ({ page, app }) => {
        await setScheduleAllowlist(page, ' ');
        await mockSecretDetails(page);
        await mockSecretDelete(page, {
          body: 'Secret repo/github/octocat/password deleted from native service',
        });
        await app.login('/-/secrets/native/repo/github/octocat/password');
      });

      test('add button should not show', async ({ page }) => {
        await expect(page.getByTestId('checkbox-schedule')).toHaveCount(0);
      });
    });

    test.describe('click Delete', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('button-delete').click();
      });

      test('delete button should show when going to another secrets page', async ({
        page,
      }) => {
        await page.goto('/-/secrets/native/org/github/password');
        await expect(page.getByTestId('button-delete')).toBeVisible();
        await expect(page.getByTestId('button-delete')).toContainText('Delete');
      });

      test('Cancel button should show', async ({ page }) => {
        await expect(page.getByTestId('button-delete-cancel')).toBeVisible();
        await expect(page.getByTestId('button-delete-cancel')).toContainText(
          'Cancel',
        );
      });

      test('Confirm button should show', async ({ page }) => {
        await expect(page.getByTestId('button-delete-confirm')).toBeVisible();
        await expect(page.getByTestId('button-delete-confirm')).toContainText(
          'Confirm',
        );
      });

      test.describe('click Cancel', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('button-delete-cancel').click();
        });

        test('should revert Confirm to Delete', async ({ page }) => {
          await expect(page.getByTestId('button-delete')).toBeVisible();
          await expect(page.getByTestId('button-delete')).toContainText(
            'Delete',
          );
        });

        test('Cancel should not show', async ({ page }) => {
          await expect(page.getByTestId('button-delete-cancel')).toHaveCount(0);
        });
      });

      test.describe('click Confirm', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('button-delete-confirm').click();
        });

        test('Confirm should redirect to repo secrets page', async ({
          page,
        }) => {
          await expect(page).toHaveURL('/-/secrets/native/repo/github/octocat');
        });

        test('Alert should show', async ({ page }) => {
          await expect(page.getByTestId('alerts')).toContainText('password');
          await expect(page.getByTestId('alerts')).toContainText('Deleted');
          await expect(page.getByTestId('alerts')).toContainText('repo');
        });
      });
    });
  });

  test.describe('add shared secret', () => {
    test.beforeEach(async ({ page, app }) => {
      await app.login('/-/secrets/native/shared/github/*/add');
    });

    test('allow command and substitution should default to false', async ({
      page,
    }) => {
      await expect(
        page.locator('input[data-test=radio-secret-allow-command-no]'),
      ).toBeChecked();
      await expect(
        page.locator('input[data-test=radio-secret-allow-substitution-no]'),
      ).toBeChecked();
    });

    test('should strip disallowed characters from secret name input', async ({
      page,
    }) => {
      await page.getByTestId('input-name').fill('test\'name"with&bad<chars>');
      await expect(page.getByTestId('input-name')).toHaveValue(
        'testnamewithbadchars',
      );
    });
  });

  test.describe('server returning remove error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSecretDetails(page);
      await page.route(secretDetailPattern, route => {
        if (route.request().method() !== 'DELETE') {
          return route.fallback();
        }

        return route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'server error could not remove' }),
        });
      });
      await app.login('/-/secrets/native/repo/github/octocat/password');
      await page.getByTestId('button-delete').click();
      await page.getByTestId('button-delete-confirm').click();
    });

    test('error should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText(
        'could not remove',
      );
    });
  });

  test.describe('server returning secrets error', () => {
    test.beforeEach(async ({ page, app }) => {
      await page.route(secretsListPattern, route => {
        if (route.request().method() !== 'GET') {
          return route.fallback();
        }

        return route.fulfill({ status: 500, body: 'server error' });
      });
      await app.login('/-/secrets/native/org/github');
    });

    test('secrets table should not show', async ({ page }) => {
      await expect(page.getByTestId('org-secrets-error')).toBeVisible();
    });

    test('error should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });

    test('error banner should show', async ({ page }) => {
      await expect(page.getByTestId('org-secrets-error')).toContainText(
        'there was an error',
      );
    });
  });

  test.describe('server returning 5 secrets', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSecretsList(page, 'secrets_org_5.json');
      await mockSecretDetails(page);
      await app.login('/-/secrets/native/org/github');
    });

    test('secrets table should show', async ({ page }) => {
      await expect(page.getByTestId('org-secrets-table')).toBeVisible();
    });

    test('secrets table should show 5 secrets', async ({ page }) => {
      await expect(
        page.getByTestId('org-secrets-table').getByTestId('secrets-row'),
      ).toHaveCount(5);
    });

    test('pagination controls should not show', async ({ page }) => {
      const orgTable = page.getByTestId('org-secrets-table');
      await expect(orgTable.getByTestId('pager-previous')).toBeDisabled();
      await expect(orgTable.getByTestId('pager-next')).toBeDisabled();
    });

    test.describe('secret', () => {
      test.beforeEach(async ({ page }) => {
        const orgRows = page
          .getByTestId('org-secrets-table')
          .getByTestId('secrets-row');
        await orgRows.first().waitFor();
        await orgRows.last().waitFor();
      });

      test('should show copy', async ({ page }) => {
        const orgTable = page.getByTestId('org-secrets-table');
        const firstSecret = orgTable.getByTestId('secrets-row').first();
        const lastSecret = orgTable.getByTestId('secrets-row').last();

        await expect(firstSecret.getByTestId('copy-secret')).toBeVisible();
        await expect(lastSecret.getByTestId('copy-secret')).toBeVisible();
      });

      test('should copy secret to clipboard and alert', async ({ page }) => {
        const firstSecret = page
          .getByTestId('org-secrets-table')
          .getByTestId('secrets-row')
          .first();
        await firstSecret.getByTestId('copy-secret').click();
        await expect(page.getByTestId('alerts')).toContainText('copied');
      });

      test('should show key', async ({ page }) => {
        const orgTable = page.getByTestId('org-secrets-table');
        const firstSecret = orgTable.getByTestId('secrets-row').first();
        const lastSecret = orgTable.getByTestId('secrets-row').last();

        await expect(firstSecret.getByTestId('cell-key')).toContainText(
          'github/docker_username',
        );
        await expect(lastSecret.getByTestId('cell-key')).toContainText(
          'github/deployment',
        );
      });

      test('should show name', async ({ page }) => {
        const orgTable = page.getByTestId('org-secrets-table');
        const firstSecret = orgTable.getByTestId('secrets-row').first();
        const lastSecret = orgTable.getByTestId('secrets-row').last();

        await expect(firstSecret.getByTestId('cell-name')).toContainText(
          'docker_username',
        );
        await expect(lastSecret.getByTestId('cell-name')).toContainText(
          'deployment',
        );
      });

      test('clicking name should route to edit secret page', async ({
        page,
      }) => {
        const firstSecret = page
          .getByTestId('org-secrets-table')
          .getByTestId('secrets-row')
          .first();
        await firstSecret
          .getByTestId('cell-name')
          .locator('a')
          .click({ force: true });
        await expect(page).toHaveURL(
          '/-/secrets/native/org/github/docker_username',
        );
      });

      test('clicking name with special character should use encoded url', async ({
        page,
      }) => {
        const lastSecret = page
          .getByTestId('org-secrets-table')
          .getByTestId('secrets-row')
          .last();
        await lastSecret
          .getByTestId('cell-name')
          .locator('a')
          .click({ force: true });
        await expect(page).toHaveURL(
          '/-/secrets/native/org/github/github%2Fdeployment',
        );
      });
    });
  });
});
