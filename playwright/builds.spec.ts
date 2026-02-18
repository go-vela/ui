/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockBuildsByNumber,
  mockBuildsErrors,
  mockBuildsFilter,
  mockBuildsList,
  mockBuildsListPaged,
  mockCancelBuild,
  mockRestartBuild,
} from './utils/buildMocks';

test.describe('Builds', () => {
  test.describe('server returning builds error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsErrors(page);
      await mockBuildsByNumber(page);
      await app.login('/github/octocat');
    });

    test('builds should not show', async ({ page }) => {
      await expect(page.getByTestId('builds')).not.toBeVisible();
    });

    test('error should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });

    test('error banner should show', async ({ page }) => {
      await expect(page.getByTestId('builds-error')).toContainText(
        'try again later',
      );
    });
  });

  test.describe('logged in and server returning 5 builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockBuildsList(page, 'builds_5.json');
      await mockCancelBuild(page, {
        status: 200,
        body: 'canceled build github/octocat/1',
      });
      await mockRestartBuild(page, {
        status: 200,
        payload: 'build_pending.json',
      });
      await app.login('/github/octocat');
    });

    test('builds should show', async ({ page }) => {
      await expect(page.getByTestId('builds')).toBeVisible();
    });

    test('cancel build button should be present when running', async ({
      page,
    }) => {
      const buildItems = page.getByTestId('builds').locator(':scope > *');

      await expect(
        buildItems.nth(0).locator('[data-test=cancel-build]'),
      ).toHaveCount(1);
      await expect(
        buildItems.nth(1).locator('[data-test=cancel-build]'),
      ).toHaveCount(0);
      await expect(
        buildItems.nth(2).locator('[data-test=cancel-build]'),
      ).toHaveCount(0);
      await expect(
        buildItems.nth(3).locator('[data-test=cancel-build]'),
      ).toHaveCount(0);
      await expect(
        buildItems.nth(4).locator('[data-test=cancel-build]'),
      ).toHaveCount(1);
    });

    test('build menu should expand and close when action is fired', async ({
      page,
    }) => {
      const firstBuild = page
        .getByTestId('builds')
        .locator(':scope > *')
        .first();
      const cancelBuild = firstBuild.getByTestId('cancel-build');
      const restartBuild = firstBuild.getByTestId('restart-build');

      await expect(cancelBuild).toBeHidden();
      await expect(restartBuild).toBeHidden();

      await firstBuild.getByTestId('build-menu').click();
      await expect(cancelBuild).toBeVisible();
      await expect(restartBuild).toBeVisible();

      await cancelBuild.click();
      await expect(cancelBuild).toBeHidden();
      await expect(restartBuild).toBeHidden();

      await firstBuild.getByTestId('build-menu').click();
      await expect(cancelBuild).toBeVisible();
      await expect(restartBuild).toBeVisible();

      await restartBuild.click();
      await expect(cancelBuild).toBeHidden();
      await expect(restartBuild).toBeHidden();
    });

    test('restart build button should be present', async ({ page }) => {
      await expect(page.getByTestId('restart-build')).not.toHaveCount(0);
    });

    test('builds should display commit message', async ({ page }) => {
      const firstBuild = page
        .getByTestId('builds')
        .locator(':scope > *')
        .first();
      await expect(firstBuild.locator('.commit-msg')).toBeVisible();
    });

    test('longer build commit message should be truncated with ellipsis', async ({
      page,
    }) => {
      const firstBuild = page
        .getByTestId('builds')
        .locator(':scope > *')
        .first();
      await expect(firstBuild.locator('.commit-msg')).toHaveCSS(
        'text-overflow',
        'ellipsis',
      );
    });

    test('timestamp checkbox should be present', async ({ page }) => {
      await expect(page.getByTestId('time-toggle')).toBeVisible();
    });

    test('timestamp checkbox switches time when checked', async ({ page }) => {
      const firstBuild = page
        .getByTestId('builds')
        .locator(':scope > *')
        .first();
      const age = firstBuild.locator('.time-info .age');

      await expect(age).not.toContainText(/\bat\b/);
      await expect(age).toHaveAttribute('title', /\bat\b/);

      await page.getByTestId('time-toggle').click({ force: true });

      await expect(age).toContainText(/\bat\b/);
      await expect(age).not.toHaveAttribute('title', /\bat\b/);
    });
  });

  test.describe('logged in and server returning 20 builds and running build', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsListPaged(page);
      await mockBuildsByNumber(page);
      await app.login('/github/octocat');
    });

    test('builds should show', async ({ page }) => {
      await expect(page.getByTestId('builds')).toBeVisible();
    });

    test('builds should show build number', async ({ page }) => {
      const buildItems = page.getByTestId('builds').locator(':scope > *');
      await expect(buildItems.first()).toContainText('#1');
      await expect(buildItems.last()).toContainText('#10');
    });

    test('build page 2 should show the next set of results', async ({
      page,
    }) => {
      await page.goto('/github/octocat?page=2');
      const buildItems = page.getByTestId('builds').locator(':scope > *');
      await expect(buildItems.first()).toContainText('#11');
      await expect(buildItems.last()).toContainText('#20');
      await expect(page.getByTestId('pager-next').first()).toBeDisabled();
    });

    test("loads the first page when hitting the 'previous' button", async ({
      page,
    }) => {
      await page.goto('/github/octocat');
      await page.getByTestId('pager-next').first().click();
      const previous = page.getByTestId('pager-previous').first();
      await expect(previous).toBeEnabled();
      await previous.click();
      await expect(page).toHaveURL(/\/github\/octocat(\?page=1)?$/);
    });

    test('builds should show commit hash', async ({ page }) => {
      const buildItems = page.getByTestId('builds').locator(':scope > *');
      await expect(buildItems.first()).toContainText('9b1d8bd');
      await expect(buildItems.last()).toContainText('7bd468e');
    });

    test('builds should show branch', async ({ page }) => {
      const buildItems = page.getByTestId('builds').locator(':scope > *');
      await expect(buildItems.first()).toContainText('infra');
      await expect(buildItems.last()).toContainText('terra');
    });

    test('build should having running style', async ({ page }) => {
      const firstBuild = page
        .getByTestId('builds')
        .locator(':scope > *')
        .first();
      await expect(firstBuild.getByTestId('build-status')).toHaveClass(
        /-running/,
      );
    });

    test('build should display commit message', async ({ page }) => {
      const buildItems = page.getByTestId('builds').locator(':scope > *');
      await expect(buildItems.first().locator('.commit-msg')).toBeVisible();
      await expect(buildItems.last().locator('.commit-msg')).toBeVisible();
    });

    test('longer build commit message should be truncated with ellipsis', async ({
      page,
    }) => {
      const buildItems = page.getByTestId('builds').locator(':scope > *');
      await expect(buildItems.first().locator('.commit-msg')).toHaveCSS(
        'text-overflow',
        'ellipsis',
      );
      await expect(buildItems.last().locator('.commit-msg')).toHaveCSS(
        'text-overflow',
        'ellipsis',
      );
    });

    test('clicking build number should redirect to build page', async ({
      page,
    }) => {
      const firstBuild = page
        .getByTestId('builds')
        .locator(':scope > *')
        .first();
      await firstBuild.getByTestId('build-number').first().click();
      await expect(page).toHaveURL(/\/github\/octocat\/1$/);
    });
  });

  test.describe('logged in and server returning builds error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsErrors(page);
      await app.login('/github/octocat');
    });

    test('error alert should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });
  });

  test.describe('logged out and server returning 10 builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsListPaged(page);
      await app.loggedOut('/github/octocat');
    });

    test('error alert should not show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).not.toContainText('Error');
    });

    test('builds should show login page', async ({ page }) => {
      await expect(page.locator('body')).toContainText('Authorize Via');
    });
  });

  test.describe('build filters', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsFilter(page);
      await app.login('/github/octocat');
    });

    test('renders builds filter', async ({ page }) => {
      await expect(page.getByTestId('build-filter')).toBeVisible();
    });

    test('shows all results by default', async ({ page }) => {
      await expect(page.getByTestId('build')).toHaveCount(11);
    });

    test('should only show 7 push events', async ({ page }) => {
      await page.getByTestId('build-filter-push').click({ force: true });
      await expect(page.getByTestId('build')).toHaveCount(7);
      await expect(page).toHaveURL(/\?event=push/);
    });

    test('should only show two pull events', async ({ page }) => {
      await page
        .getByTestId('build-filter-pull_request')
        .click({ force: true });
      await expect(page.getByTestId('build')).toHaveCount(2);
      await expect(page).toHaveURL(/\?event=pull_request/);
    });

    test('should only show one tag event', async ({ page }) => {
      await page.getByTestId('build-filter-tag').click({ force: true });
      await expect(page.getByTestId('build')).toHaveCount(1);
      await expect(page).toHaveURL(/\?event=tag/);
    });

    test('should show no results', async ({ page }) => {
      await page.getByTestId('build-filter-deployment').click({ force: true });
      await expect(page.getByTestId('build')).toHaveCount(0);
      await expect(page.locator('h3')).toContainText(
        'No builds for "deployment" event found.',
      );
      await expect(page).toHaveURL(/\?event=deployment/);
    });

    test('should only show one comment event', async ({ page }) => {
      await page.getByTestId('build-filter-comment').click({ force: true });
      await expect(page.getByTestId('build')).toHaveCount(1);
      await expect(page).toHaveURL(/\?event=comment/);
    });

    test('should only show two schedule event', async ({ page }) => {
      await page.getByTestId('build-filter-schedule').click({ force: true });
      await expect(page.getByTestId('build')).toHaveCount(2);
      await expect(page).toHaveURL(/\?event=schedule/);
    });
  });

  test.describe('build filter /pulls shortcut', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsFilter(page);
      await app.login('/github/octocat/pulls');
    });

    test('renders builds filter', async ({ page }) => {
      await expect(page.getByTestId('build-filter')).toBeVisible();
    });

    test('should only show two pull events', async ({ page }) => {
      await expect(page.getByTestId('build')).toHaveCount(2);
    });
  });

  test.describe('build filter /tags shortcut', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsFilter(page);
      await app.login('/github/octocat/tags');
    });

    test('renders builds filter', async ({ page }) => {
      await expect(page.getByTestId('build-filter')).toBeVisible();
    });

    test('should only show one tag event', async ({ page }) => {
      await expect(page.getByTestId('build')).toHaveCount(1);
    });
  });
});
