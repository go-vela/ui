/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import {
  mockRepoChown,
  mockRepoChownError,
  mockRepoDetail,
  mockRepoDisable,
  mockRepoEnable,
  mockRepoRepair,
  mockRepoRepairError,
  mockRepoUpdate,
} from './utils/repoMocks';
import {
  repoChownPattern,
  repoDetailPattern,
  repoEnablePattern,
  repoRepairPattern,
} from './utils/routes';
import { readTestData } from './utils/testData';

async function clickAndWaitForRepoUpdate(
  page: Page,
  action: () => Promise<void>,
): Promise<void> {
  await Promise.all([
    page.waitForResponse(
      response =>
        repoDetailPattern.test(response.url()) &&
        response.request().method() === 'PUT',
    ),
    action(),
  ]);
}

test.describe('Repo Settings', () => {
  test.describe('server returning bad repo', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockRepoUpdate(page, 'repository_updated.json');
      await mockRepoDetail(page, 'repository_bad.json');
      await app.login('/github/octocatbad/settings');
    });

    test('should show an error', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });
  });

  test.describe('server returning repo', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockRepoUpdate(page, 'repository_updated.json');
      await mockRepoDetail(page, 'repository.json');
      await mockRepoDisable(page, 'Repo github/octocat deleted');
      await mockRepoEnable(page, 'enable_repo_response.json');
      await mockRepoChown(page, 'Repo github/octocat changed owner');
      await mockRepoRepair(page, 'Repo github/octocat repaired.');
      await app.login('/github/octocat/settings');
    });

    test('approval timeout should show', async ({ page }) => {
      await expect(page.getByTestId('repo-approval-timeout')).toBeVisible();
    });

    test('build limit input should show', async ({ page }) => {
      await expect(page.getByTestId('repo-limit')).toBeVisible();
    });

    test('build timeout input should show', async ({ page }) => {
      await expect(page.getByTestId('repo-timeout')).toBeVisible();
    });

    test('build counter input should show', async ({ page }) => {
      await expect(page.getByTestId('repo-counter')).toBeVisible();
    });

    test('webhook event category should show', async ({ page }) => {
      await expect(page.getByTestId('repo-settings-events')).toBeVisible();
    });

    test('allow_push_branch checkbox should show', async ({ page }) => {
      await expect(
        page.getByTestId('checkbox-allow-events-push-branch-allow_push_branch'),
      ).toBeVisible();
    });

    test('clicking allow_push_branch checkbox should toggle the value', async ({
      page,
    }) => {
      const checkbox = page.getByTestId(
        'checkbox-allow-events-push-branch-allow_push_branch',
      );
      const input = checkbox.locator('input[type="checkbox"]');

      await expect(input).toBeChecked();
      await clickAndWaitForRepoUpdate(page, () =>
        checkbox.locator('label').click({ force: true }),
      );
      await expect(input).not.toBeChecked();
    });

    test('clicking access radio should toggle both values', async ({
      page,
    }) => {
      const radio = page.getByTestId('radio-access-private');
      const input = radio.locator('input[type="radio"]');

      await expect(input).not.toBeChecked();
      await clickAndWaitForRepoUpdate(page, () =>
        radio.locator('label').click({ force: true }),
      );
      await expect(input).toBeChecked();
    });

    test('clicking outside contributor approval policy should toggle', async ({
      page,
    }) => {
      const radio = page.getByTestId('radio-policy-fork-no-write');
      const input = radio.locator('input[type="radio"]');

      await expect(input).not.toBeChecked();
      await clickAndWaitForRepoUpdate(page, () =>
        radio.locator('label').click({ force: true }),
      );
      await expect(input).toBeChecked();
    });

    test('clicking pipeline type radio should toggle all values', async ({
      page,
    }) => {
      const repo = readTestData('repository.json') as Record<string, unknown>;
      const updatedRepo = { ...repo, pipeline_type: 'go' };

      await page.unroute(repoDetailPattern);
      await mockRepoDetail(page, repo);
      await mockRepoUpdate(page, updatedRepo);

      const radio = page.getByTestId('radio-type-go');
      const input = radio.locator('input[type="radio"]');

      await expect(input).not.toBeChecked();
      await clickAndWaitForRepoUpdate(page, () =>
        radio.locator('label').click({ force: true }),
      );
      await expect(input).toBeChecked();
    });

    test('approval timeout input should allow number input', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-approval-timeout').locator('input');
      await input.fill('123');
      await expect(input).toHaveValue('123');
    });

    test('approval timeout input should not allow letter/character input', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-approval-timeout').locator('input');

      await input.fill('');
      await input.type('cat');
      await expect(input).not.toHaveValue('cat');

      await input.fill('');
      await input.type('12cat34');
      await expect(input).toHaveValue('1234');
    });

    test('clicking update on approval timeout should update timeout and hide button', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-approval-timeout').locator('input');
      const button = page.locator('[data-test=repo-approval-timeout] + button');

      await input.fill('80');
      await expect(button).toBeVisible();
      await button.click({ force: true });
      await expect(button).toBeDisabled();
    });

    test('build limit input should allow number input', async ({ page }) => {
      const input = page.getByTestId('repo-limit').locator('input');
      await input.fill('123');
      await expect(input).toHaveValue('123');
    });

    test('build limit input should not allow letter/character input', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-limit').locator('input');

      await input.fill('');
      await input.type('cat');
      await expect(input).not.toHaveValue('cat');

      await input.fill('');
      await input.type('12cat34');
      await expect(input).toHaveValue('1234');
    });

    test('clicking update on build limit should update limit and hide button', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-limit').locator('input');
      const button = page.locator('[data-test=repo-limit] + button');

      await input.fill('80');
      await expect(button).toBeVisible();
      await button.click({ force: true });
      await expect(button).toBeDisabled();
    });

    test('build timeout input should allow number input', async ({ page }) => {
      const input = page.getByTestId('repo-timeout').locator('input');
      await input.fill('123');
      await expect(input).toHaveValue('123');
    });

    test('build timeout input should not allow letter/character input', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-timeout').locator('input');

      await input.fill('');
      await input.type('cat');
      await expect(input).not.toHaveValue('cat');

      await input.fill('');
      await input.type('12cat34');
      await expect(input).toHaveValue('1234');
    });

    test('clicking update on build timeout should update timeout and hide button', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-timeout').locator('input');
      const button = page.locator('[data-test=repo-timeout] + button');

      await input.fill('91');
      await expect(button).toBeVisible();
      await button.click({ force: true });
      await expect(button).toBeDisabled();
    });

    test('build counter input should allow number input', async ({ page }) => {
      const input = page.getByTestId('repo-counter').locator('input');
      await input.fill('123');
      await expect(input).toHaveValue('123');
    });

    test('build counter input should not allow letter/character input', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-counter').locator('input');

      await input.fill('');
      await input.type('cat');
      await expect(input).not.toHaveValue('cat');

      await input.fill('');
      await input.type('12cat34');
      await expect(input).toHaveValue('1234');
    });

    test('clicking update on build counter should update counter and hide button', async ({
      page,
    }) => {
      const input = page.getByTestId('repo-counter').locator('input');
      const button = page.locator('[data-test=repo-counter] + button');

      await input.fill('80');
      await expect(button).toBeVisible();
      await button.click({ force: true });
      await expect(button).toBeDisabled();
    });

    test('Disable button should exist', async ({ page }) => {
      await expect(page.getByTestId('repo-disable')).toBeVisible();
    });

    test('clicking button should prompt disable confirmation', async ({
      page,
    }) => {
      await page.getByTestId('repo-disable').first().click({ force: true });
      await expect(page.getByTestId('repo-disable')).toContainText(
        'Confirm Disable',
      );
    });

    test('clicking button twice should disable the repo', async ({ page }) => {
      const disableButton = page.getByTestId('repo-disable').first();

      await disableButton.click({ force: true });
      await Promise.all([
        page.waitForResponse(
          response =>
            repoDetailPattern.test(response.url()) &&
            response.request().method() === 'DELETE',
        ),
        disableButton.click({ force: true }),
      ]);

      await expect(page.getByTestId('repo-enable')).toContainText('Enable');
    });

    test('clicking button three times should re-enable the repo', async ({
      page,
    }) => {
      const disableButton = page.getByTestId('repo-disable').first();

      await disableButton.click({ force: true });
      await Promise.all([
        page.waitForResponse(
          response =>
            repoDetailPattern.test(response.url()) &&
            response.request().method() === 'DELETE',
        ),
        disableButton.click({ force: true }),
      ]);

      const enableButton = page.getByTestId('repo-enable').first();
      await Promise.all([
        page.waitForResponse(
          response =>
            repoEnablePattern.test(response.url()) &&
            response.request().method() === 'POST',
        ),
        enableButton.click({ force: true }),
      ]);

      await expect(page.getByTestId('repo-disable')).toContainText('Disable');
    });

    test('should show an success alert on successful removal of a repo', async ({
      page,
    }) => {
      const disableButton = page.getByTestId('repo-disable').first();

      await disableButton.click({ force: true });
      await Promise.all([
        page.waitForResponse(
          response =>
            repoDetailPattern.test(response.url()) &&
            response.request().method() === 'DELETE',
        ),
        disableButton.click({ force: true }),
      ]);

      await expect(page.getByTestId('alerts')).toContainText('Success');
    });

    test('should copy markdown to clipboard and alert', async ({ page }) => {
      await page.getByTestId('copy-md').click({ force: true });
      await expect(page.getByTestId('alerts')).toContainText('copied');
    });

    test('Chown button should exist', async ({ page }) => {
      await expect(page.getByTestId('repo-chown')).toBeVisible();
    });

    test('should show an success alert on successful chown of a repo', async ({
      page,
    }) => {
      await page.getByTestId('repo-chown').click({ force: true });
      await expect(page.getByTestId('alerts')).toContainText('Success');
    });

    test('should show an error alert on failed chown of a repo', async ({
      page,
    }) => {
      await page.unroute(repoChownPattern);
      await mockRepoChownError(page, 500, 'Unable to...');

      await page.getByTestId('repo-chown').click({ force: true });
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });

    test('Repair button should exist', async ({ page }) => {
      await expect(page.getByTestId('repo-repair')).toBeVisible();
    });

    test('should show an success alert on successful repair of a repo', async ({
      page,
    }) => {
      await page.getByTestId('repo-repair').click({ force: true });
      await expect(page.getByTestId('alerts')).toContainText('Success');
      await expect(page.getByTestId('repo-disable')).toContainText('Disable');
    });

    test('should show an error alert on a failed repair of a repo', async ({
      page,
    }) => {
      await page.unroute(repoRepairPattern);
      await mockRepoRepairError(page, 500, 'Unable to...');

      await page.getByTestId('repo-repair').click({ force: true });
      await expect(page.getByTestId('alerts')).toContainText('Error');
      await expect(page.getByTestId('repo-disable')).toContainText('Disable');
    });
  });

  test.describe('server returning inactive repo', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockRepoDetail(page, 'repository_inactive.json');
      await mockRepoRepair(page, 'Repo github/octocat repaired.');
      await app.login('/github/octocat/settings');
    });

    test('should show enable button', async ({ page }) => {
      await expect(page.getByTestId('repo-enable')).toContainText('Enable');
    });

    test('failed repair keeps enable button enabled', async ({ page }) => {
      await page.unroute(repoRepairPattern);
      await mockRepoRepairError(page, 500, 'Unable to...');

      await page.getByTestId('repo-repair').click({ force: true });
      await expect(page.getByTestId('alerts')).toContainText('Error');
      await expect(page.getByTestId('repo-enable')).toContainText('Enable');
    });
  });
});
