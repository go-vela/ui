/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsList } from './utils/buildMocks';
import { mockHooksList } from './utils/hookMocks';

type BuildParams = {
  enqueued: number;
  created: number;
  started: number;
  finished: number;
  status?: string;
  number?: number;
};

const dayInSeconds = 24 * 60 * 60;

function createBuild({
  enqueued,
  created,
  started,
  finished,
  status = 'success',
  number = 1,
}: BuildParams) {
  return {
    id: number,
    repo_id: 1,
    number,
    parent: 1,
    event: 'push',
    status,
    error: '',
    enqueued,
    created,
    started,
    finished,
    deploy: '',
    link: `/github/octocat/${number}`,
    clone: 'https://github.com/github/octocat.git',
    source:
      'https://github.com/github/octocat/commit/9b1d8bded6e992ab660eaee527c5e3232d0a2441',
    title: 'push received from https://github.com/github/octocat',
    message: 'fixing docker params',
    commit: '9b1d8bded6e992ab660eaee527c5e3232d0a2441',
    sender: 'CookieCat',
    author: 'CookieCat',
    branch: 'infra',
    ref: 'refs/heads/infra',
    base_ref: '',
    host: '',
    runtime: 'docker',
    distribution: 'linux',
  };
}

function getUnixTime(offsetSeconds = 0): number {
  return Math.floor(Date.now() / 1000) + offsetSeconds;
}

test.describe('Insights', () => {
  test.describe('no builds', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsList(page, []);
      await mockHooksList(page, []);
      await app.login('/github/octocat/insights');
    });

    test('should show no builds message', async ({ page }) => {
      await expect(page.getByTestId('no-builds')).toBeVisible();
    });
  });

  test.describe('varying builds', () => {
    test.beforeEach(async ({ page, app }) => {
      const builds = [
        createBuild({
          enqueued: getUnixTime(-3 * dayInSeconds),
          created: getUnixTime(-3 * dayInSeconds),
          started: getUnixTime(-3 * dayInSeconds),
          finished: getUnixTime(-3 * dayInSeconds + 30 * 60),
          status: 'success',
          number: 1,
        }),
        createBuild({
          enqueued: getUnixTime(-2 * dayInSeconds),
          created: getUnixTime(-2 * dayInSeconds),
          started: getUnixTime(-2 * dayInSeconds),
          finished: getUnixTime(-2 * dayInSeconds + 30 * 60),
          status: 'failure',
          number: 2,
        }),
        createBuild({
          enqueued: getUnixTime(-2 * dayInSeconds + 600),
          created: getUnixTime(-2 * dayInSeconds + 600),
          started: getUnixTime(-2 * dayInSeconds + 600),
          finished: getUnixTime(-2 * dayInSeconds + 600 + 15 * 60),
          status: 'success',
          number: 3,
        }),
        createBuild({
          enqueued: getUnixTime(-dayInSeconds),
          created: getUnixTime(-dayInSeconds),
          started: getUnixTime(-dayInSeconds),
          finished: getUnixTime(-dayInSeconds + 45 * 60),
          status: 'success',
          number: 4,
        }),
      ];

      await mockBuildsList(page, builds);
      await mockHooksList(page, []);
      await app.login('/github/octocat/insights');
    });

    test('daily average should be 2', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-activity')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('2');
    });

    test('average build time should be 30m 0s', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-duration')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('30m 0s');
    });

    test('reliability should be 75% success', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-reliability')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('75.0%');
    });

    test('time to recover should be 10 minutes', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-reliability')
        .locator('.metric-value')
        .nth(2);
      await expect(value).toHaveText('10m 0s');
    });

    test('average queue time should be 0 seconds', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-queue')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('0s');
    });
  });

  test.describe('one identical build a day', () => {
    test.beforeEach(async ({ page, app }) => {
      const epochTime = getUnixTime(-6 * dayInSeconds);

      const builds = Array.from({ length: 7 }, (_, index) => {
        const created = epochTime + index * dayInSeconds;
        const enqueued = created + 10;
        const started = enqueued + 10;
        const finished = started + 30;

        return createBuild({
          enqueued,
          created,
          started,
          finished,
          number: index + 1,
        });
      });

      await mockBuildsList(page, builds);
      await mockHooksList(page, []);
      await app.login('/github/octocat/insights');
    });

    test('should show 4 metric quicklists', async ({ page }) => {
      await expect(page.locator('[data-test^=metrics-quicklist-]')).toHaveCount(
        4,
      );
    });

    test('should show 4 charts', async ({ page }) => {
      await expect(page.getByTestId('metrics-chart')).toHaveCount(4);
    });

    test('daily average should be 1', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-activity')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('1');
    });

    test('average build time should be 30 seconds', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-duration')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('30s');
    });

    test('reliability should be 100% success', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-reliability')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('100.0%');
    });

    test('average queue time should be 10 seconds', async ({ page }) => {
      const value = page
        .getByTestId('metrics-quicklist-queue')
        .locator('.metric-value')
        .first();
      await expect(value).toHaveText('10s');
    });
  });
});
