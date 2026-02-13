/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Route } from '@playwright/test';
import { readTestData } from './testData';

type MockResponse = {
  status?: number;
  headers?: Record<string, string>;
  body: unknown;
};

// Helper function to fulfill a route with a JSON response
export function jsonResponse(
  route: Route,
  response: MockResponse,
): Promise<void> {
  const headers = {
    'content-type': 'application/json',
    ...response.headers,
  };

  return route.fulfill({
    status: response.status ?? 200,
    headers,
    body: JSON.stringify(response.body),
  });
}

// Helper function to resolve a payload that can be either an object or a fixture name
export function resolvePayload(payloadOrFixture: string | unknown): unknown {
  if (typeof payloadOrFixture === 'string') {
    return readTestData(payloadOrFixture);
  }

  return payloadOrFixture;
}

// Helper function to handle a route only if it matches the specified HTTP method
export function withMethod(
  route: Route,
  method: string,
  handler: () => Promise<void> | void,
): Promise<void> | void {
  if (route.request().method() !== method) {
    return route.fallback();
  }

  return handler();
}

// Helper function to handle a route only if it's a GET request
export function withGet(
  route: Route,
  handler: () => Promise<void> | void,
): Promise<void> | void {
  return withMethod(route, 'GET', handler);
}
