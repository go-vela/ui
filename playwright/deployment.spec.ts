/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import { mockBuildsList } from './utils/buildMocks';
import {
  mockDeploymentConfig,
  mockDeploymentCreate,
  mockDeploymentsList,
  mockHooksList,
  mockRepoDetail,
} from './utils/deploymentMocks';

test.describe('Deployment', () => {
  test.describe('server returning deployments', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockDeploymentCreate(page, 'deployment.json');
      await mockDeploymentsList(page, 'deployments_5.json');
      await mockHooksList(page, []);
      await mockRepoDetail(page, 'repository.json');
      await mockBuildsList(page, 'builds_5.json');
      await mockDeploymentConfig(page, 'deployment_config.json');
      await app.loginWithUserFixture('user_admin.json');
    });

    test('add parameter button should be disabled', async ({ page }) => {
      await page.goto('/github/octocat/deployments/add');
      const addButton = page
        .getByTestId('parameters-inputs')
        .getByTestId('button-parameter-add');
      await expect(addButton).toBeVisible();
      await expect(addButton).toBeDisabled();
      await expect(addButton).toContainText('Add');
    });

    test('add parameter should work as intended', async ({ page }) => {
      await page.goto('/github/octocat/deployments/add');

      await expect(page.getByTestId('parameters-list').first()).toContainText(
        'no parameters defined',
      );

      const inputs = page.getByTestId('parameters-inputs');
      await inputs.getByTestId('input-parameter-key').fill('key1');
      await inputs.getByTestId('input-parameter-value').fill('val1');

      const addButton = inputs.getByTestId('button-parameter-add');
      await expect(addButton).toBeEnabled();
      await expect(addButton).toContainText('Add');
      await addButton.click();

      await expect(page.getByTestId('alerts')).toContainText('Success');

      await expect(
        page.getByTestId('button-parameter-remove-key1'),
      ).toBeVisible();
      await expect(inputs.getByTestId('input-parameter-key')).toHaveValue('');
      await expect(inputs.getByTestId('input-parameter-value')).toHaveValue('');

      await inputs.getByTestId('input-parameter-key').fill('key2');
      await inputs.getByTestId('input-parameter-value').fill('val2');
      await addButton.click();

      await inputs.getByTestId('input-parameter-key').fill('key3');
      await inputs.getByTestId('input-parameter-value').fill('val3');
      await addButton.click();

      const parametersList = page.getByTestId('parameters-list');
      await parametersList
        .locator(':scope > *')
        .first()
        .getByText('remove')
        .click();

      await expect(parametersList.locator(':scope > *').first()).toContainText(
        'key2=val2',
      );
      await expect(parametersList.locator(':scope > *').first()).toContainText(
        '$DEPLOYMENT_PARAMETER_KEY2',
      );
    });

    test('should handle multiple parameters', async ({ page }) => {
      await page.goto('/github/octocat/deployments/add');

      const inputs = page.getByTestId('parameters-inputs');
      await inputs.getByTestId('input-parameter-key').fill('key4');
      await inputs.getByTestId('input-parameter-value').fill('val4');
      await inputs.getByTestId('button-parameter-add').click();

      await inputs.getByTestId('input-parameter-key').fill('key5');
      await inputs.getByTestId('input-parameter-value').fill('val5');
      await inputs.getByTestId('button-parameter-add').click();

      const items = page.getByTestId('parameters-list').locator(':scope > *');
      await expect(items).toHaveCount(2);
      await expect(items.first().locator(':scope > *').first()).toContainText(
        'key4=val4',
      );
      await expect(items.last().locator(':scope > *').first()).toContainText(
        'key5=val5',
      );
    });

    test('add config parameters should work as intended', async ({ page }) => {
      await page.goto('/github/octocat/deployments/add');

      await expect(
        page.getByTestId('parameters-inputs-list').locator(':scope > *'),
      ).toHaveCount(3);

      const parameterItems = page.getByTestId('parameters-item-wrap');

      await expect(
        parameterItems.first().getByTestId('input-parameter-key'),
      ).toHaveValue('cluster_count');
      await expect(
        parameterItems.first().getByTestId('input-parameter-key'),
      ).toBeDisabled();
      await expect(
        parameterItems.first().getByTestId('input-parameter-value'),
      ).toHaveAttribute('type', 'number');
      await expect(
        parameterItems.first().getByTestId('input-parameter-value'),
      ).toHaveValue('');

      const selectItem = parameterItems.nth(1);
      await expect(selectItem.getByTestId('input-parameter-key')).toHaveValue(
        'entrypoint',
      );
      await expect(
        selectItem.getByTestId('input-parameter-key'),
      ).toBeDisabled();
      await expect(selectItem.getByTestId('custom-select')).toBeVisible();

      const selectOptions = selectItem.getByTestId('custom-select-options');
      await expect(selectOptions.locator(':scope > *')).toHaveCount(3);
      await expect(selectOptions.locator(':scope > *').first()).toBeHidden();
      await selectItem.getByTestId('custom-select').click();
      await expect(selectOptions.locator(':scope > *').first()).toBeVisible();
      await selectItem.getByTestId('custom-select').click();

      const textItem = parameterItems.last();
      await expect(textItem.getByTestId('input-parameter-key')).toHaveValue(
        'region',
      );
      await expect(textItem.getByTestId('input-parameter-key')).toBeDisabled();
      await expect(textItem.getByTestId('input-parameter-value')).toHaveValue(
        '',
      );
      await expect(
        textItem.locator('[data-test=input-parameter-value]:invalid'),
      ).toHaveCount(1);
    });

    test('parameter of bar=foo properly prepopulates deployment form', async ({
      page,
    }) => {
      await page.goto(
        '/github/octocat/deployments/add?description=Deployment%20request%20from%20Vela&parameters=bar%253Dfoo&ref=master&target=production&task=deploy%3Avela',
      );
      await expect(
        page.getByTestId('parameters-list').locator(':scope > *').first(),
      ).toContainText('bar=foo');
    });

    test('parameter of foo=bar=cat properly prepopulates deployment form', async ({
      page,
    }) => {
      await page.goto(
        '/github/octocat/deployments/add?description=Deployment%20request%20from%20Vela&parameters=foo%253Dbar%253Dcat&ref=master&target=production&task=deploy%3Avela',
      );
      await expect(
        page.getByTestId('parameters-list').locator(':scope > *').first(),
      ).toContainText('foo=bar=cat');
    });

    test('multiple parameters properly prepopulate deployment form', async ({
      page,
    }) => {
      await page.goto(
        '/github/octocat/deployments/add?description=Deployment%20request%20from%20Vela&parameters=bar%253Dfoo,foo%253Dbar%253Dcat&ref=master&target=production&task=deploy%3Avela',
      );

      const items = page.getByTestId('parameters-list').locator(':scope > *');
      await expect(items.first()).toContainText('foo=bar=cat');
      await expect(items.nth(1)).toContainText('bar=foo');
    });

    test('deployments table should show', async ({ page }) => {
      await page.goto('/github/octocat/deployments');
      await expect(page.getByTestId('deployments-table')).toBeVisible();
    });

    test('deployments table should contain deployments', async ({ page }) => {
      await page.goto('/github/octocat/deployments');
      await expect(page.getByTestId('deployments-row').first()).toContainText(
        'Deployment request from Vela',
      );
    });

    test('deployments table should list of parameters', async ({ page }) => {
      await page.goto('/github/octocat/deployments');
      await expect(
        page
          .getByTestId('deployments-row')
          .first()
          .getByTestId('cell-list-item-parameters'),
      ).toContainText('foo=bar');
    });
  });
});
