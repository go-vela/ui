/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { readTestData } from './testData';

type AuthTokenOptions = {
  isAdmin?: boolean;
  isActive?: boolean;
  subject?: string;
  expiresInSeconds?: number;
};

function base64Encode(value: string): string {
  return Buffer.from(value).toString('base64');
}

function buildAuthToken({
  isAdmin = false,
  isActive = true,
  subject = 'cookie cat',
  expiresInSeconds = 3600,
}: AuthTokenOptions = {}): string {
  const issuedAt = Math.floor(Date.now() / 1000);
  const payload = {
    is_admin: isAdmin,
    is_active: isActive,
    exp: issuedAt + expiresInSeconds,
    iat: issuedAt,
    sub: subject,
  };
  const header = { alg: 'HS256', typ: 'JWT' };
  return [
    base64Encode(JSON.stringify(header)),
    base64Encode(JSON.stringify(payload)),
    'signature',
  ].join('.');
}

async function mockTokenRefresh(
  page: Page,
  options?: AuthTokenOptions,
): Promise<void> {
  const payload = { token: buildAuthToken(options) };
  await page.route(/^https?:\/\/[^/]+\/token-refresh(\?.*)?$/, route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(payload),
    }),
  );
}

async function mockCurrentUser(
  page: Page,
  dataName: string,
): Promise<void> {
  const payload = readTestData(dataName);
  await page.route(/^https?:\/\/[^/]+\/api\/v1\/user(\?.*)?$/, route => {
    if (route.request().method() !== 'GET') {
      return route.fallback();
    }

    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(payload),
    });
  });
}

async function mockAuthenticate(
  page: Page,
  options?: AuthTokenOptions,
): Promise<void> {
  const payload = { token: buildAuthToken(options) };
  await page.route(/^https?:\/\/[^/]+\/authenticate(\?.*)?$/, route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(payload),
    }),
  );
}

export async function login(page: Page, path = '/'): Promise<void> {
  await mockTokenRefresh(page);
  await mockCurrentUser(page, 'user.json');
  await page.goto(path);
}

export async function loginWithUserFixture(
  page: Page,
  userFixture: string,
  path = '/',
): Promise<void> {
  await mockTokenRefresh(page);
  await mockCurrentUser(page, userFixture);
  await page.goto(path);
}

export async function loginAdmin(page: Page, path = '/'): Promise<void> {
  await mockTokenRefresh(page, { isAdmin: true });
  await mockCurrentUser(page, 'user_admin.json');
  await page.goto(path);
}

export async function loggingIn(page: Page, path = '/'): Promise<void> {
  await mockTokenRefresh(page);
  await mockAuthenticate(page);
  await mockCurrentUser(page, 'user.json');
  await page.addInitScript(redirectPath => {
    window.localStorage.setItem('vela-redirect', redirectPath);
  }, path);
  const encodedPath = encodeURIComponent(path);
  await page.goto(
    `/account/authenticate?code=deadbeef&state=1337&from=${encodedPath}`,
  );
}

export async function loggedOut(page: Page, path = '/'): Promise<void> {
  await page.route('**/token-refresh*', route =>
    route.fulfill({
      status: 401,
      contentType: 'application/json',
      body: JSON.stringify({ message: 'unauthorized' }),
    }),
  );
  await page.goto(path);
}
