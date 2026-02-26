/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import {
  jsonResponse,
  resolvePayload,
  withGet,
  withMethod,
  textResponse,
} from './http';
import { adminSettingsPattern } from './routes';

export async function mockAdminSettings(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(adminSettingsPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockAdminSettingsError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(adminSettingsPattern, route =>
    withGet(route, () => textResponse(route, { status, body })),
  );
}

export async function mockAdminSettingsUpdate(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(adminSettingsPattern, route =>
    withMethod(route, 'PUT', () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}
