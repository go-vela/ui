/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import {
  jsonResponse,
  resolvePayload,
  withGet,
  withMethod,
  withPagedResponse,
} from './http';
import { hooksListPattern, hookRedeliverPattern } from './routes';
import { readTestData } from './testData';

export async function mockHooksList(
  page: Page,
  payloadOrFixture: string | unknown,
  headers?: Record<string, string>,
): Promise<void> {
  await page.route(hooksListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
        headers,
      }),
    ),
  );
}

export async function mockHooksError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(hooksListPattern, route =>
    withGet(route, () => route.fulfill({ status, body })),
  );
}

export async function mockHooksListPaged(page: Page): Promise<void> {
  const page1 = readTestData('hooks_10a.json');
  const page2 = readTestData('hooks_10b.json');

  await page.route(hooksListPattern, route =>
    withGet(route, () =>
      withPagedResponse(route, {
        page1,
        page2,
        linkHeaderPage1:
          '<http://localhost:8080/api/v1/hooks/github/octocat?page=2&per_page=10>; rel="next", <http://localhost:8080/api/v1/hooks/github/octocat?page=2&per_page=10>; rel="last"',
        linkHeaderPage2:
          '<http://localhost:8080/api/v1/hooks/github/octocat?page=1&per_page=10>; rel="first", <http://localhost:8080/api/v1/hooks/github/octocat?page=1&per_page=10>; rel="prev"',
      }),
    ),
  );
}

export async function mockRedeliverHook(
  page: Page,
  options: { status: number; body: string },
): Promise<void> {
  await page.route(hookRedeliverPattern, route =>
    withMethod(route, 'POST', () =>
      route.fulfill({
        status: options.status,
        contentType: 'application/json',
        body: JSON.stringify(options.body),
      }),
    ),
  );
}
