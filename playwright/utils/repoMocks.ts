/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import {
  jsonResponse,
  resolvePayload,
  withCorsPreflight,
  withGet,
  withMethod,
} from './http';
import {
  orgReposPattern,
  repoChownPattern,
  repoDetailPattern,
  repoEnablePattern,
  repoRepairPattern,
  reposListPattern,
} from './routes';

export async function mockReposList(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(reposListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockOrgReposList(
  page: Page,
  payloadOrFixture: string | unknown,
  headers?: Record<string, string>,
): Promise<void> {
  await page.route(orgReposPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
        headers,
      }),
    ),
  );
}

export async function mockOrgReposListPaged(page: Page): Promise<void> {
  const page1 = resolvePayload('repositories_10a.json');
  const page2 = resolvePayload('repositories_10b.json');

  await page.route(orgReposPattern, route =>
    withGet(route, () => {
      const url = new URL(route.request().url());
      const pageNumber = url.searchParams.get('page');

      if (pageNumber === '2') {
        const linkHeader =
          '<http://localhost:8080/api/v1/repos/vela?page=1&per_page=10>; rel="first", <http://localhost:8080/api/v1/repos/vela?page=1&per_page=10>; rel="prev"';

        return jsonResponse(route, {
          body: page2,
          headers: {
            Link: linkHeader,
            link: linkHeader,
            'access-control-expose-headers': 'link, Link',
          },
        });
      }

      const linkHeader =
        '<http://localhost:8080/api/v1/repos/vela?page=2&per_page=10>; rel="next", <http://localhost:8080/api/v1/repos/vela?page=2&per_page=10>; rel="last"';

      return jsonResponse(route, {
        body: page1,
        headers: {
          Link: linkHeader,
          link: linkHeader,
          'access-control-expose-headers': 'link, Link',
        },
      });
    }),
  );
}

export async function mockRepoDetail(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoDetailPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockRepoUpdate(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoDetailPattern, route =>
    withMethod(route, 'PUT', () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockRepoDisable(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoDetailPattern, route =>
    withMethod(route, 'DELETE', () =>
      typeof payloadOrFixture === 'string'
        ? route.fulfill({
            status: 200,
            headers: { 'content-type': 'text/plain' },
            body: payloadOrFixture,
          })
        : jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockRepoEnable(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoEnablePattern, route =>
    withCorsPreflight(route, () =>
      withMethod(route, 'POST', () =>
        jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
      ),
    ),
  );
}

export async function mockRepoEnableError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(repoEnablePattern, route =>
    withCorsPreflight(route, () =>
      withMethod(route, 'POST', () => route.fulfill({ status, body })),
    ),
  );
}

export async function mockRepoChown(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoChownPattern, route =>
    withMethod(route, 'PATCH', () =>
      typeof payloadOrFixture === 'string'
        ? route.fulfill({
            status: 200,
            headers: { 'content-type': 'text/plain' },
            body: payloadOrFixture,
          })
        : jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockRepoChownError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(repoChownPattern, route =>
    withMethod(route, 'PATCH', () => route.fulfill({ status, body })),
  );
}

export async function mockRepoRepair(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoRepairPattern, route =>
    withMethod(route, 'PATCH', () =>
      typeof payloadOrFixture === 'string'
        ? route.fulfill({
            status: 200,
            headers: { 'content-type': 'text/plain' },
            body: payloadOrFixture,
          })
        : jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockRepoRepairError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(repoRepairPattern, route =>
    withMethod(route, 'PATCH', () => route.fulfill({ status, body })),
  );
}
