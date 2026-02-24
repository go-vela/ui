/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockBuildsByNumber,
  mockBuildsList,
  mockStepsList,
} from './utils/buildMocks';
import { mockStepLog } from './utils/logMocks';
import { readTestData } from './utils/testData';

const waitForLogLine = async (
  page: {
    getByTestId: (id: string) => {
      waitFor: (options?: {
        state?: 'attached' | 'visible';
      }) => Promise<unknown>;
    };
  },
  step: number,
  line: number,
  state: 'attached' | 'visible' = 'attached',
) => page.getByTestId(`log-line-${step}-${line}`).waitFor({ state });

const clickSteps = async (page: { getByTestId: (id: string) => any }) => {
  for (const step of [1, 2, 3, 4, 5]) {
    const header = page.getByTestId(`step-header-${step}`);
    await header.scrollIntoViewIfNeeded();
    await header.click({ force: true });
  }
};

test.describe('Steps', () => {
  test.describe('logged in and server returning builds, steps, and logs', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockStepsList(page, 'steps_5_skipped_step.json');

      const logs = readTestData('logs.json') as Array<{ step_id: number }>;
      await Promise.all(
        logs.map((log, index) => mockStepLog(page, index + 1, log)),
      );

      await app.login('/github/octocat/1');
      await page.getByTestId('steps').waitFor();
      await clickSteps(page);
      await page.getByTestId('logs-1').waitFor();
    });

    test('steps should show', async ({ page }) => {
      await expect(page.getByTestId('steps')).toBeVisible();
    });

    test('5 steps should show', async ({ page }) => {
      await expect(page.getByTestId('steps').locator(':scope > *')).toHaveCount(
        5,
      );
    });

    test('steps should be in order by number', async ({ page }) => {
      const stepItems = page.getByTestId('steps').locator(':scope > *');
      await expect(stepItems.first()).toContainText('clone');
      await expect(stepItems.last()).toContainText('echo');
    });

    test('First 5 steps should have logs', async ({ page }) => {
      await expect(page.getByTestId('logs-1')).toContainText('$');
      await expect(page.getByTestId('logs-2')).toContainText('$');
      await expect(page.getByTestId('logs-3')).toContainText('$');
      await expect(page.getByTestId('logs-4')).toContainText('$');
      await expect(page.getByTestId('logs-5')).toContainText('$');
      await expect(page.getByTestId('logs-6')).toHaveCount(0);
    });

    test('logs should be base64 decoded', async ({ page }) => {
      await expect(page.getByTestId('log-line-1-1')).toContainText('$');
    });

    test('logs should be hidden', async ({ page }) => {
      await page.getByTestId('step-header-1').click({ force: true });
      await expect(
        page.getByTestId('logs-1').locator(':scope > *').first(),
      ).toBeHidden();
    });

    test.describe('click steps (to hide them)', () => {
      test.beforeEach(async ({ page }) => {
        await clickSteps(page);
      });

      test('logs should be hidden', async ({ page }) => {
        await expect(
          page.getByTestId('logs-1').locator(':scope > *').first(),
        ).toBeHidden();
      });

      test.describe('click steps again', () => {
        test.beforeEach(async ({ page }) => {
          await clickSteps(page);
        });

        test('should show logs', async ({ page }) => {
          await expect(
            page.getByTestId('logs-1').locator(':scope > *').first(),
          ).toBeVisible();
        });
      });
    });

    test.describe('click first step twice', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('step-header-1').click({ force: true });
        await page.getByTestId('step-header-1').click({ force: true });
      });

      test('browser path should contain first step fragment', async ({
        page,
      }) => {
        await expect(page).toHaveURL(/#1$/);
      });

      test('browser path should contain last step fragment', async ({
        page,
      }) => {
        await page.getByTestId('step-header-5').click({ force: true });
        await page.getByTestId('step-header-5').click({ force: true });
        await expect(page).toHaveURL(/#5$/);
      });
    });

    test.describe('click log line in last step', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('step-header-5').click({ force: true });
        await page.getByTestId('step-skipped').click({ force: true });
      });

      test.describe('click first step twice', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('step-header-1').click({ force: true });
          await page.getByTestId('step-header-1').click({ force: true });
        });

        test('browser path should contain first step fragment', async ({
          page,
        }) => {
          await expect(page).toHaveURL(/#1$/);
        });
      });
    });

    test.describe('click log line number', () => {
      test.beforeEach(async ({ page }) => {
        await waitForLogLine(page, 1, 3);
        await page.getByTestId('log-line-num-1-3').click({ force: true });
      });

      test('line should be highlighted', async ({ page }) => {
        const line = page.getByTestId('log-line-1-3');
        await expect(line).toHaveClass(/-focus/);
      });

      test('browser path should contain step and line fragment', async ({
        page,
      }) => {
        await expect(page).toHaveURL(/#1:3$/);
      });

      test.describe('click other log line number', () => {
        test.beforeEach(async ({ page }) => {
          await waitForLogLine(page, 3, 2);
          await page.getByTestId('log-line-num-3-2').click({ force: true });
        });

        test('original line should not be highlighted', async ({ page }) => {
          await expect(page.getByTestId('log-line-1-3')).not.toHaveClass(
            /-focus/,
          );
        });

        test('other line should be highlighted', async ({ page }) => {
          await expect(page.getByTestId('log-line-3-2')).toHaveClass(/-focus/);
        });

        test('browser path should contain other step and line fragment', async ({
          page,
        }) => {
          await clickSteps(page);
          await expect(page).toHaveURL(/#3:2$/);
        });

        test('browser path should contain other step and line fragment (direct click)', async ({
          page,
        }) => {
          await page.getByTestId('log-line-num-3-2').click({ force: true });
          await expect(page).toHaveURL(/#3:2$/);
        });
      });
    });

    test.describe('visit Build, then visit log line with fragment', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/1#2:2');
        await page.reload();
        await waitForLogLine(page, 2, 2);
      });

      test('line should be highlighted', async ({ page }) => {
        await expect(page.getByTestId('log-line-2-2')).toHaveClass(/-focus/);
      });
    });

    test.describe('visit Build, with only step fragment', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/1#2');
        await page.reload();
        await waitForLogLine(page, 2, 2);
      });

      test('range start line should not be highlighted', async ({ page }) => {
        await expect(page.getByTestId('log-line-2-2')).not.toHaveClass(
          /-focus/,
        );
      });

      test.describe('click line 2, shift click line 5', () => {
        test.beforeEach(async ({ page }) => {
          await waitForLogLine(page, 2, 2);
          await page.keyboard.down('Shift');
          await page.getByTestId('log-line-num-2-2').click({ force: true });
          await page.getByTestId('log-line-num-2-5').click({ force: true });
          await page.keyboard.up('Shift');
        });

        test('range start line should be highlighted', async ({ page }) => {
          await expect(page.getByTestId('log-line-2-2')).toHaveClass(/-focus/);
        });

        test('lines between range start and end should be highlighted', async ({
          page,
        }) => {
          await expect(page.getByTestId('log-line-2-3')).toHaveClass(/-focus/);
          await expect(page.getByTestId('log-line-2-4')).toHaveClass(/-focus/);
        });
      });

      test.describe('click first step twice', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('step-header-1').click({ force: true });
          await page.getByTestId('step-header-1').click({ force: true });
        });

        test('browser path should contain first step fragment', async ({
          page,
        }) => {
          await expect(page).toHaveURL(/#1$/);
        });
      });
    });

    test.describe('visit Build, then visit log line range with fragment', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/1#2:2:5');
        await page.reload();
        await waitForLogLine(page, 2, 5);
      });

      test('range start line should be highlighted', async ({ page }) => {
        await expect(page.getByTestId('log-line-2-2')).toHaveClass(/-focus/);
      });

      test('range end line should be highlighted', async ({ page }) => {
        await expect(page.getByTestId('log-line-2-5')).toHaveClass(/-focus/);
      });

      test('lines between range start and end should be highlighted', async ({
        page,
      }) => {
        await expect(page.getByTestId('log-line-2-3')).toHaveClass(/-focus/);
        await expect(page.getByTestId('log-line-2-4')).toHaveClass(/-focus/);
      });
    });

    test.describe('visit Build, click log line, then visit log line with fragment', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/github/octocat/1');
        await clickSteps(page);
        await page.getByTestId('log-line-num-3-3').click({ force: true });
        await page.goto('/github/octocat/1#2:2');
        await page.reload();
        await page.getByTestId('step-header-3').scrollIntoViewIfNeeded();
        await page.getByTestId('step-header-3').click({ force: true });
        await waitForLogLine(page, 3, 3);
      });

      test('original line should not be highlighted', async ({ page }) => {
        await expect(page.getByTestId('log-line-3-3')).not.toHaveClass(
          /-focus/,
        );
      });

      test('other line should be highlighted', async ({ page }) => {
        await expect(page.getByTestId('log-line-2-2')).toHaveClass(/-focus/);
      });

      test.describe('click first step', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('step-header-5').click({ force: true });
        });

        test('last step should contain killed/skip', async ({ page }) => {
          const lastStep = page.getByTestId('step').last();
          await lastStep.click({ force: true });
          await expect(lastStep).toContainText('step was skipped');
        });
      });
    });
  });

  test.describe('visit build/steps with server error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 5: 'build_error.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockStepsList(page, 'steps_error.json');

      const logs = readTestData('logs.json') as Array<{ step_id: number }>;
      await Promise.all(logs.map(log => mockStepLog(page, log.step_id, log)));

      await app.login('/github/octocat/5');
      await clickSteps(page);
      await clickSteps(page);
      await page.getByTestId('build').waitFor();
    });

    test('build should have error style', async ({ page }) => {
      await expect(page.getByTestId('build-status')).toHaveClass(/-error/);
    });

    test('build error should show', async ({ page }) => {
      await expect(page.getByTestId('build-error')).toBeVisible();
    });

    test('build error should contain error', async ({ page }) => {
      const error = page.getByTestId('build-error');
      await expect(error).toContainText('error:');
      await expect(error).toContainText('failure authenticating');
    });

    test('first step should contain error', async ({ page }) => {
      const cloneStep = page.getByTestId('step').first();
      await cloneStep.click({ force: true });
      await expect(cloneStep).toContainText('error:');
      await expect(cloneStep).toContainText('problem starting container');
    });

    test('last step should not contain killed/skipped', async ({ page }) => {
      const echoStep = page.getByTestId('step').last();
      await page.getByTestId('step-header-5').click({ force: true });
      await expect(echoStep).not.toContainText('error:');
      await expect(echoStep).not.toContainText('step was killed');
      await expect(echoStep).toContainText('$');
    });
  });

  test.describe('visit build/steps with stages', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 5: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockStepsList(page, 'steps_stages.json');
      await app.login('/github/octocat/5');
    });

    test('build should contain stages', async ({ page }) => {
      await expect(page.getByTestId('stage')).toHaveCount(4);
    });

    test('stages should contain stage names go and deploy', async ({
      page,
    }) => {
      await expect(
        page.getByTestId('stage').filter({ hasText: 'go' }),
      ).toHaveCount(1);
      await expect(page.getByTestId('stage-divider-go')).toContainText('go');

      await expect(
        page.getByTestId('stage').filter({ hasText: 'deploy' }),
      ).toHaveCount(1);
      await expect(page.getByTestId('stage-divider-deploy')).toContainText(
        'deploy',
      );
    });

    test('init/clone stages should not contain stage dividers', async ({
      page,
    }) => {
      await expect(page.getByTestId('stage-divider-init')).toHaveCount(0);
      await expect(page.getByTestId('stage-divider-clone')).toHaveCount(0);
    });

    test('stages should contain grouped steps', async ({ page }) => {
      await expect(page.locator('[data-test=stage-go] .step')).toHaveCount(2);
      await expect(page.getByTestId('stage-go')).toContainText('build');
      await expect(page.getByTestId('stage-go')).toContainText('test');

      await expect(page.locator('[data-test=stage-deploy] .step')).toHaveCount(
        3,
      );
      await expect(page.getByTestId('stage-deploy')).toContainText(
        'docker-build',
      );
      await expect(page.getByTestId('stage-deploy')).toContainText(
        'docker-publish',
      );
      await expect(page.getByTestId('stage-deploy')).toContainText(
        'docker-tag',
      );
    });
  });
});
