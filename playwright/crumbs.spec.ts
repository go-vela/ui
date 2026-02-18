/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsByNumber, mockBuildsList, mockStepsList } from './utils/buildMocks';
import { mockSourceRepos } from './utils/sourceReposMocks';
import { mockSecretDetail, mockSecretsList } from './utils/secretMocks';

test.describe('Crumbs', () => {
  test.describe('logged in', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsList(page, 'builds_5.json');
      await mockBuildsByNumber(page, { 1: 'build_running.json' });
      await mockStepsList(page);
      await mockSourceRepos(page, 'source_repositories.json');
      await app.login();
    });

    test('visit / should show overview', async ({ page }) => {
      await expect(page.getByTestId('crumb-overview')).toContainText('Overview');
    });

    test('visit /account/source-repos should have Overview with link', async ({
      page,
    }) => {
      await page.goto('/account/source-repos');
      await expect(
        page.getByTestId('crumb-overview').getByRole('link', {
          name: 'Overview',
        }),
      ).toBeVisible();
    });

    test('visit /account/source-repos should have Account without link', async ({
      page,
    }) => {
      await page.goto('/account/source-repos');
      await expect(page.getByTestId('crumb-account')).toContainText('Account');
      await expect(
        page.getByTestId('crumb-account').getByRole('link'),
      ).toHaveCount(0);
    });

    test('visit /account/source-repos should have Source Repositories without link', async ({
      page,
    }) => {
      await page.goto('/account/source-repos');
      await expect(page.getByTestId('crumb-source-repositories')).toContainText(
        'Source Repositories',
      );
      await expect(
        page.getByTestId('crumb-source-repositories').getByRole('link'),
      ).toHaveCount(0);
    });

    test('visit /account/source-repos Overview crumb should redirect to Overview page', async ({
      page,
    }) => {
      await page.goto('/account/source-repos');
      await page.getByTestId('crumb-overview').click();
      await expect(page).toHaveURL(/\/$/);
    });

    test('visit /github/octocat should show org and repo crumbs', async ({
      page,
    }) => {
      await page.goto('/github/octocat');
      await expect(page.getByTestId('crumb-github')).toBeVisible();
      await expect(page.getByTestId('crumb-octocat')).toBeVisible();
    });

    test('visit /github/octocat Overview crumb should redirect to Overview page', async ({
      page,
    }) => {
      await page.goto('/github/octocat');
      await page.getByTestId('crumb-overview').click();
      await expect(page).toHaveURL(/\/$/);
    });

    test('visit /github/octocat/build Overview crumb should redirect to Overview page', async ({
      page,
    }) => {
      await page.goto('/github/octocat/1');
      await page.getByTestId('crumb-overview').click();
      await expect(page).toHaveURL(/\/$/);
    });

    test('visit bad build /github/octocat/build should not show not-found crumb', async ({
      page,
    }) => {
      await page.goto('/github/octocat/1');
      await expect(page.getByTestId('crumb-not-found')).toBeHidden();
    });
  });

  test.describe('visit org secrets', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSecretsList(page, 'secrets_org_5.json');
      await app.login('/-/secrets/native/org/github');
    });

    test('should show appropriate secrets crumbs', async ({ page }) => {
      await expect(page.getByTestId('crumb-github')).toBeVisible();
    });
  });

  test.describe('visit repo secret', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSecretsList(page, []);
      await mockSecretDetail(page, 'secret_repo.json');
      await mockBuildsList(page, 'builds_5.json');
      await app.login('/-/secrets/native/repo/github/octocat/password');
    });

    test('should show appropriate secrets crumbs', async ({ page }) => {
      await expect(page.getByTestId('crumb-github')).toBeVisible();
      await expect(page.getByTestId('crumb-octocat')).toBeVisible();
      await expect(page.getByTestId('crumb-password')).toBeVisible();
    });

    test('repo crumb should redirect to repo builds', async ({ page }) => {
      await page.getByTestId('crumb-octocat').click();
      await expect(page).toHaveURL(/\/github\/octocat$/);
    });

    test('Repo Secrets crumb should redirect to repo secrets', async ({ page }) => {
      await page.getByTestId('crumb-repo-secrets').click();
      await expect(page).toHaveURL(/\/-\/secrets\/native\/repo\/github\/octocat$/);
    });
  });

  test.describe(
    'visit shared secret with special characters in team and name',
    () => {
      test.beforeEach(async ({ page, app }) => {
        await mockSecretsList(page, []);
        await mockSecretDetail(page, 'secret_shared.json');
        await app.login(
          '/-/secrets/native/shared/github/some%2Fteam/docker%2Fpassword',
        );
      });

      test('should show appropriate secrets crumbs', async ({ page }) => {
        await expect(page.getByTestId('crumb-github')).toBeVisible();
        await expect(page.getByTestId('crumb-some/team')).toBeVisible();
        await expect(page.getByTestId('crumb-shared-secrets')).toBeVisible();
        await expect(page.getByTestId('crumb-docker/password')).toBeVisible();
      });
    },
  );

  test.describe('visit add repo secret', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSecretsList(page, []);
      await app.login('/-/secrets/native/repo/github/octocat/add');
    });

    test('should show appropriate secrets crumbs', async ({ page }) => {
      await expect(page.getByTestId('crumb-github')).toBeVisible();
      await expect(page.getByTestId('crumb-octocat')).toBeVisible();
    });
  });
});
