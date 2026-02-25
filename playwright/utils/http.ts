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

type TextResponse = {
  status?: number;
  headers?: Record<string, string>;
  body: string;
};

type PagedResponseOptions = {
  page1: unknown;
  page2: unknown;
  linkHeaderPage1: string;
  linkHeaderPage2: string;
  pageParam?: string;
  headers?: Record<string, string>;
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

// Helper function to fulfill a route with a plain text response
export function textResponse(
  route: Route,
  response: TextResponse,
): Promise<void> {
  const headers = {
    'content-type': 'text/plain',
    ...response.headers,
  };

  return route.fulfill({
    status: response.status ?? 200,
    headers,
    body: response.body,
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

// Helper function to fulfill a paged JSON response with Link headers
export function withPagedResponse(
  route: Route,
  options: PagedResponseOptions,
): Promise<void> {
  const url = new URL(route.request().url());
  const pageNumber = url.searchParams.get(options.pageParam ?? 'page');
  const isSecondPage = pageNumber === '2';
  const linkHeader = isSecondPage
    ? options.linkHeaderPage2
    : options.linkHeaderPage1;
  const body = isSecondPage ? options.page2 : options.page1;

  return jsonResponse(route, {
    body,
    headers: {
      Link: linkHeader,
      link: linkHeader,
      'access-control-expose-headers': 'link, Link',
      ...options.headers,
    },
  });
}

// Helper to fulfill CORS preflight requests before delegating to a handler.
export function withCorsPreflight(
  route: Route,
  handler: () => Promise<void> | void,
): Promise<void> | void {
  if (route.request().method() === 'OPTIONS') {
    return route.fulfill({
      status: 204,
      headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-methods':
          'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'access-control-allow-headers': 'content-type, authorization',
      },
    });
  }

  return handler();
}
