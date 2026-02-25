/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockSourceRepos, mockEnableRepo } from './utils/sourceReposMocks';
import { mockUserUpdate } from './utils/userMocks';

test.describe('Searching', () => {
  test.describe('logged in and server returning source repos', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSourceRepos(page, 'source_repos.json');
      await mockEnableRepo(page, 'enable_repo_response.json');
      await mockUserUpdate(page, 'user.json');
      await app.login('/account/source-repos');
    });

    test('global search bar should show', async ({ page }) => {
      await expect(page.getByTestId('global-search-bar')).toBeVisible();
    });

    test.describe('click on github org', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('source-org-github').click();
      });

      test('local search bar should show', async ({ page }) => {
        await expect(
          page.getByTestId('local-search-input-github'),
        ).toBeVisible();
      });

      test.describe("type 'serv' into the global search bar", () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('global-search-input').fill('serv');
        });

        test('server should show', async ({ page }) => {
          await expect(page.getByTestId('source-repo-server')).toBeVisible();
        });

        test('octocat should not show', async ({ page }) => {
          await expect(page.getByTestId('source-repo-octocat')).toHaveCount(0);
        });

        test('org repo count should not exist', async ({ page }) => {
          await expect(page.getByTestId('source-repo-count')).toHaveCount(0);
        });

        test('cat org should not exist', async ({ page }) => {
          await expect(page.getByTestId('source-org-github')).toHaveCount(0);
        });
      });

      test.describe("type 'octo' into the github org local search bar", () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('global-search-input').fill('');
          await page.getByTestId('local-search-input-github').fill('octo');
        });

        test('octocat should show', async ({ page }) => {
          await expect(page.getByTestId('source-repo-octocat')).toBeVisible();
        });

        test('server should not show', async ({ page }) => {
          await expect(page.getByTestId('source-repo-server')).toHaveCount(0);
        });

        test('github repo count should display 3', async ({ page }) => {
          await expect(
            page
              .getByTestId('source-org-github')
              .getByTestId('source-repo-count'),
          ).toContainText('3');
        });

        test.describe('clear github local search bar', () => {
          test.beforeEach(async ({ page }) => {
            await page.getByTestId('global-search-input').fill('');
            await page.getByTestId('local-search-input-github').fill('');
          });

          test('octocat and server should show', async ({ page }) => {
            await expect(page.getByTestId('source-repo-octocat')).toBeVisible();
            await expect(page.getByTestId('source-repo-server')).toBeVisible();
          });
        });
      });

      test.describe("type 'octo' into the github org local search bar (enable)", () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('global-search-input').fill('');
          await page.getByTestId('local-search-input-github').fill('octo');
        });

        test('octocat should show', async ({ page }) => {
          await expect(page.getByTestId('source-repo-octocat')).toBeVisible();
        });

        test('enable all button should contain Enable Results', async ({
          page,
        }) => {
          await expect(page.getByTestId('enable-org-github')).toContainText(
            'Enable Results',
          );
        });

        test.describe('click Enable All button, then clear github local search input', () => {
          test.beforeEach(async ({ page }) => {
            await page.getByTestId('enable-org-github').click({ force: true });
            await page.getByTestId('local-search-input-github').fill('');
          });

          test('filtered repos should show and display enabling', async ({
            page,
          }) => {
            await expect(
              page.getByTestId('source-repo-octocat-1'),
            ).toContainText('Enabling');
            await expect(
              page.getByTestId('source-repo-octocat-2'),
            ).toContainText('Enabling');
            await expect(
              page.getByTestId('source-repo-server'),
            ).not.toContainText('Enabling');
          });

          test('non-filtered repos should show but not display enabling', async ({
            page,
          }) => {
            await expect(page.getByTestId('source-repo-server')).toBeVisible();
            await expect(
              page.getByTestId('source-repo-server'),
            ).not.toContainText('Enabling');
            await expect(page.getByTestId('source-repo-octocat')).toBeVisible();
            await expect(
              page.getByTestId('source-repo-octocat'),
            ).not.toContainText('Enabling');
          });

          test('without search input, enable all button should contain Enable All', async ({
            page,
          }) => {
            await expect(page.getByTestId('enable-org-github')).toContainText(
              'Enable All',
            );
          });
        });
      });

      test.describe('with searches entered, refresh source repos list', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('local-search-input-github').fill('serv');
          await page.getByTestId('global-search-input').fill('github');
          await page.getByTestId('refresh-source-repos').click();
        });

        test('global search should be cleared', async ({ page }) => {
          await expect(page.getByTestId('global-search-input')).not.toHaveValue(
            /octo/,
          );
        });

        test('local search should be cleared', async ({ page }) => {
          await expect(
            page.getByTestId('local-search-input-github'),
          ).toHaveCount(0);
        });
      });

      test.describe("type 'nonsense' into the global search bar", () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('global-search-input').fill('nonsense');
        });

        test("should show message for 'No results'", async ({ page }) => {
          await expect(page.getByTestId('source-repos')).toContainText(
            'No results',
          );
        });
      });

      test.describe("type 'nonsense' into the local search bar", () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('local-search-input-github').fill('nonsense');
        });

        test("should show message for 'No results'", async ({ page }) => {
          await expect(page.getByTestId('source-repos')).toContainText(
            'No results',
          );
        });
      });
    });
  });
});
