/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test as base, expect } from '@playwright/test';
import {
  loggedOut,
  loggingIn,
  login,
  loginAdmin,
  loginWithUserFixture,
} from './utils/auth';

type AppFixtures = {
  app: {
    login: (path?: string) => Promise<void>;
    loginWithUserFixture: (userFixture: string, path?: string) => Promise<void>;
    loginAdmin: (path?: string) => Promise<void>;
    loggingIn: (path?: string) => Promise<void>;
    loggedOut: (path?: string) => Promise<void>;
  };
  resetState: void;
};

export const test = base.extend<AppFixtures>({
  resetState: [
    async ({ context }, use) => {
      await context.clearCookies();
      await context.addInitScript(() => {
        window.localStorage.clear();
        window.sessionStorage.clear();
      });
      await use();
    },
    { auto: true },
  ],
  app: async ({ page }, use) => {
    const app = {
      login: async (path = '/') =>
        test.step('login', async () => {
          await login(page, path);
        }),
      loginWithUserFixture: async (userFixture: string, path = '/') =>
        test.step('login with user fixture', async () => {
          await loginWithUserFixture(page, userFixture, path);
        }),
      loginAdmin: async (path = '/') =>
        test.step('login admin', async () => {
          await loginAdmin(page, path);
        }),
      loggingIn: async (path = '/') =>
        test.step('logging in', async () => {
          await loggingIn(page, path);
        }),
      loggedOut: async (path = '/') =>
        test.step('logged out', async () => {
          await loggedOut(page, path);
        }),
    };

    await use(app);
  },
});

export { expect };
