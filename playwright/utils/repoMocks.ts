/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet } from './http';
import { reposListPattern } from './routes';

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
