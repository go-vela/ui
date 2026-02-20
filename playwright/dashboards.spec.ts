/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsByNumber, mockBuildsList, mockStepsList } from './utils/buildMocks';
import {
  mockDashboardDetail,
  mockDashboardDetailError,
  mockUserDashboards,
} from './utils/dashboardMocks';

test.describe('Dashboards', () => {
  test.describe('main dashboards page', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockUserDashboards(page, 'user_dashboards.json');
      await app.login('/dashboards');
    });

    test('shows the list of dashboards', async ({ page }) => {
      await expect(page.getByTestId('dashboard-item')).toHaveCount(2);
    });

    test('shows the repos within a dashboard', async ({ page }) => {
      await expect(page.getByTestId('dashboard-repos').first()).toContainText(
        'github/repo1',
      );
    });

    test('shows a message when there are no repos', async ({ page }) => {
      await expect(page.getByTestId('dashboard-repos').nth(1)).toContainText(
        'No repositories in this dashboard',
      );
    });

    test('clicking dashboard name navigates to dashboard page', async ({
      page,
    }) => {
      await page
        .getByTestId('dashboard-item')
        .first()
        .getByRole('link')
        .first()
        .click();
      await expect(page).toHaveURL(
        /\/dashboards\/6e26a6d0-2fc3-4531-a04d-678a58135288$/,
      );
    });
  });

  test.describe('server returning dashboard with 3 cards, one without builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockDashboardDetail(page, 'dashboard.json');
      await mockBuildsList(page, 'builds_5.json');
      await mockBuildsByNumber(page, { 25: 'build_success.json' });
      await mockStepsList(page);
      await app.login('/dashboards/86671eb5-a3ff-49e1-ad85-c3b2f648dcb2');
    });

    test('shows 3 dashboard cards', async ({ page }) => {
      await expect(page.getByTestId('dashboard-card')).toHaveCount(3);
    });

    test('shows an empty state when there are no builds', async ({ page }) => {
      await expect(page.getByTestId('dashboard-card').last()).toContainText(
        'waiting for builds',
      );
    });

    test('shows success build icon in header in the first card', async ({
      page,
    }) => {
      const firstHeaderIcon = page
        .getByTestId('dashboard-card')
        .first()
        .locator('header .-icon')
        .first();
      await expect(
        firstHeaderIcon,
      ).toHaveClass(/-success/);
    });

    test('shows failure build icon in header in the first card', async ({
      page,
    }) => {
      const secondHeaderIcon = page
        .getByTestId('dashboard-card')
        .nth(1)
        .locator('header .-icon')
        .first();
      await expect(
        secondHeaderIcon,
      ).toHaveClass(/-failure/);
    });

    test('org link in card header goes to org page', async ({ page }) => {
      await page.getByTestId('dashboard-card').first().locator('.card-org').click();
      await expect(page).toHaveURL(/\/github$/);
    });

    test('repo link in card header goes to repo page', async ({ page }) => {
      await page.getByTestId('dashboard-card').first().locator('.card-repo').click();
      await expect(page).toHaveURL(/\/github\/repo1$/);
    });

    test('build link in card goes to build page', async ({ page }) => {
      await page
        .getByTestId('dashboard-card')
        .first()
        .locator('.card-build-data li:first-child a')
        .click();
      await expect(page).toHaveURL(/\/github\/repo1\/25$/);
    });

    test('recent build link goes to respective build page', async ({ page }) => {
      await page.getByTestId('recent-build-link-25').click();
      await expect(page).toHaveURL(/\/github\/repo1\/25$/);
    });
  });

  test.describe('server returning dashboard without repos', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockDashboardDetail(page, 'dashboard_no_repos.json');
      await app.login('/dashboards/86671eb5-a3ff-49e1-ad85-c3b2f648dcb2');
    });

    test('shows message when there are no repositories added', async ({ page }) => {
      await expect(page.getByTestId('dashboard')).toContainText(
        "This dashboard doesn't have repositories added yet",
      );
    });
  });

  test.describe('dashboard not found', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockDashboardDetailError(page, 404);
      await app.login('/dashboards/deadbeef');
    });

    test('shows a not found message', async ({ page }) => {
      await expect(page.getByTestId('dashboard')).toContainText(
        'Dashboard "deadbeef" not found. Please check the URL.',
      );
    });
  });
});
