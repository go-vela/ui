/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsByNumber } from './utils/buildMocks';
import {
  mockServiceLog,
  mockServicesWithAnsiLogs,
  mockStepLog,
  mockStepsWithAnsiLogs,
  mockStepsWithLargeLogs,
  mockStepsWithLinkedLogs,
  mockStepsWithSkippedAndMissingLogs,
} from './utils/logMocks';
import { serviceLogsPattern, stepLogsPattern } from './utils/routes';

const waitForStepLogs = async (
  page: { waitForResponse: (arg0: RegExp) => Promise<unknown> },
  step: number,
) => page.waitForResponse(stepLogsPattern(step));

const waitForServiceLogs = async (
  page: { waitForResponse: (arg0: RegExp) => Promise<unknown> },
  service: number,
) => page.waitForResponse(serviceLogsPattern(service));

const stepDetails = (
  page: { getByTestId: (id: string) => any },
  step: number,
) =>
  page.getByTestId(`step-header-${step}`).locator('xpath=ancestor::details[1]');

const serviceDetails = (
  page: { getByTestId: (id: string) => any },
  service: number,
) =>
  page
    .getByTestId(`service-header-${service}`)
    .locator('xpath=ancestor::details[1]');

const expectTrackerInView = async (
  page: { getByTestId: (id: string) => any },
  testId: string,
) => {
  await expect(page.getByTestId(testId)).toBeInViewport();
};

const expectLogsScrolledToBottom = async (
  page: {
    evaluate: (
      fn: (logTestId: string) => number | null,
      arg: string,
    ) => Promise<number | null>;
  },
  logTestId: string,
) => {
  await expect
    .poll(async () =>
      page.evaluate(testId => {
        const container = document.querySelector(
          `[data-test="${testId}"]`,
        ) as HTMLElement | null;
        if (!container) {
          return null;
        }
        const maxScroll = container.scrollHeight - container.clientHeight;
        return maxScroll > 0 ? container.scrollTop - maxScroll : 0;
      }, logTestId),
    )
    .toBeGreaterThanOrEqual(-2);
};

test.describe('Logs', () => {
  test.describe('visit Build with steps and ansi encoded logs using url line fragment', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockStepsWithAnsiLogs(page);
      await app.login('/github/octocat/1');
      await page.getByTestId('step-header-2').click({ force: true });
      await page.getByTestId('step-header-2').click({ force: true });
      await page.goto('/github/octocat/1#2:31');
      await page.reload();
      await waitForStepLogs(page, 2);
    });

    test('line should not contain ansi characters', async ({ page }) => {
      await expect(
        page.getByTestId('log-line-2-1').locator('.ansi-red-fg'),
      ).toHaveCount(0);
    });

    test('line should contain ansi color css', async ({ page }) => {
      const line = page.getByTestId('log-line-2-2');
      await expect(line.locator('.ansi-green-fg')).toHaveCount(1);
      await expect(line.locator('.ansi-red-fg')).toHaveCount(1);
      await expect(line.locator('.ansi-bright-black-fg')).toHaveCount(1);
    });

    test('ansi fg classes should change css color', async ({ page }) => {
      const line = page.getByTestId('log-line-2-2');
      await expect(line.locator('.ansi-green-fg')).toHaveCSS(
        'color',
        'rgb(125, 209, 35)',
      );
      await expect(line.locator('.ansi-red-fg')).toHaveCSS(
        'color',
        'rgb(235, 102, 117)',
      );
    });

    test('line should respect ansi font style', async ({ page }) => {
      await expect(
        page.getByTestId('log-line-2-3').locator('.ansi-bold'),
      ).toHaveCount(1);
    });

    test('build should have collapse/expand actions', async ({ page }) => {
      const actions = page.getByTestId('log-actions');
      await expect(actions.getByTestId('collapse-all')).toHaveCount(1);
      await expect(actions.getByTestId('expand-all')).toHaveCount(1);
    });

    test('click collapse all should collapse all steps', async ({ page }) => {
      await page.getByTestId('expand-all').click({ force: true });

      await expect(stepDetails(page, 1)).toHaveJSProperty('open', true);
      await expect(stepDetails(page, 2)).toHaveJSProperty('open', true);
      await expect(stepDetails(page, 3)).toHaveJSProperty('open', true);

      await page.getByTestId('collapse-all').click({ force: true });

      await expect(stepDetails(page, 1)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 2)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 3)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 4)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 5)).toHaveJSProperty('open', false);
    });

    test('click expand all should expand all steps', async ({ page }) => {
      await page.getByTestId('step-header-2').click({ force: true });

      await expect(stepDetails(page, 1)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 2)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 3)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 4)).toHaveJSProperty('open', false);
      await expect(stepDetails(page, 5)).toHaveJSProperty('open', false);

      await page.getByTestId('expand-all').click({ force: true });
      await waitForStepLogs(page, 2);

      await expect(stepDetails(page, 1)).toHaveJSProperty('open', true);
      await expect(stepDetails(page, 2)).toHaveJSProperty('open', true);
      await expect(stepDetails(page, 3)).toHaveJSProperty('open', true);
      await expect(stepDetails(page, 4)).toHaveJSProperty('open', true);
      await expect(stepDetails(page, 5)).toHaveJSProperty('open', true);
    });

    test('log should have top and side log actions', async ({ page }) => {
      const logs = page.getByTestId('logs-2');
      await expect(logs.getByTestId('logs-header-actions-2')).toHaveCount(1);
      await expect(logs.getByTestId('logs-sidebar-actions-2')).toHaveCount(1);
    });

    test.describe('log with > 25 lines (long)', () => {
      test('top log actions should contain appropriate log actions', async ({
        page,
      }) => {
        const actions = page.getByTestId('logs-header-actions-2');
        await expect(actions.getByTestId('jump-to-bottom-2')).toHaveCount(0);
        await expect(actions.getByTestId('download-logs-2')).toHaveCount(1);
        await expect(actions.getByTestId('follow-logs-2')).toHaveCount(0);
      });

      test('sidebar should contain appropriate actions', async ({ page }) => {
        const actions = page.getByTestId('logs-sidebar-actions-2');
        await expect(actions.getByTestId('jump-to-top-2')).toHaveCount(1);
        await expect(actions.getByTestId('jump-to-bottom-2')).toHaveCount(1);
        await expect(actions.getByTestId('follow-logs-2')).toHaveCount(1);
      });

      test('should have trackers', async ({ page }) => {
        const logs = page.getByTestId('logs-2');
        await expect(logs.getByTestId('bottom-log-tracker-2')).toHaveCount(1);
        await expect(logs.getByTestId('top-log-tracker-2')).toHaveCount(1);
      });

      test('bottom tracker should not have focus', async ({ page }) => {
        await expect(
          page.getByTestId('bottom-log-tracker-2'),
        ).not.toBeFocused();
      });

      test('click jump to bottom should focus bottom tracker', async ({
        page,
      }) => {
        await page.getByTestId('jump-to-bottom-2').click({ force: true });
        await expectLogsScrolledToBottom(page, 'logs-2');
      });

      test('top tracker should not have focus', async ({ page }) => {
        await expect(page.getByTestId('top-log-tracker-2')).not.toBeFocused();
      });

      test('click jump to top should focus top tracker', async ({ page }) => {
        await page.getByTestId('jump-to-top-2').click({ force: true });
        await expectTrackerInView(page, 'top-log-tracker-2');
      });

      test('click follow logs should focus follow new logs', async ({
        page,
      }) => {
        await expect(
          page.getByTestId('bottom-log-tracker-2'),
        ).not.toBeFocused();
        await mockStepLog(page, 2, 'log_step_long.json', { times: 1 });
        await Promise.all([
          waitForStepLogs(page, 2),
          page.getByTestId('follow-logs-2').first().click({ force: true }),
        ]);

        await expectLogsScrolledToBottom(page, 'logs-2');
      });
    });

    test.describe('log with < 25 lines (short)', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('step-header-5').click({ force: true });
      });

      test('logs header should contain limited actions', async ({ page }) => {
        const actions = page.getByTestId('logs-header-actions-5');
        await expect(actions.getByTestId('jump-to-bottom-5')).toHaveCount(0);
        await expect(actions.getByTestId('jump-to-top-5')).toHaveCount(0);
        await expect(actions.getByTestId('download-logs-5')).toHaveCount(1);
      });
    });

    test.describe('log with no data (empty log)', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('step-header-1').click({ force: true });
      });

      test('logs header actions should exist', async ({ page }) => {
        await expect(page.getByTestId('logs-header-actions-1')).toBeVisible();
      });

      test('download button should not be visible', async ({ page }) => {
        await expect(page.getByTestId('download-logs-1')).not.toBeVisible();
      });

      test('logs data should contain helpful message', async ({ page }) => {
        await expect(page.getByTestId('log-line-1-1')).toContainText(
          'The build has not written anything to this log yet.',
        );
      });

      test('logs sidebar actions should be visible', async ({ page }) => {
        await expect(page.getByTestId('logs-sidebar-actions-1')).toBeVisible();
      });
    });
  });

  test.describe('visit Build with services and ansi encoded logs using url line fragment', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockServicesWithAnsiLogs(page);
      await app.login('/github/octocat/1/services');
      await page.getByTestId('service-header-2').click({ force: true });
      await page.getByTestId('service-header-2').click({ force: true });
      await page.goto('/github/octocat/1/services#2:31');
      await page.reload();
      await waitForServiceLogs(page, 2);
    });

    test('line should not contain ansi characters', async ({ page }) => {
      await expect(
        page.getByTestId('log-line-2-1').locator('.ansi-red-fg'),
      ).toHaveCount(0);
    });

    test('line should contain ansi color css', async ({ page }) => {
      const line = page.getByTestId('log-line-2-2');
      await expect(line.locator('.ansi-green-fg')).toHaveCount(1);
      await expect(line.locator('.ansi-red-fg')).toHaveCount(1);
      await expect(line.locator('.ansi-bright-black-fg')).toHaveCount(1);
    });

    test('ansi fg classes should change css color', async ({ page }) => {
      const line = page.getByTestId('log-line-2-2');
      await expect(line.locator('.ansi-green-fg')).toHaveCSS(
        'color',
        'rgb(125, 209, 35)',
      );
      await expect(line.locator('.ansi-red-fg')).toHaveCSS(
        'color',
        'rgb(235, 102, 117)',
      );
    });

    test('line should respect ansi font style', async ({ page }) => {
      await expect(
        page.getByTestId('log-line-2-3').locator('.ansi-bold'),
      ).toHaveCount(1);
    });

    test('build services should have collapse/expand actions', async ({
      page,
    }) => {
      const actions = page.getByTestId('log-actions');
      await expect(actions.getByTestId('collapse-all')).toHaveCount(1);
      await expect(actions.getByTestId('expand-all')).toHaveCount(1);
    });

    test('click collapse all should collapse all services', async ({
      page,
    }) => {
      await page.getByTestId('expand-all').click({ force: true });

      await expect(serviceDetails(page, 1)).toHaveJSProperty('open', true);
      await expect(serviceDetails(page, 2)).toHaveJSProperty('open', true);
      await expect(serviceDetails(page, 3)).toHaveJSProperty('open', true);

      await page.getByTestId('collapse-all').click({ force: true });

      await expect(serviceDetails(page, 1)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 2)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 3)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 4)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 5)).toHaveJSProperty('open', false);
    });

    test('click expand all should expand all services', async ({ page }) => {
      await page.getByTestId('service-header-2').click({ force: true });

      await expect(serviceDetails(page, 1)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 2)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 3)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 4)).toHaveJSProperty('open', false);
      await expect(serviceDetails(page, 5)).toHaveJSProperty('open', false);

      await page.getByTestId('expand-all').click({ force: true });
      await waitForServiceLogs(page, 2);

      await expect(serviceDetails(page, 1)).toHaveJSProperty('open', true);
      await expect(serviceDetails(page, 2)).toHaveJSProperty('open', true);
      await expect(serviceDetails(page, 3)).toHaveJSProperty('open', true);
      await expect(serviceDetails(page, 4)).toHaveJSProperty('open', true);
      await expect(serviceDetails(page, 5)).toHaveJSProperty('open', true);
    });

    test('log should have top and side log actions', async ({ page }) => {
      const logs = page.getByTestId('logs-2');
      await expect(logs.getByTestId('logs-header-actions-2')).toHaveCount(1);
      await expect(logs.getByTestId('logs-sidebar-actions-2')).toHaveCount(1);
    });

    test.describe('log with > 25 lines (long)', () => {
      test('top log actions should contain appropriate log actions', async ({
        page,
      }) => {
        const actions = page.getByTestId('logs-header-actions-2');
        await expect(actions.getByTestId('jump-to-bottom-2')).toHaveCount(0);
        await expect(actions.getByTestId('download-logs-2')).toHaveCount(1);
        await expect(actions.getByTestId('follow-logs-2')).toHaveCount(0);
      });

      test('sidebar should contain appropriate actions', async ({ page }) => {
        const actions = page.getByTestId('logs-sidebar-actions-2');
        await expect(actions.getByTestId('jump-to-top-2')).toHaveCount(1);
        await expect(actions.getByTestId('jump-to-bottom-2')).toHaveCount(1);
        await expect(actions.getByTestId('follow-logs-2')).toHaveCount(1);
      });

      test('should have trackers', async ({ page }) => {
        const logs = page.getByTestId('logs-2');
        await expect(logs.getByTestId('bottom-log-tracker-2')).toHaveCount(1);
        await expect(logs.getByTestId('top-log-tracker-2')).toHaveCount(1);
      });

      test('bottom tracker should not have focus', async ({ page }) => {
        await expect(
          page.getByTestId('bottom-log-tracker-2'),
        ).not.toBeFocused();
      });

      test('click jump to bottom should focus bottom tracker', async ({
        page,
      }) => {
        await page.getByTestId('jump-to-bottom-2').click({ force: true });
        await expectLogsScrolledToBottom(page, 'logs-2');
      });

      test('top tracker should not have focus', async ({ page }) => {
        await expect(page.getByTestId('top-log-tracker-2')).not.toBeFocused();
      });

      test('click jump to top should focus top tracker', async ({ page }) => {
        await page.getByTestId('jump-to-top-2').click({ force: true });
        await expectTrackerInView(page, 'top-log-tracker-2');
      });

      test('click follow logs should focus follow new logs', async ({
        page,
      }) => {
        await expect(
          page.getByTestId('bottom-log-tracker-2'),
        ).not.toBeFocused();
        await mockServiceLog(page, 2, 'log_service_long.json', { times: 1 });
        await Promise.all([
          waitForServiceLogs(page, 2),
          page.getByTestId('follow-logs-2').first().click({ force: true }),
        ]);

        await expectLogsScrolledToBottom(page, 'logs-2');
      });
    });

    test.describe('log with < 25 lines (short)', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('service-header-5').click({ force: true });
      });

      test('logs header should contain limited actions', async ({ page }) => {
        const actions = page.getByTestId('logs-header-actions-5');
        await expect(actions.getByTestId('jump-to-bottom-5')).toHaveCount(0);
        await expect(actions.getByTestId('jump-to-top-5')).toHaveCount(0);
        await expect(actions.getByTestId('download-logs-5')).toHaveCount(1);
      });
    });

    test.describe('log with no data (empty log)', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('service-header-1').click({ force: true });
      });

      test('logs header actions should exist', async ({ page }) => {
        await expect(page.getByTestId('logs-header-actions-1')).toBeVisible();
      });

      test('download button should not be visible', async ({ page }) => {
        await expect(page.getByTestId('download-logs-1')).not.toBeVisible();
      });

      test('logs data should contain helpful message', async ({ page }) => {
        await expect(page.getByTestId('log-line-1-1')).toContainText(
          'The build has not written anything to this log yet.',
        );
      });

      test('logs sidebar actions should be visible', async ({ page }) => {
        await expect(page.getByTestId('logs-sidebar-actions-1')).toBeVisible();
      });
    });
  });

  test.describe('visit Build with steps and large logs', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockStepsWithLargeLogs(page);
      await app.login('/github/octocat/1');
      await page.getByTestId('step-header-1').click({ force: true });
    });

    test('line should contain size exceeded message', async ({ page }) => {
      await expect(page.getByTestId('log-line-1-1')).toContainText(
        'exceeds the size limit',
      );
    });

    test('second line should contain download tip', async ({ page }) => {
      await expect(page.getByTestId('log-line-1-2')).toContainText('download');
    });

    test('download button should show', async ({ page }) => {
      await expect(page.getByTestId('download-logs-1')).toHaveCount(1);
    });
  });

  test.describe('visit Build with steps and linked logs using url line fragment', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockStepsWithLinkedLogs(page);
      await app.login('/github/octocat/1');
      await page.getByTestId('step-header-2').click({ force: true });
      await page.getByTestId('step-header-2').click({ force: true });
      await page.goto('/github/octocat/1#2:31');
      await page.reload();
      await waitForStepLogs(page, 2);
    });

    test('lines should not contain link', async ({ page }) => {
      await expect(
        page.getByTestId('log-line-2-1').getByTestId('log-line-link'),
      ).toHaveCount(0);
      await expect(
        page.getByTestId('log-line-2-2').getByTestId('log-line-link'),
      ).toHaveCount(0);
      await expect(
        page.getByTestId('log-line-2-3').getByTestId('log-line-link'),
      ).toHaveCount(0);
    });

    test('lines should contain https link', async ({ page }) => {
      const ids = [4, 5, 6, 7, 8, 9, 10, 11, 12];
      for (const id of ids) {
        await expect(
          page.getByTestId(`log-line-2-${id}`).getByTestId('log-line-link'),
        ).toHaveCount(1);
      }
    });

    test('line should contain ansi color and link', async ({ page }) => {
      const line = page.getByTestId('log-line-2-13');
      await expect(line.getByTestId('log-line-link')).toHaveCount(1);
      await expect(line.locator('.ansi-magenta-bg')).toHaveCount(1);
      await expect(line.locator('.ansi-magenta-bg')).toHaveCSS(
        'background-color',
        /rgb/,
      );
    });
  });

  test.describe('visit Build with skipped steps and 404 log errors', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page);
      await mockStepsWithSkippedAndMissingLogs(page);
      await app.login('/github/octocat/1');
    });

    test('should show skipped step message without making log API call', async ({
      page,
    }) => {
      await page.getByTestId('step-header-5').click({ force: true });

      await expect(page.getByTestId('logs-5')).toHaveCount(0);

      const container = page.locator(
        '[data-test=step-header-5] + .logs-container',
      );
      await expect(container.getByTestId('step-skipped')).toHaveCount(1);
      await expect(container.getByTestId('step-skipped')).toContainText(
        'step was skipped',
      );
    });

    test('should show 404 error message for missing logs', async ({ page }) => {
      await Promise.all([
        waitForStepLogs(page, 3),
        page.getByTestId('step-header-3').click({ force: true }),
      ]);

      await expect(page.getByTestId('logs-3')).toHaveCount(0);

      const container = page.locator(
        '[data-test=step-header-3] + .logs-container',
      );
      await expect(container.getByTestId('log-error')).toHaveCount(1);
      await expect(container.getByTestId('log-error')).toContainText(
        'Log not found (may be expired)',
      );
    });

    test('should show both step error and log error when both exist', async ({
      page,
    }) => {
      await Promise.all([
        waitForStepLogs(page, 4),
        page.getByTestId('step-header-4').click({ force: true }),
      ]);

      await expect(page.getByTestId('logs-4')).toHaveCount(0);

      const container = page.locator(
        '[data-test=step-header-4] + .logs-container',
      );
      await expect(container.getByTestId('resource-error')).toHaveCount(1);
      await expect(container.getByTestId('resource-error')).toContainText(
        'error:',
      );

      await expect(container.getByTestId('log-error')).toHaveCount(1);
      await expect(container.getByTestId('log-error')).toContainText(
        'Log not found (may be expired)',
      );
    });

    test('should handle successful logs normally', async ({ page }) => {
      await Promise.all([
        waitForStepLogs(page, 1),
        page.getByTestId('step-header-1').click({ force: true }),
      ]);

      const logs = page.getByTestId('logs-1');
      await expect(logs.getByTestId('log-line-1-1')).toHaveCount(1);
      await expect(logs.getByTestId('log-error')).toHaveCount(0);
      await expect(logs.getByTestId('step-skipped')).toHaveCount(0);
    });

    test('should show step error but still display logs when error step has logs', async ({
      page,
    }) => {
      await Promise.all([
        waitForStepLogs(page, 6),
        page.getByTestId('step-header-6').click({ force: true }),
      ]);

      const container = page.locator(
        '[data-test=step-header-6] + .logs-container',
      );
      await expect(container.getByTestId('resource-error')).toHaveCount(1);
      await expect(container.getByTestId('resource-error')).toContainText(
        'error: test suite failed',
      );

      await expect(container.getByTestId('log-error')).toHaveCount(0);

      await expect(
        page.getByTestId('logs-6').getByTestId('log-line-6-1'),
      ).toHaveCount(1);
    });

    test('should cache logs for finished steps and not refetch on re-expand', async ({
      page,
    }) => {
      await Promise.all([
        waitForStepLogs(page, 1),
        page.getByTestId('step-header-1').click({ force: true }),
      ]);

      await expect(page.getByTestId('logs-1')).toHaveCount(1);

      await page.getByTestId('step-header-1').click({ force: true });
      await expect(page.getByTestId('logs-1')).not.toBeVisible();

      await page.getByTestId('step-header-1').click({ force: true });

      await expect(page.getByTestId('logs-1')).toBeVisible();
      await expect(
        page.getByTestId('logs-1').getByTestId('log-line-1-1'),
      ).toHaveCount(1);
    });
  });
});
