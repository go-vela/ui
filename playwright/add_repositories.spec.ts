/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockEnableRepo,
  mockEnableRepoError,
  mockSourceRepos,
  mockSourceReposError,
} from './utils/sourceReposMocks';
import { repoEnablePattern, sourceReposPattern } from './utils/routes';

test.describe('Source Repositories', () => {
  test.describe('logged in', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSourceRepos(page, 'source_repositories.json');
      await mockEnableRepo(page, 'enable_repo_response.json');
      await app.login('/account/source-repos');
    });

    test('should show the orgs', async ({ page }) => {
      await expect(
        page.locator('[data-test=source-repos] .details'),
      ).toHaveCount(3);
    });

    test('toggles visibility of repos in an org', async ({ page }) => {
      const catOrg = page.locator('[data-test=source-org-cat]');
      const catRepos = page.locator(
        '[data-test=source-org-cat] ~ [data-test^=source-repo]',
      );

      await catOrg.click();
      await expect(catRepos).toHaveCount(3);
      await expect(catRepos.first()).toBeVisible();
      await expect(catRepos.last()).toBeVisible();

      await catOrg.click();
      await expect(catRepos.first()).toBeHidden();
      await expect(catRepos.last()).toBeHidden();
    });

    test('shows the enabled label when a repo is enabled', async ({ page }) => {
      await page.getByTestId('source-org-github').click();
      await page.getByTestId('enable-github-octocat').click();

      await expect(
        page.getByTestId('enabled-github-octocat').first(),
      ).toBeVisible();
      await expect(
        page.getByTestId('enabled-github-octocat').first(),
      ).toContainText('Enabled');
    });

    test('shows the failed button and alert when the enable is unsuccessful', async ({
      page,
    }) => {
      await page.unroute(repoEnablePattern);
      await mockEnableRepoError(page);

      await page.getByTestId('source-org-cat').click();
      await page.getByTestId('enable-cat-purr').click();

      await expect(page.getByTestId('enabled-cat-purr')).toBeHidden();
      await expect(page.getByTestId('failed-cat-purr')).toBeVisible();
      await expect(page.getByTestId('failed-cat-purr')).toContainText('Fail');
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });

    test('shows the loading labels when all repos for org are enabled', async ({
      page,
    }) => {
      await page.getByTestId('source-org-github').click();
      await page.getByTestId('enable-org-github').click({ force: true });

      await expect(page.getByTestId('source-repo-octocat-1')).toContainText(
        'Enabling',
      );
      await expect(page.getByTestId('source-repo-octocat-2')).toContainText(
        'Enabling',
      );
      await expect(page.getByTestId('source-repo-server')).toContainText(
        'Enabling',
      );
    });
  });

  test.describe('logged in - artificial 1s load delay', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSourceRepos(page, {}, { delayMs: 1000 });
      await app.login('/account/source-repos');
    });

    test('disables the refresh list button while loading', async ({ page }) => {
      const refreshButton = page.getByTestId('refresh-source-repos');
      await expect(refreshButton).toBeVisible();
      await expect(refreshButton).toBeDisabled();
      await page.waitForResponse(sourceReposPattern);
    });
  });

  test.describe('logged in - api error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSourceReposError(page, 500, 'server error');
      await app.login('/account/source-repos');
    });

    test('show a message and an alert when there is a server error', async ({
      page,
    }) => {
      await expect(page.locator('.content-wrap')).toContainText(
        'There was an error fetching your available repositories, please refresh or try again later!',
      );
    });
  });

  test.describe('logged in - unexpected response', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockSourceRepos(page, 'source_repositories_bad.json');
      await app.login('/account/source-repos');
    });

    test('show a message and an alert when the response is malformed', async ({
      page,
    }) => {
      await expect(page.locator('.content-wrap')).toContainText(
        'There was an error fetching your available repositories, please refresh or try again later!',
      );
      await expect(page.getByTestId('alerts')).toContainText(
        'Expecting an OBJECT with a field named `org`',
      );
    });
  });
});
