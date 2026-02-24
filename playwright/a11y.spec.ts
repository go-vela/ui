/*
 * SPDX-License-Identifier: Apache-2.0
 */

import AxeBuilder from '@axe-core/playwright';
import type { RunOptions } from 'axe-core';
import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import {
  mockBuildsByNumber,
  mockBuildsList,
  mockStepsList,
} from './utils/buildMocks';
import {
  mockDeploymentConfig,
  mockDeploymentsList,
  mockHooksList as mockDeploymentHooksList,
} from './utils/deploymentMocks';
import { mockHooksList as mockRepoHooksList } from './utils/hookMocks';
import { mockStepLog } from './utils/logMocks';
import { mockRepoDetail } from './utils/repoMocks';
import { mockRepoSchedules } from './utils/scheduleMocks';
import { mockSecretsList } from './utils/secretMocks';
import { mockSourceRepos } from './utils/sourceReposMocks';
import { readTestData } from './utils/testData';

const A11Y_OPTS = {
  runOnly: {
    type: 'tag',
    values: ['section508', 'best-practice', 'wcag21aa', 'wcag2aa'],
  },
  rules: {
    'page-has-heading-one': { enabled: false },
    'scope-attr-valid': { enabled: false },
  },
} satisfies RunOptions;

const elmExclude = '[style*="padding-left: calc(1ch + 6px)"]';
const elmPopupExclude =
  'div[style*="position: fixed"][style*="bottom: 2em"][style*="right: 2em"][style*="z-index: 2147483647"]';

const themeCases = [
  { label: 'default', theme: undefined },
  { label: 'light', theme: 'theme-light' },
];

async function setTheme(page: Page, theme?: string): Promise<void> {
  if (!theme) {
    return;
  }

  await page.addInitScript(value => {
    window.localStorage.setItem('vela-theme', value);
  }, theme);
}

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

async function runA11y(
  page: Page,
  options: { exclude?: string[] } = {},
): Promise<void> {
  const defaultExcludes = [elmExclude, elmPopupExclude];
  let builder = new AxeBuilder({ page }).options(A11Y_OPTS);

  for (const selector of [...defaultExcludes, ...(options.exclude ?? [])]) {
    builder = builder.exclude(selector);
  }

  const results = await builder.analyze();
  expect(results.violations).toEqual([]);
}

async function clickSteps(page: Page): Promise<void> {
  for (const step of [1, 2, 3, 4, 5]) {
    const header = page.getByTestId(`step-header-${step}`);
    await header.scrollIntoViewIfNeeded();
    await header.click({ force: true });
  }
}

test.describe('Accessibility (a11y)', () => {
  for (const themeCase of themeCases) {
    test.describe(`Theme: ${themeCase.label}`, () => {
      test.describe('Logged out', () => {
        test('overview', async ({ page, app }) => {
          await setTheme(page, themeCase.theme);
          await app.loggedOut('/account/login');
          await page.waitForTimeout(2000);
          await runA11y(page, { exclude: [elmExclude] });
        });
      });

      test.describe('Logged in', () => {
        test.beforeEach(async ({ page }) => {
          await setTheme(page, themeCase.theme);
          await mockSourceRepos(page, 'source_repositories.json');
          await mockRepoDetail(page, 'repository.json');
          await mockBuildsList(page, 'builds_5.json');
          await mockBuildsByNumber(page, {
            1: 'build_success.json',
            2: 'build_failure.json',
            3: 'build_running.json',
          });
          await mockStepsList(page, 'steps_5.json');

          const logs = readTestData('logs.json') as Array<{ step_id: number }>;
          await Promise.all(
            logs.map(log => mockStepLog(page, log.step_id, log)),
          );

          await mockRepoHooksList(page, 'hooks_5.json');
          await mockRepoSchedules(page, 'schedules.json');
          await mockDeploymentsList(page, 'deployments_5.json');
          await mockDeploymentConfig(page, 'deployment_config.json');
          await mockDeploymentHooksList(page, []);
          await mockSecretsList(page, 'secrets_org_5.json');
        });

        test('overview', async ({ page, app }) => {
          await app.loginWithUserFixture('favorites.json', '/');
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('source repos', async ({ page, app }) => {
          await app.loginWithUserFixture(
            'favorites.json',
            '/account/source-repos',
          );
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('settings', async ({ page, app }) => {
          await app.loginWithUserFixture(
            'favorites.json',
            '/github/octocat/settings',
          );
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('repo page', async ({ page, app }) => {
          await app.loginWithUserFixture('favorites.json', '/github/octocat');
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('hooks page', async ({ page, app }) => {
          await app.loginWithUserFixture(
            'favorites.json',
            '/github/octocat/hooks',
          );
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('schedules page', async ({ page, app }) => {
          await setScheduleAllowlist(page, 'github/octocat');
          await app.loginWithUserFixture(
            'favorites.json',
            '/github/octocat/schedules',
          );
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('deployments page', async ({ page, app }) => {
          await app.loginWithUserFixture(
            'favorites.json',
            '/github/octocat/deployments',
          );
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('repo secrets page', async ({ page, app }) => {
          await app.loginWithUserFixture(
            'favorites.json',
            '/-/secrets/native/repo/octocat/deployments',
          );
          await page.waitForTimeout(2000);
          await runA11y(page);
        });

        test('build page', async ({ page, app }) => {
          await app.loginWithUserFixture('favorites.json', '/github/octocat/1');
          await page.waitForTimeout(2000);
          await page.getByTestId('steps').waitFor();
          await clickSteps(page);
          await runA11y(page, { exclude: [elmExclude] });
        });
      });
    });
  }
});
