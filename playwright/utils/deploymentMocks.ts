/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet, withMethod } from './http';
import {
  deploymentConfigPattern,
  deploymentsListPattern,
  hooksListPattern,
  repoDetailPattern,
} from './routes';

export async function mockDeploymentsList(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(deploymentsListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockDeploymentCreate(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(deploymentsListPattern, route =>
    withMethod(route, 'POST', () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockDeploymentConfig(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(deploymentConfigPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockHooksList(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(hooksListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
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
