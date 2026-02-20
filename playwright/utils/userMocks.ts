/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet, withMethod } from './http';
import { userPattern } from './routes';

export async function mockUser(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(userPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockUserUpdate(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(userPattern, route =>
    withMethod(route, 'PUT', () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockUserError(
  page: Page,
  status = 500,
  body: Record<string, string> = { error: 'error fetching user' },
): Promise<void> {
  await page.route(userPattern, route =>
    withGet(route, () =>
      route.fulfill({
        status,
        contentType: 'application/json',
        body: JSON.stringify(body),
      }),
    ),
  );
}
