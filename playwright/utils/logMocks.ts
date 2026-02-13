/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { jsonResponse, resolvePayload, withGet } from './http';
import { readTestData } from './testData';
import {
  serviceLogsPattern,
  servicesListPattern,
  stepLogsPattern,
  stepsListPattern,
} from './routes';

async function mockStepsList(
  page: Page,
  payloadOrFixture: string | unknown = 'steps_5.json',
): Promise<void> {
  await page.route(stepsListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
      }),
    ),
  );
}

async function mockServicesList(
  page: Page,
  payloadOrFixture: string | unknown = 'services_5.json',
): Promise<void> {
  await page.route(servicesListPattern, route =>
    withGet(route, () =>
      jsonResponse(route, {
        body: resolvePayload(payloadOrFixture),
      }),
    ),
  );
}

export async function mockStepLog(
  page: Page,
  stepNumber: number,
  payloadOrFixture: string | unknown,
  options?: { status?: number; times?: number },
): Promise<void> {
  const pattern = stepLogsPattern(stepNumber);

  await page.route(
    pattern,
    route =>
      withGet(route, () =>
        jsonResponse(route, {
          status: options?.status ?? 200,
          body: resolvePayload(payloadOrFixture),
        }),
      ),
    { times: options?.times },
  );
}

export async function mockServiceLog(
  page: Page,
  serviceNumber: number,
  payloadOrFixture: string | unknown,
  options?: { status?: number; times?: number },
): Promise<void> {
  const pattern = serviceLogsPattern(serviceNumber);

  await page.route(
    pattern,
    route =>
      withGet(route, () =>
        jsonResponse(route, {
          status: options?.status ?? 200,
          body: resolvePayload(payloadOrFixture),
        }),
      ),
    { times: options?.times },
  );
}

export async function mockStepsWithAnsiLogs(page: Page): Promise<void> {
  const logs = readTestData('logs_ansi.json') as unknown[];
  await mockStepsList(page, 'steps_5.json');

  await Promise.all(
    logs.map((log, index) => mockStepLog(page, index + 1, log)),
  );
}

export async function mockServicesWithAnsiLogs(page: Page): Promise<void> {
  const logs = readTestData('logs_services_ansi.json') as unknown[];
  await mockServicesList(page, 'services_5.json');

  await Promise.all(
    logs.map((log, index) => mockServiceLog(page, index + 1, log)),
  );
}

export async function mockStepsWithLargeLogs(page: Page): Promise<void> {
  await mockStepsList(page, 'steps_5.json');
  await mockStepLog(page, 1, 'logs_large.json');
}

export async function mockStepsWithLinkedLogs(page: Page): Promise<void> {
  const logs = readTestData('logs_links.json') as unknown[];
  await mockStepsList(page, 'steps_5.json');

  await Promise.all(
    logs.map((log, index) => mockStepLog(page, index + 1, log)),
  );
}

export async function mockStepsWithSkippedAndMissingLogs(
  page: Page,
): Promise<void> {
  const logs = readTestData('logs.json') as unknown[];
  await mockStepsList(page, 'steps_mixed_status.json');

  await mockStepLog(page, 1, logs[0]);
  await mockStepLog(page, 2, logs[1]);
  await mockStepLog(page, 3, { message: 'log not found' }, { status: 404 });
  await mockStepLog(page, 4, { message: 'log not found' }, { status: 404 });
  await mockStepLog(
    page,
    5,
    { message: 'log not found for killed step' },
    { status: 404 },
  );
  await mockStepLog(page, 6, logs[2]);
}
