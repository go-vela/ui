/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsByNumber } from './utils/buildMocks';
import {
  mockArtifacts,
  mockArtifactsEmpty,
  mockArtifactsError,
} from './utils/artifactMocks';
import { buildArtifactsPattern } from './utils/routes';

const artifactsTableSelector = '[data-test=build-artifacts-table]';

test.describe('Artifacts', () => {
  test.describe('server returning artifacts', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockArtifacts(page, 'artifacts.json');
      await app.login('/github/octocat/1/artifacts');
    });

    test('should show artifacts page', async ({ page }) => {
      await expect(page.locator(artifactsTableSelector)).toBeVisible();
    });

    test('should show artifact links', async ({ page }) => {
      const rows = page.locator(`${artifactsTableSelector} tbody tr`);
      await expect(rows).toHaveCount(3);
      await expect(rows.first()).toContainText('coverage.html');
      await expect(rows.nth(1)).toContainText('junit-report.json');
      await expect(rows.nth(2)).toContainText('test-results.xml');
    });

    test('artifact links should have correct href attributes', async ({
      page,
    }) => {
      const links = page.locator(`${artifactsTableSelector} a`);
      await expect(links.first()).toHaveAttribute(
        'href',
        'https://example.com/signed-url/coverage.html',
      );
      await expect(links.nth(1)).toHaveAttribute(
        'href',
        'https://example.com/signed-url/junit-report.json',
      );
      await expect(links.nth(2)).toHaveAttribute(
        'href',
        'https://example.com/signed-url/test-results.xml',
      );
    });
  });

  test.describe('server returning artifacts error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockArtifactsError(page);
      await app.login('/github/octocat/1/artifacts');
    });

    test('should show error message', async ({ page }) => {
      const output = page.locator('.artifact-output');
      await expect(output).toContainText('Failed to load artifacts');
      await expect(output).toContainText('HTTP 500');
    });
  });

  test.describe('server returning no artifacts', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockArtifactsEmpty(page);
      await app.login('/github/octocat/1/artifacts');
    });

    test('should show empty state message', async ({ page }) => {
      await expect(page.locator(artifactsTableSelector)).toBeVisible();
      await expect(page.locator(artifactsTableSelector)).toContainText(
        'No artifacts are available for this build. They may not have been generated or have expired.',
      );
    });
  });

  test.describe('artifact table structure', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockArtifacts(page, 'artifacts.json');
      await app.login('/github/octocat/1/artifacts');
    });

    test('should show all table headers', async ({ page }) => {
      await expect(page.locator(artifactsTableSelector)).toBeVisible();
      await expect(page.locator(`${artifactsTableSelector} th`)).toHaveCount(1);
      await expect(
        page.locator(artifactsTableSelector).getByText('Name'),
      ).toBeVisible();
    });

    test('should display artifacts in table rows', async ({ page }) => {
      await expect(
        page.locator(`${artifactsTableSelector} tbody tr`),
      ).toHaveCount(3);
    });
  });

  test.describe('loading state', () => {
    test('should show loading message while artifacts are loading', async ({
      page,
      app,
    }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      let releaseArtifacts: () => void = () => {};
      const artifactsGate = new Promise<void>(resolve => {
        releaseArtifacts = resolve;
      });

      await page.route(buildArtifactsPattern, route => {
        if (route.request().method() !== 'GET') {
          return route.fallback();
        }

        return artifactsGate.then(() =>
          route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ names: {} }),
          }),
        );
      });
      await app.login('/github/octocat/1/artifacts');
      await expect(page.locator('.artifact-output')).toContainText(
        'Loading artifacts...',
      );
      releaseArtifacts();
      await expect(page.locator(artifactsTableSelector)).toBeVisible();
    });
  });
});
