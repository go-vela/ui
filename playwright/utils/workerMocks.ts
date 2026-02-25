/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet, withPagedResponse } from './http';
import { workersListPattern } from './routes';

export async function mockWorkersList(
  page: Page,
  payloadOrFixture: string | unknown,
  headers?: Record<string, string>,
): Promise<void> {
  await page.route(workersListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
        headers,
      }),
    ),
  );
}

export async function mockWorkersListPaged(page: Page): Promise<void> {
  const page1 = resolvePayload('workers_10a.json');
  const page2 = resolvePayload('workers_10b.json');

  await page.route(workersListPattern, route =>
    withGet(route, () =>
      withPagedResponse(route, {
        page1,
        page2,
        linkHeaderPage1:
          '<http://localhost:8080/api/v1/workers?page=2&per_page=10>; rel="next", <http://localhost:8080/api/v1/workers?page=2&per_page=10>; rel="last"',
        linkHeaderPage2:
          '<http://localhost:8080/api/v1/workers?page=1&per_page=10>; rel="first", <http://localhost:8080/api/v1/workers?page=1&per_page=10>; rel="prev"',
      }),
    ),
  );
}

export async function mockWorkersError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(workersListPattern, route =>
    withGet(route, () => route.fulfill({ status, body })),
  );
}
