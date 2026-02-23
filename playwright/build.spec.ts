/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockApproveBuild,
  mockBuildErrors,
  mockBuildsByNumber,
  mockBuildsErrors,
  mockBuildsList,
  mockBuildsListPaged,
  mockCancelBuild,
  mockRestartBuild,
  mockStepsList,
  mockStepsErrors,
} from './utils/buildMocks';

test.describe('Build', () => {
  test.describe('logged in and server returning build error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildErrors(page);
      await mockBuildsErrors(page);
      await mockStepsErrors(page);
      await app.login('/github/octocat/1');
    });

    test('error alert should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });
  });

  test.describe('logged in and server returning 5 builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockBuildsList(page, 'builds_5.json');
      await app.login('/github/octocat/1');
    });

    test('build history should show', async ({ page }) => {
      await expect(page.getByTestId('build-history')).toBeVisible();
    });

    test('build history should have 5 builds', async ({ page }) => {
      const buildHistory = page.getByTestId('build-history');
      await expect(buildHistory).toBeVisible();
      await expect(buildHistory.locator(':scope > *')).toHaveCount(5);
    });

    test('clicking build history item should redirect to build page', async ({
      page,
    }) => {
      await page
        .getByTestId('recent-build-link-105')
        .locator(':scope > *')
        .last()
        .click();
      await expect(page).toHaveURL(/\/github\/octocat\/105$/);
    });
  });

  test.describe('logged in and server returning 0 builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockBuildsList(page, []);
      await app.login('/github/octocat/1');
    });

    test('build history should not show', async ({ page }) => {
      await expect(page.getByTestId('build-history')).toHaveCount(0);
    });
  });

  test.describe('logged in and server returning builds and single build', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockBuildsListPaged(page);
      await mockStepsList(page);
      await app.login('/github/octocat/1');
    });

    test.describe('server returning 55 builds', () => {
      test('build history should show', async ({ page }) => {
        await expect(page.getByTestId('build-history')).toBeVisible();
      });

      test('build history should have 10 builds', async ({ page }) => {
        const buildHistory = page.getByTestId('build-history');
        await expect(buildHistory).toBeVisible();
        await expect(buildHistory.locator(':scope > *')).toHaveCount(10);
      });

      test('clicking build history item should redirect to build page', async ({
        page,
      }) => {
        await page
          .getByTestId('recent-build-link-1')
          .locator(':scope > *')
          .last()
          .click();
        await expect(page).toHaveURL(/\/github\/octocat\/1$/);
      });

      test.describe('hover build history item', () => {
        test('should show build event', async ({ page }) => {
          await expect(
            page.getByTestId('build-history-tooltip').last(),
          ).toContainText('push');
        });

        test('should show build number', async ({ page }) => {
          await expect(
            page.getByTestId('build-history-tooltip').last(),
          ).toContainText('10');
        });

        test('should show build times', async ({ page }) => {
          const tooltip = page.getByTestId('build-history-tooltip').last();
          await expect(tooltip).toContainText('started');
          await expect(tooltip).toContainText('finished');
        });

        test('should show commit', async ({ page }) => {
          const tooltip = page.getByTestId('build-history-tooltip').last();
          await expect(tooltip).toContainText('commit');
          await expect(tooltip).toContainText('7bd468e');
        });

        test('should show branch', async ({ page }) => {
          const tooltip = page.getByTestId('build-history-tooltip').last();
          await expect(tooltip).toContainText('branch');
          await expect(tooltip).toContainText('terra');
        });

        test('should show worker', async ({ page }) => {
          const tooltip = page.getByTestId('build-history-tooltip').last();
          await expect(tooltip).toContainText('worker');
          await expect(tooltip).toContainText('https://vela-worker-6.com');
        });

        test('should show route', async ({ page }) => {
          const tooltip = page.getByTestId('build-history-tooltip').last();
          await expect(tooltip).toContainText('route');
          await expect(tooltip).toContainText('vela');
        });
      });
    });

    test.describe('server stubbed Restart Build', () => {
      test.beforeEach(async ({ page }) => {
        await mockRestartBuild(page, {
          status: 200,
          payload: 'build_pending.json',
        });
      });

      test('clicking restart build should show alert', async ({ page }) => {
        await page.getByTestId('restart-build').click();
        await expect(page.getByTestId('alert')).toContainText(
          'Restarted build github/octocat/1',
        );
      });

      test('clicking restarted build link should redirect to Build page', async ({
        page,
      }) => {
        await page.getByTestId('restart-build').click();
        await page.getByTestId('alert-hyperlink').click();
        await expect(page).toHaveURL(/\/github\/octocat\/2$/);
      });
    });

    test.describe('server failing to restart build', () => {
      test.beforeEach(async ({ page }) => {
        await mockRestartBuild(page, {
          status: 500,
        });
      });

      test('clicking restart build should show error alert', async ({
        page,
      }) => {
        await page.getByTestId('restart-build').click();
        await expect(page.getByTestId('alert')).toContainText('Error');
      });
    });

    test.describe('server stubbed Cancel Build', () => {
      test.beforeEach(async ({ page }) => {
        await mockCancelBuild(page, {
          status: 200,
          body: 'canceled build github/octocat/1',
        });
      });

      test('clicking cancel build should show alert', async ({ page }) => {
        await page.getByTestId('cancel-build').click();
        await expect(page.getByTestId('alert')).toContainText(
          'Canceled build github/octocat/1.',
        );
      });
    });

    test.describe('server failing to cancel build', () => {
      test.beforeEach(async ({ page }) => {
        await mockCancelBuild(page, {
          status: 500,
          body: 'server error',
        });
      });

      test('clicking cancel build should show error alert', async ({
        page,
      }) => {
        await page.getByTestId('cancel-build').click();
        await expect(page.getByTestId('alert')).toContainText('Error');
      });
    });

    test.describe('server stubbed Approve Build', () => {
      test.beforeEach(async ({ page }) => {
        await mockApproveBuild(page, {
          status: 200,
          body: 'Successfully approved build github/octocat/8',
        });
        await page.goto('/github/octocat/8');
      });

      test('there should be a notice banner', async ({ page }) => {
        await expect(page.getByTestId('approve-build-notice')).toBeVisible();
      });

      test('clicking cancel build should show alert', async ({ page }) => {
        await page.getByTestId('approve-build').click();
        await expect(page.getByTestId('alert')).toContainText(
          'Approved build github/octocat/8.',
        );
      });
    });

    test.describe('server stubbed Approved Build', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/9');
      });

      test('should show who approved the build', async ({ page }) => {
        await expect(page.getByTestId('git-info')).toContainText(
          'approved by gh0st',
        );
      });

      test('sha should link to the commit in the PR', async ({ page }) => {
        await expect(page.getByTestId('commit-link')).toHaveAttribute(
          'href',
          /pull\/42\/commits\//,
        );
      });
    });

    test.describe('visit running build', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/1');
      });

      test('build should show', async ({ page }) => {
        await expect(page.getByTestId('build')).toBeVisible();
      });

      test('build should show commit hash', async ({ page }) => {
        await expect(page.getByTestId('build')).toContainText('9b1d8bd');
      });

      test('build should show branch', async ({ page }) => {
        await expect(page.getByTestId('build')).toContainText('infra');
      });

      test('build should have running style', async ({ page }) => {
        await expect(page.getByTestId('build-status')).toHaveClass(/-running/);
      });

      test('build should display commit message', async ({ page }) => {
        await expect(
          page.getByTestId('build').locator('.commit-msg'),
        ).toBeVisible();
      });

      test('longer build commit message should be truncated with ellipsis', async ({
        page,
      }) => {
        await expect(
          page.getByTestId('build').locator('.commit-msg'),
        ).toHaveCSS('text-overflow', 'ellipsis');
      });

      test('build should annotate the age with the full timestamp', async ({
        page,
      }) => {
        await expect(
          page.getByTestId('build').locator('.time-info .age'),
        ).toHaveAttribute('title', /.+/);
      });
    });

    test.describe('visit pending build', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/2');
      });

      test('build should have pending style', async ({ page }) => {
        await expect(page.getByTestId('build-status')).toHaveClass(/-pending/);
      });
    });

    test.describe('visit success build', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/3');
      });

      test('build should have success style', async ({ page }) => {
        await expect(page.getByTestId('build-status')).toHaveClass(/-success/);
      });
    });

    test.describe('visit failure build', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/4');
      });

      test('build should have failure style', async ({ page }) => {
        await expect(page.getByTestId('build-status')).toHaveClass(/-failure/);
      });
    });

    test.describe('visit build with server error', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/5');
      });

      test('build should have error style', async ({ page }) => {
        await expect(page.getByTestId('build-status')).toHaveClass(/-error/);
      });

      test('build error should show', async ({ page }) => {
        await expect(page.getByTestId('build-error')).toBeVisible();
      });

      test('build error should contain error', async ({ page }) => {
        const buildError = page.getByTestId('build-error');
        await expect(buildError).toContainText('error:');
        await expect(buildError).toContainText('failure authenticating');
      });
    });

    test.describe('visit canceled build', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/6');
      });

      test('build should have canceled style', async ({ page }) => {
        await expect(page.getByTestId('build-status')).toHaveClass(/-canceled/);
      });

      test('build error should show', async ({ page }) => {
        await expect(page.getByTestId('build-error')).toBeVisible();
      });

      test('build error should contain error', async ({ page }) => {
        const buildError = page.getByTestId('build-error');
        await expect(buildError).toContainText('auto canceled:');
        await expect(buildError).toContainText(
          'build auto canceled in favor of build #7',
        );
      });

      test('clicking superseding build link should direct to new build page', async ({
        page,
      }) => {
        await page.getByTestId('new-build-link').click();
        await expect(page).toHaveURL(/\/github\/octocat\/7$/);
      });
    });
  });
});
