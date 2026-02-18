/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet, withMethod } from './http';
import { readTestData } from './testData';
import {
  buildApprovePattern,
  buildCancelPattern,
  buildDetailPattern,
  buildListPattern,
  stepsListPattern,
} from './routes';

type BuildFixtureMap = Record<number, string>;

// Default fixtures for builds 1-9, which can be overridden by providing a custom map to mockBuildsByNumber
const defaultBuildFixtures: BuildFixtureMap = {
  1: 'build_running.json',
  2: 'build_pending.json',
  3: 'build_success.json',
  4: 'build_failure.json',
  5: 'build_error.json',
  6: 'build_canceled.json',
  7: 'build_success.json',
  8: 'build_pending_approval.json',
  9: 'build_approved.json',
};

// Helper function to mock build details by build number, with optional overrides for specific build numbers
export async function mockBuildsByNumber(
  page: Page,
  overrides?: BuildFixtureMap,
): Promise<void> {
  const fixtures = { ...defaultBuildFixtures, ...overrides };

  await page.route(buildDetailPattern, route =>
    withGet(route, () => {
      const match = route.request().url().match(buildDetailPattern);
      const buildNumber = match ? Number(match[1]) : NaN;
      const fixtureName = fixtures[buildNumber];

      if (!fixtureName) {
        return jsonResponse(route, {
          status: 404,
          body: { message: 'build not found' },
        });
      }

      return jsonResponse(route, { body: readTestData(fixtureName) });
    }),
  );
}

export async function mockBuildsList(
  page: Page,
  payloadOrFixture: string | unknown,
  headers?: Record<string, string>,
): Promise<void> {
  await page.route(buildListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
        headers,
      }),
    ),
  );
}

export async function mockBuildsListPaged(page: Page): Promise<void> {
  const page1 = readTestData('builds_10a.json');
  const page2 = readTestData('builds_10b.json');

  await page.route(buildListPattern, route =>
    withGet(route, () => {
      const url = new URL(route.request().url());
      const pageNumber = url.searchParams.get('page');

      if (pageNumber === '2') {
        return jsonResponse(route, {
          body: page2,
          headers: {
            link: '<http://localhost:8888/api/v1/repos/github/octocat/builds?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/github/octocat/builds?page=1&per_page=10>; rel="prev",',
          },
        });
      }

      return jsonResponse(route, {
        body: page1,
        headers: {
          link: '<http://localhost:8888/api/v1/repos/github/octocat/builds?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/github/octocat/builds?page=2&per_page=10>; rel="last",',
        },
      });
    }),
  );
}

export async function mockBuildErrors(page: Page): Promise<void> {
  await page.route(buildDetailPattern, route =>
    withGet(route, () => route.fulfill({ status: 500, body: 'server error' })),
  );
}

export async function mockBuildsErrors(page: Page): Promise<void> {
  await page.route(buildListPattern, route =>
    withGet(route, () => route.fulfill({ status: 500, body: 'server error' })),
  );
}

export async function mockStepsErrors(page: Page): Promise<void> {
  await page.route(stepsListPattern, route =>
    withGet(route, () => route.fulfill({ status: 500, body: 'server error' })),
  );
}

export async function mockStepsList(
  page: Page,
  payloadOrFixture: string | unknown = 'steps_5.json',
): Promise<void> {
  await page.route(stepsListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
      }),
    ),
  );
}

export async function mockRestartBuild(
  page: Page,
  options: { status: number; payload?: string | unknown },
): Promise<void> {
  await page.route(buildDetailPattern, route =>
    withMethod(route, 'POST', () => {
      if (options.payload === undefined) {
        return jsonResponse(route, {
          status: options.status,
          body: { message: 'server error' },
        });
      }

      return jsonResponse(route, {
        status: options.status,
        body: resolvePayload(options.payload),
      });
    }),
  );
}

export async function mockCancelBuild(
  page: Page,
  options: { status: number; body: string },
): Promise<void> {
  await page.route(buildCancelPattern, route =>
    withMethod(route, 'DELETE', () =>
      jsonResponse(route, {
        status: options.status,
        body: options.body,
      }),
    ),
  );
}

export async function mockApproveBuild(
  page: Page,
  options: { status: number; body: string },
): Promise<void> {
  await page.route(buildApprovePattern, route =>
    withMethod(route, 'POST', () =>
      jsonResponse(route, {
        status: options.status,
        body: options.body,
      }),
    ),
  );
}
