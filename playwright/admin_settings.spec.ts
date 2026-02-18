/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockAdminSettings,
  mockAdminSettingsError,
  mockAdminSettingsUpdate,
} from './utils/adminSettingsMocks';

test.describe('Admin Settings', () => {
  test.describe('server returning error', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockAdminSettingsError(page, 500);
      await app.loginAdmin('/admin/settings');
    });

    test('should show an error', async ({ page }) => {
      await expect(page.getByTestId('alert')).toBeVisible();
      await expect(page.getByTestId('alert')).toContainText('Error');
    });
  });

  test.describe('server returning settings', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockAdminSettings(page, 'settings.json');
      await app.loginAdmin('/admin/settings');
    });

    test('compiler clone image should show', async ({ page }) => {
      await expect(page.getByTestId('input-clone-image')).toBeVisible();
    });

    test('compiler template depth should show', async ({ page }) => {
      await expect(page.getByTestId('input-template-depth')).toBeVisible();
    });

    test('compiler starlark exec limit should show', async ({ page }) => {
      await expect(page.getByTestId('input-starlark-exec-limit')).toBeVisible();
    });

    test('queue routes list should show', async ({ page }) => {
      const queueRoutes = page.getByTestId('editable-list-queue-routes');
      await expect(queueRoutes).toBeVisible();
      await expect(page.getByTestId('editable-list-item-vela')).toContainText(
        'vela',
      );
    });

    test('max dashboard repos should show', async ({ page }) => {
      await expect(page.getByTestId('input-max-dashboard-repos')).toBeVisible();
    });

    test('queue restart limit should show', async ({ page }) => {
      await expect(page.getByTestId('input-queue-restart-limit')).toBeVisible();
    });

    test.describe('form should allow editing', () => {
      test.beforeEach(async ({ page }) => {
        await mockAdminSettingsUpdate(page, 'settings_updated.json');
      });

      test('clone image should allow editing', async ({ page }) => {
        const cloneInput = page.getByTestId('input-clone-image');
        await cloneInput.clear();
        await cloneInput.fill('target/vela-git:abc123');

        await page.getByTestId('button-clone-image-update').click();

        await expect(page.getByTestId('alert')).toBeVisible();
        await expect(page.getByTestId('alert')).toContainText('Success');
        await expect(cloneInput).toHaveValue('target/vela-git:abc123');
      });

      test('editing above or below a limit should disable button', async ({
        page,
      }) => {
        const templateDepthInput = page.getByTestId('input-template-depth');
        await templateDepthInput.clear();
        await templateDepthInput.fill('999999');
        await expect(
          page.getByTestId('button-template-depth-update'),
        ).toBeDisabled();

        await templateDepthInput.fill('0');
        await expect(
          page.getByTestId('button-template-depth-update'),
        ).toBeDisabled();

        const maxDashboardInput = page.getByTestId('input-max-dashboard-repos');
        await maxDashboardInput.clear();
        await maxDashboardInput.fill('999999');
        await expect(
          page.getByTestId('button-max-dashboard-repos-update'),
        ).toBeDisabled();

        await maxDashboardInput.fill('0');
        await expect(
          page.getByTestId('button-max-dashboard-repos-update'),
        ).toBeDisabled();

        const queueRestartInput = page.getByTestId('input-queue-restart-limit');
        await queueRestartInput.clear();
        await queueRestartInput.fill('999999');
        await expect(
          page.getByTestId('button-queue-restart-limit-update'),
        ).toBeDisabled();

        await queueRestartInput.fill('0');
        await expect(
          page.getByTestId('button-queue-restart-limit-update'),
        ).toBeDisabled();
      });

      test.describe('list item should allow editing', () => {
        test('edit button should toggle save and remove buttons', async ({
          page,
        }) => {
          const queueRoutes = page.getByTestId('editable-list-queue-routes');
          const editButton = page.getByTestId('editable-list-item-vela-edit');
          const saveButton = page.getByTestId('editable-list-item-vela-save');
          const removeButton = page.getByTestId(
            'editable-list-item-vela-remove',
          );

          await expect(queueRoutes).toBeVisible();
          await expect(editButton).toBeVisible();
          await expect(saveButton).toBeHidden();
          await expect(removeButton).toBeHidden();

          await editButton.click({ force: true });
          await expect(editButton).toBeHidden();
          await expect(removeButton).toBeVisible();

          await saveButton.click({ force: true });
          await expect(saveButton).toBeHidden();
        });

        test('save button should skip non-edits', async ({ page }) => {
          const editButton = page.getByTestId('editable-list-item-vela-edit');
          const saveButton = page.getByTestId('editable-list-item-vela-save');

          await expect(editButton).toBeVisible();
          await expect(saveButton).toBeHidden();

          await editButton.click({ force: true });
          await saveButton.click({ force: true });
          await expect(saveButton).toBeHidden();
          await expect(
            page.getByTestId('editable-list-item-vela'),
          ).toContainText('vela');

          await editButton.click({ force: true });
          await page.getByTestId('input-editable-list-item-vela').clear();
          await saveButton.click({ force: true });
          await expect(saveButton).toBeHidden();
          await expect(
            page.getByTestId('editable-list-item-vela'),
          ).toContainText('vela');
          await expect(page.getByTestId('alert')).toHaveCount(0);
        });

        test('save button should save edits', async ({ page }) => {
          await page
            .getByTestId('editable-list-item-vela-edit')
            .click({ force: true });
          await page
            .getByTestId('input-editable-list-item-vela')
            .fill('vela123');
          await page
            .getByTestId('editable-list-item-vela-save')
            .click({ force: true });

          await expect(
            page.getByTestId('editable-list-item-vela-save'),
          ).toBeHidden();
          await expect(
            page.getByTestId('editable-list-item-vela123'),
          ).toContainText('vela123');
        });

        test('remove button should remove an item', async ({ page }) => {
          const scheduleList = page.getByTestId(
            'editable-list-schedule-allowlist',
          );
          await expect(scheduleList).toBeVisible();

          await page
            .locator('[data-test="editable-list-item-*-edit"]')
            .click({ force: true });
          await page
            .locator('[data-test="editable-list-item-*-remove"]')
            .click({ force: true });
          await expect(
            page.locator('[data-test="editable-list-item-*"]'),
          ).toBeHidden();
          await expect(
            page.getByTestId('editable-list-schedule-allowlist-no-items'),
          ).toBeVisible();

          await expect(page.getByTestId('alert')).toBeVisible();
          await expect(page.getByTestId('alert')).toContainText('Success');
        });

        test('* repo wildcard should show helpful text', async ({ page }) => {
          const scheduleList = page.getByTestId(
            'editable-list-schedule-allowlist',
          );
          await expect(scheduleList).toBeVisible();
          await expect(
            page.locator('[data-test="editable-list-item-*"]'),
          ).toContainText('all repos');
        });

        test('add item input header should add items', async ({ page }) => {
          await expect(
            page.getByTestId('editable-list-item-linux-large'),
          ).toHaveCount(0);

          await page
            .getByTestId('input-editable-list-queue-routes-add')
            .fill('linux-large');
          await page
            .getByTestId('button-editable-list-queue-routes-add')
            .click({ force: true });

          await expect(
            page.getByTestId('editable-list-item-linux-large'),
          ).toBeVisible();
        });
      });
    });
  });
});
