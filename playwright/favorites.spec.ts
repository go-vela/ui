/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import { mockBuildsList } from './utils/buildMocks';
import { mockEnableRepo, mockSourceRepos } from './utils/sourceReposMocks';
import { userPattern } from './utils/routes';
import { mockUser, mockUserError, mockUserUpdate } from './utils/userMocks';

const toggleSelector = 'star-toggle-github-octocat';

async function clickAndWaitForUserUpdate(
  page: Page,
  action: () => Promise<void>,
): Promise<void> {
  await Promise.all([
    page.waitForResponse(
      response =>
        userPattern.test(response.url()) &&
        response.request().method() === 'PUT',
    ),
    action(),
  ]);
}

test.describe('Favorites', () => {
  test.describe('error loading user', () => {
    test.beforeEach(async ({ page, app }) => {
      await app.login('/');
      await page.unroute(userPattern);
      await mockUserError(page, 500, { error: 'error fetching user' });
      await page.goto('/');
    });

    test('should show the errors tray', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText(
        'error fetching user',
      );
    });
  });

  test.describe('user loaded with no favorites', () => {
    test.beforeEach(async ({ app }) => {
      await app.loginWithUserFixture('favorites_none.json');
    });

    test('should show how to add favorites', async ({ page }) => {
      await expect(page.getByTestId('overview')).toContainText(
        'To display a repository here, click the',
      );
    });
  });

  test.describe('source repos/user favorites loaded, mocked add favorite', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockUserUpdate(page, 'favorites_add.json');
      await mockSourceRepos(page, 'source_repositories.json');
      await mockEnableRepo(page, 'enable_repo_response.json');
      await app.loginWithUserFixture('favorites.json');
    });

    test.describe('Source Repos page', () => {
      test.beforeEach(async ({ page }) => {
        await page.goto('/account/source-repos');
      });

      test.describe('enable github/octocat', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('source-org-github').click();
          await page.getByTestId('enable-github-octocat').click();
        });

        test('should show favorites star toggle', async ({ page }) => {
          await expect(page.getByTestId(toggleSelector)).toBeVisible();
        });

        test('star should have favorited class', async ({ page }) => {
          await expect(
            page.getByTestId(toggleSelector).locator('svg'),
          ).toHaveClass(/favorited/);
        });

        test.describe('add favorite github/octocat', () => {
          test.beforeEach(async ({ page }) => {
            await clickAndWaitForUserUpdate(page, () =>
              page.getByTestId(toggleSelector).click(),
            );
          });

          test('star should have favorited class', async ({ page }) => {
            await expect(
              page.getByTestId(toggleSelector).locator('svg'),
            ).toHaveClass(/favorited/);
          });

          test('should show a success alert', async ({ page }) => {
            await expect(page.getByTestId('alerts')).toContainText('Success');
            await expect(page.getByTestId('alerts')).toContainText(
              'added to favorites',
            );
          });
        });
      });
    });

    test.describe('Repo Builds page', () => {
      test.beforeEach(async ({ page }) => {
        await mockBuildsList(page, 'builds_5.json');
        await page.goto('/github/octocat');
      });

      test('enabling repo should show favorites star toggle', async ({
        page,
      }) => {
        await expect(page.getByTestId(toggleSelector)).toBeVisible();
      });

      test('star should not have favorited class', async ({ page }) => {
        await expect(
          page.getByTestId(toggleSelector).locator('svg'),
        ).not.toHaveClass(/favorited/);
        await page.getByTestId(toggleSelector).click();
        await expect(
          page.getByTestId(toggleSelector).locator('svg'),
        ).toHaveClass(/favorited/);
      });

      test.describe('add favorite github/octocat', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId(toggleSelector).click();
        });

        test('star should add favorited class', async ({ page }) => {
          await expect(
            page.getByTestId(toggleSelector).locator('svg'),
          ).toHaveClass(/favorited/);
        });

        test.describe('visit Overview page', () => {
          test.beforeEach(async ({ page }) => {
            await page.unroute(userPattern);
            await mockUser(page, 'favorites_add.json');
            await page.goto('/');
          });

          test('github/octocat should display in favorites', async ({
            page,
          }) => {
            await expect(page.getByTestId(toggleSelector)).toBeVisible();
            await expect(
              page.getByTestId(toggleSelector).locator('svg'),
            ).toHaveClass(/favorited/);
          });

          test('clicking star should remove github/octocat from favorites', async ({
            page,
          }) => {
            await mockUserUpdate(page, 'favorites.json');
            await clickAndWaitForUserUpdate(page, () =>
              page.getByTestId(toggleSelector).click(),
            );
            await expect(page.getByTestId(toggleSelector)).toBeHidden();
          });
        });

        test.describe('remove favorite github/octocat', () => {
          test.beforeEach(async ({ page }) => {
            await mockUserUpdate(page, 'favorites.json');
            await clickAndWaitForUserUpdate(page, () =>
              page.getByTestId(toggleSelector).click(),
            );
          });

          test('star should not have favorited class', async ({ page }) => {
            await expect(
              page.getByTestId(toggleSelector).locator('svg'),
            ).not.toHaveClass(/favorited/);
          });
        });
      });
    });
  });

  test.describe('source repos/user favorites loaded, mocked remove favorite', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockUserUpdate(page, 'favorites_remove.json');
      await mockBuildsList(page, 'builds_5.json');
      await app.loginWithUserFixture('favorites_add.json', '/github/octocat');
    });

    test('should show a success alert', async ({ page }) => {
      await clickAndWaitForUserUpdate(page, () =>
        page.getByTestId(toggleSelector).click(),
      );
      await expect(page.getByTestId('alerts')).toContainText('Success');
      await expect(page.getByTestId('alerts')).toContainText(
        'removed from favorites',
      );
    });

    test('star should not have favorited class', async ({ page }) => {
      await clickAndWaitForUserUpdate(page, () =>
        page.getByTestId(toggleSelector).click(),
      );
      await expect(
        page.getByTestId(toggleSelector).locator('svg'),
      ).not.toHaveClass(/favorited/);
    });
  });
});
