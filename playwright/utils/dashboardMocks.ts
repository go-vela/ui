/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet } from './http';
import { dashboardDetailPattern, userDashboardsPattern } from './routes';

export async function mockUserDashboards(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(userDashboardsPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockDashboardDetail(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(dashboardDetailPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockDashboardDetailError(
  page: Page,
  status = 404,
  body: Record<string, string> = {
    error:
      'unable to read dashboard deadbeef: ERROR: invalid input syntax for type uuid: "deadbeef" (SQLSTATE 22P02)',
  },
): Promise<void> {
  await page.route(dashboardDetailPattern, route =>
    withGet(route, () =>
      route.fulfill({
        status,
        contentType: 'application/json',
        body: JSON.stringify(body),
      }),
    ),
  );
}
