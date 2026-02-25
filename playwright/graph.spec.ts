/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Locator } from '@playwright/test';
import { test, expect } from './fixtures';
import {
  mockBuildErrors,
  mockBuildGraph,
  mockBuildsByNumber,
  mockBuildsErrors,
  mockBuildsList,
  mockStepsErrors,
} from './utils/buildMocks';
import { mockRepoDetail } from './utils/repoMocks';

async function setCheckbox(
  checkbox: Locator,
  label: Locator,
  checked: boolean,
): Promise<void> {
  const isChecked = await checkbox.isChecked();

  if (isChecked !== checked) {
    await label.click({ force: true });
  }

  if (checked) {
    await expect(checkbox).toBeChecked();
  } else {
    await expect(checkbox).not.toBeChecked();
  }
}

test.describe('Build Graph', () => {
  test.describe('logged in and server returning build graph error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildErrors(page);
      await mockBuildsErrors(page);
      await mockStepsErrors(page);
      await app.login('/github/octocat/1/graph');
    });

    test('error alert should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });
  });

  test.describe('logged in and server returning build graph, build, and steps', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsList(page, 'builds_5.json');
      await mockBuildsByNumber(page, { 4: 'build_success.json' });
      await mockBuildGraph(page, 'build_graph.json');
      await mockRepoDetail(page, 'repository.json');
      await app.login('/github/octocat/4/graph');
      await expect(page.locator('.elm-build-graph-root')).toBeVisible();
    });

    test('build graph root should be visible', async ({ page }) => {
      await expect(page.locator('.elm-build-graph-root')).toBeVisible();
    });

    test('node should reflect build information', async ({ page }) => {
      await expect(page.locator('.elm-build-graph-node-3')).toHaveAttribute(
        'id',
        '#3,init,success,false',
      );
      await expect(page.locator('.d3-build-graph-node-outline-3')).toHaveClass(
        /-success/,
      );
    });

    test('edge should contain build information', async ({ page }) => {
      await expect(page.locator('.elm-build-graph-edge-3-4')).toHaveAttribute(
        'id',
        '#3,4,success,false',
      );
      await expect(page.locator('.d3-build-graph-edge-path-3-4')).toHaveClass(
        /-success/,
      );
    });

    test('click node should apply focus', async ({ page }) => {
      const node = page.locator('.elm-build-graph-node-3');
      await expect(node).toHaveAttribute('id', '#3,init,success,false');
      await node.locator('a').first().click({ force: true });
      await expect(node).toHaveAttribute('id', '#3,init,success,true');
      await expect(page.locator('.d3-build-graph-node-outline-3')).toHaveClass(
        /-focus/,
      );
    });

    test('node styles should reflect status', async ({ page }) => {
      await expect(page.locator('.d3-build-graph-node-outline-0')).toHaveClass(
        /-pending/,
      );
      await expect(page.locator('.d3-build-graph-node-outline-1')).toHaveClass(
        /-running/,
      );
      await expect(page.locator('.d3-build-graph-node-outline-2')).toHaveClass(
        /-canceled/,
      );
      await expect(page.locator('.d3-build-graph-node-outline-3')).toHaveClass(
        /-success/,
      );
      await expect(page.locator('.d3-build-graph-node-outline-4')).toHaveClass(
        /-failure/,
      );
      await expect(page.locator('.d3-build-graph-node-outline-5')).toHaveClass(
        /-killed/,
      );
    });

    test('legend should show', async ({ page }) => {
      await expect(page.locator('.elm-build-graph-legend')).toBeVisible();
      await expect(page.locator('.elm-build-graph-legend-node')).toHaveCount(7);
    });

    test('actions should show', async ({ page }) => {
      await expect(page.locator('.elm-build-graph-actions')).toBeVisible();
      await expect(
        page.getByTestId('build-graph-action-toggle-services'),
      ).toBeVisible();
      await expect(
        page.getByTestId('build-graph-action-toggle-steps'),
      ).toBeVisible();
      await expect(page.getByTestId('build-graph-action-filter')).toBeVisible();
      await expect(
        page.getByTestId('build-graph-action-filter-clear'),
      ).toBeVisible();
    });

    test('click "show services" should hide services', async ({ page }) => {
      const servicesToggle = page.getByTestId(
        'build-graph-action-toggle-services',
      );
      const servicesLabel = page.locator(
        'label[for="checkbox-services-toggle"]',
      );
      const serviceNode = page.locator('.elm-build-graph-node-0');

      await setCheckbox(servicesToggle, servicesLabel, true);
      await expect(serviceNode).toHaveCount(1);
      await expect(serviceNode).toContainText('postgres');

      await setCheckbox(servicesToggle, servicesLabel, false);
      await expect(serviceNode).toHaveCount(0);

      await setCheckbox(servicesToggle, servicesLabel, true);
      await expect(serviceNode).toHaveCount(1);
      await expect(serviceNode).toContainText('postgres');
    });

    test('click "show steps" should hide steps', async ({ page }) => {
      const stepsToggle = page.getByTestId('build-graph-action-toggle-steps');
      const stepsLabel = page.locator('label[for="checkbox-steps-toggle"]');
      const stageNode = page.locator('.elm-build-graph-node-5');

      await setCheckbox(stepsToggle, stepsLabel, true);
      await expect(stageNode).toContainText('sleep');

      await setCheckbox(stepsToggle, stepsLabel, false);
      await expect(stageNode).not.toContainText('sleep');

      await setCheckbox(stepsToggle, stepsLabel, true);
      await expect(stageNode).toContainText('sleep');
    });

    test('filter input and clear button should control focus', async ({
      page,
    }) => {
      const node = page.locator('.elm-build-graph-node-5');
      await expect(node).toHaveAttribute('id', '#5,stage-a,killed,false');
      await expect(
        page.locator('.d3-build-graph-node-outline-5'),
      ).not.toHaveClass(/-focus/);
      await page.getByTestId('build-graph-action-filter').fill('stage-a');
      await expect(node).toHaveAttribute('id', '#5,stage-a,killed,true');
      await expect(page.locator('.d3-build-graph-node-outline-5')).toHaveClass(
        /-focus/,
      );
      await page
        .getByTestId('build-graph-action-filter-clear')
        .click({ force: true });
      await expect(
        page.locator('.d3-build-graph-node-outline-5'),
      ).not.toHaveClass(/-focus/);
    });

    test('click on step row should redirect to step logs', async ({ page }) => {
      await expect(page).toHaveURL(/\/github\/octocat\/4\/graph$/);
      await page.locator('[data-step-name="sleep"]').first().click({
        force: true,
      });
      await expect(page).toHaveURL(/\/github\/octocat\/4#5$/);
    });

    test('step should reflect build information', async ({ page }) => {
      await expect(
        page.locator('[data-test=build-graph-step-link] svg.-killed'),
      ).toBeVisible();
      await expect(
        page.locator('[data-test=build-graph-step-link] svg.-success'),
      ).toBeVisible();
    });
  });
});
