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
import {
  pipelineConfigPattern,
  pipelineExpandPattern,
  pipelineTemplatesPattern,
} from './routes';

export async function mockPipelineConfig(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(pipelineConfigPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockPipelineConfigError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(pipelineConfigPattern, route =>
    withGet(route, () => route.fulfill({ status, body })),
  );
}

export async function mockPipelineTemplates(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(pipelineTemplatesPattern, route =>
    withGet(route, () =>
      jsonResponse(route, { body: resolvePayload(payloadOrFixture) }),
    ),
  );
}

export async function mockPipelineTemplatesEmpty(page: Page): Promise<void> {
  await page.route(pipelineTemplatesPattern, route =>
    withGet(route, () => jsonResponse(route, { body: {} })),
  );
}

export async function mockPipelineTemplatesError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(pipelineTemplatesPattern, route =>
    withGet(route, () => route.fulfill({ status, body })),
  );
}

export async function mockPipelineExpand(
  page: Page,
  payloadOrFixture: string | unknown,
): Promise<void> {
  await page.route(pipelineExpandPattern, route =>
    withMethod(route, 'POST', () => {
      const payload = resolvePayload(payloadOrFixture);
      const body =
        typeof payload === 'string' ? payload : JSON.stringify(payload);

      return textResponse(route, { body });
    }),
  );
}

export async function mockPipelineExpandError(
  page: Page,
  status = 500,
  body = 'server error',
): Promise<void> {
  await page.route(pipelineExpandPattern, route =>
    withMethod(route, 'POST', () => route.fulfill({ status, body })),
  );
}
