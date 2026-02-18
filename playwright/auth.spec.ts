/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';

test.describe('Authentication', () => {
  test.describe('logged in - session exists', () => {
    test.beforeEach(async ({ app }) => {
      await app.login();
    });

    test('stays on the overview page', async ({ page }) => {
      await expect(page).toHaveURL(/\/$/);
    });

    test('shows the username near the logo', async ({ page }) => {
      await expect(page.getByTestId('identity')).toContainText('cookie cat');
    });

    test('redirects back to the overview page when trying to access login page', async ({
      page,
    }) => {
      await page.goto('/account/login');
      await expect(page).toHaveURL(/\/$/);
    });

    test('source-repos page does not redirect', async ({ page }) => {
      await page.goto('/account/source-repos');
      await expect(page).toHaveURL(/\/account\/source-repos$/);
    });

    test('provides a logout link', async ({ page }) => {
      await expect(page.getByTestId('logout-link')).toHaveAttribute(
        'href',
        /\/account\/logout(\?.*)?$/,
      );
    });
  });

  test.describe('logged out', () => {
    test.beforeEach(async ({ app }) => {
      await app.loggedOut();
    });

    test('should show login page when visiting root', async ({ page }) => {
      await expect(page.locator('body')).toContainText('Authorize Via');
    });

    test('should keep you on login page when visiting it', async ({ page }) => {
      await page.goto('/account/login');
      await expect(page).toHaveURL(/\/account\/login$/);
    });

    test('visiting non-existent page should show login page', async ({
      page,
    }) => {
      await page.goto('/asdf');
      await expect(page.locator('body')).toContainText('Authorize Via');
    });

    test('should say the application name near the logo', async ({ page }) => {
      await expect(page.getByTestId('identity')).toContainText('Vela');
    });

    test('should show the log in button', async ({ page }) => {
      const loginButton = page.getByTestId('login-button');
      await expect(loginButton).toBeVisible();
      await expect(loginButton).toHaveText('GitHub');
    });
  });

  test.describe('post-login redirect', () => {
    test.beforeEach(async ({ app }) => {
      await app.loggingIn('/Cookie/Cat');
    });

    test('should go directly to page requested', async ({ page }) => {
      await expect(page).toHaveURL(/\/Cookie\/Cat$/);
    });
  });
});
