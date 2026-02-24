/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet } from './http';
import { scheduleDetailPattern, schedulesListPattern } from './routes';

export async function mockRepoSchedules(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(schedulesListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockRepoSchedule(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(scheduleDetailPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}
