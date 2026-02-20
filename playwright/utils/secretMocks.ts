/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet } from './http';
import { secretDetailPattern, secretsListPattern } from './routes';

export async function mockSecretsList(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(secretsListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockSecretDetail(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(secretDetailPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}
