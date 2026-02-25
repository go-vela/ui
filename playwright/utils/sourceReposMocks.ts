/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet, textResponse } from './http';
import { repoEnablePattern, sourceReposPattern } from './routes';

const sleep = (ms: number): Promise<void> =>
  new Promise(resolve => setTimeout(resolve, ms));

type SourceReposOptions = {
  delayMs?: number;
  status?: number;
};

export async function mockSourceRepos(
  page: Page,
  payloadOrFixture: string | unknown,
  options: SourceReposOptions = {},
): Promise<void> {
  await page.route(sourceReposPattern, route =>
    withGet(route, async () => {
      if (options.delayMs) {
        await sleep(options.delayMs);
      }

      return jsonResponse(route, {
        status: options.status,
        body: resolvePayload(payloadOrFixture),
      });
    }),
  );
}

export async function mockSourceReposError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(sourceReposPattern, route =>
    withGet(route, () => textResponse(route, { status, body })),
  );
}

export async function mockEnableRepo(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(repoEnablePattern, route => {
    const method = route.request().method();
    if (method !== 'POST' && method !== 'PUT') {
      return route.fallback();
    }

    return jsonResponse(route, { body: resolvePayload(payloadOrFixture) });
  });
}

export async function mockEnableRepoError(
  page: Page,
  status = 500,
  body = { error: 'unable to create webhook for : something went wrong' },
): Promise<void> {
  await page.route(repoEnablePattern, route => {
    if (route.request().method() !== 'POST') {
      return route.fallback();
    }

    return route.fulfill({
      status,
      contentType: 'application/json',
      body: JSON.stringify(body),
    });
  });
}
