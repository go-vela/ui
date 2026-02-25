/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet } from './http';
import { buildArtifactsPattern } from './routes';

export async function mockArtifacts(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(buildArtifactsPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockArtifactsError(
  page: Page,
  status = 500,
  body: Record<string, string> = { error: 'Internal server error' },
): Promise<void> {
  await page.route(buildArtifactsPattern, route =>
    withGet(route, () =>
      route.fulfill({
        status,
        contentType: 'application/json',
        body: JSON.stringify(body),
      }),
    ),
  );
}

export async function mockArtifactsEmpty(page: Page): Promise<void> {
  await page.route(buildArtifactsPattern, route =>
    withGet(route, () => jsonResponse(route, { body: { names: {} } })),
  );
}
