/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { test, expect } from './fixtures';
import {
  mockAdminSettings,
  mockAdminSettingsError,
  mockAdminSettingsUpdate,
} from './utils/adminSettingsMocks';
import { readTestData } from './utils/testData';

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

      test('blocked images list should show', async ({ page }) => {
        const blockedImages = page.getByTestId('editable-list-blocked-images');
        await expect(blockedImages).toBeVisible();
        await expect(
          page.getByTestId('editable-list-item-alpine:latest'),
        ).toContainText('alpine:latest');
      });

      test('warn images list should show', async ({ page }) => {
        const warnImages = page.getByTestId('editable-list-warn-images');
        await expect(warnImages).toBeVisible();
        await expect(
          page.getByTestId('editable-list-item-busybox:latest'),
        ).toContainText('busybox:latest');
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

    test('secrets toggles should show', async ({ page }) => {
      const orgSecrets = page
        .getByTestId('checkbox-admin-secrets-org')
        .locator('input');
      const repoSecrets = page
        .getByTestId('checkbox-admin-secrets-repo')
        .locator('input');
      const sharedSecrets = page
        .getByTestId('checkbox-admin-secrets-shared')
        .locator('input');

      await expect(orgSecrets).toBeVisible();
      await expect(repoSecrets).toBeVisible();
      await expect(sharedSecrets).toBeVisible();

      await expect(orgSecrets).toBeChecked();
      await expect(repoSecrets).not.toBeChecked();
      await expect(sharedSecrets).toBeChecked();
    });

    test('scm org role map should show', async ({ page }) => {
      const orgRoleMap = page.getByTestId('editable-list-scm-org-role-map');
      await expect(orgRoleMap).toBeVisible();
      await expect(
        orgRoleMap.getByTestId('editable-list-item-admin'),
      ).toContainText('admin=admin');
    });

    test('scm repo role map should show', async ({ page }) => {
      const repoRoleMap = page.getByTestId('editable-list-scm-repo-role-map');
      await expect(repoRoleMap).toBeVisible();
      await expect(
        repoRoleMap.getByTestId('editable-list-item-maintain'),
      ).toContainText('maintain=write');
    });

    test('scm team role map should show', async ({ page }) => {
      const teamRoleMap = page.getByTestId('editable-list-scm-team-role-map');
      await expect(teamRoleMap).toBeVisible();
      await expect(
        teamRoleMap.getByTestId('editable-list-item-maintainer'),
      ).toContainText('maintainer=admin');
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

      test('secrets toggles should update', async ({ page }) => {
        const orgSecrets = page.getByTestId('checkbox-admin-secrets-org');
        const orgSecretsInput = orgSecrets.locator('input[type="checkbox"]');

        await expect(orgSecretsInput).toBeChecked();

        await orgSecrets.locator('label').click({ force: true });

        await expect(page.getByTestId('alert')).toBeVisible();
        await expect(page.getByTestId('alert')).toContainText('Success');
        await expect(orgSecretsInput).not.toBeChecked();
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

        test.describe('image restriction lists should allow editing', () => {
          test('blocked images list should add item', async ({ page }) => {
            const blockedList = page.getByTestId('editable-list-blocked-images');

            await expect(blockedList).toBeVisible();
            await expect(
              page.getByTestId('editable-list-item-python:3.12'),
            ).toHaveCount(0);

            await page
              .getByTestId('input-editable-list-blocked-images-image-add')
              .fill('python:3.12');
            await page
              .getByTestId('input-editable-list-blocked-images-reason-add')
              .fill('new blocked image');

            await page
              .getByTestId('button-editable-list-blocked-images-add')
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText('Success');
            await expect(
              page.getByTestId('editable-list-item-python:3.12'),
            ).toContainText('python:3.12');
          });

          test('blocked images list should update reason', async ({ page }) => {
            const blockedList = page.getByTestId('editable-list-blocked-images');

            await expect(blockedList).toBeVisible();
            await blockedList
              .getByTestId('button-editable-list-item-alpine:latest-edit')
              .click({ force: true });
            await blockedList
              .getByTestId('input-editable-list-item-alpine:latest')
              .fill('updated blocked reason');
            await blockedList
              .getByRole('button', { name: 'save' })
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText('Success');
            await expect(
              page.getByTestId('editable-list-item-alpine:latest'),
            ).toContainText('updated blocked reason');
          });

          test('blocked images list should remove item', async ({ page }) => {
            const settings = readTestData<Record<string, any>>('settings_updated.json');
            settings.compiler.blocked_images = [];
            await mockAdminSettingsUpdate(page, settings);

            const blockedList = page.getByTestId('editable-list-blocked-images');

            await expect(blockedList).toBeVisible();
            await blockedList
              .getByTestId('button-editable-list-item-alpine:latest-edit')
              .click({ force: true });
            await blockedList
              .getByRole('button', { name: 'remove' })
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText('Success');
            await expect(
              page.getByTestId('editable-list-item-alpine:latest'),
            ).toHaveCount(0);
          });

          test('warn images list should add item', async ({ page }) => {
            const warnList = page.getByTestId('editable-list-warn-images');

            await expect(warnList).toBeVisible();
            await expect(page.getByTestId('editable-list-item-node:20')).toHaveCount(
              0,
            );

            await page
              .getByTestId('input-editable-list-warn-images-image-add')
              .fill('node:20');
            await page
              .getByTestId('input-editable-list-warn-images-reason-add')
              .fill('new warn image');

            await page
              .getByTestId('button-editable-list-warn-images-add')
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText('Success');
            await expect(
              page.getByTestId('editable-list-item-node:20'),
            ).toContainText('node:20');
          });

          test('warn images list should update reason', async ({ page }) => {
            const warnList = page.getByTestId('editable-list-warn-images');

            await expect(warnList).toBeVisible();
            await warnList
              .getByTestId('button-editable-list-item-busybox:latest-edit')
              .click({ force: true });
            await warnList
              .getByTestId('input-editable-list-item-busybox:latest')
              .fill('updated warn reason');
            await warnList
              .getByRole('button', { name: 'save' })
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText('Success');
            await expect(
              page.getByTestId('editable-list-item-busybox:latest'),
            ).toContainText('updated warn reason');
          });

          test('warn images list should remove item', async ({ page }) => {
            const settings = readTestData<Record<string, any>>('settings_updated.json');
            settings.compiler.warn_images = [];
            await mockAdminSettingsUpdate(page, settings);

            const warnList = page.getByTestId('editable-list-warn-images');

            await expect(warnList).toBeVisible();
            await warnList
              .getByTestId('button-editable-list-item-busybox:latest-edit')
              .click({ force: true });
            await warnList
              .getByRole('button', { name: 'remove' })
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText('Success');
            await expect(
              page.getByTestId('editable-list-item-busybox:latest'),
            ).toHaveCount(0);
          });

          test('duplicate image add should show already exists message', async ({
            page,
          }) => {
            await page
              .getByTestId('input-editable-list-blocked-images-image-add')
              .fill('alpine:latest');
            await page
              .getByTestId('input-editable-list-blocked-images-reason-add')
              .fill('duplicate blocked image');

            await page
              .getByTestId('button-editable-list-blocked-images-add')
              .click({ force: true });

            await expect(page.getByTestId('alert')).toBeVisible();
            await expect(page.getByTestId('alert')).toContainText(
              "already exists in the blocked images list",
            );
          });
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

      test.describe('scm role maps should allow editing', () => {
        test('org role map should allow editing entries', async ({ page }) => {
          const orgRoleMap = page.getByTestId('editable-list-scm-org-role-map');

          await orgRoleMap
            .getByTestId('editable-list-item-member-edit')
            .click({ force: true });
          await orgRoleMap
            .getByTestId('input-editable-list-item-member')
            .fill('member=write');
          await orgRoleMap
            .getByTestId('editable-list-item-member-save')
            .click({ force: true });

          await expect(
            orgRoleMap.getByTestId('editable-list-item-member'),
          ).toContainText('member=write');
        });

        test('repo role map should allow editing entries', async ({ page }) => {
          const repoRoleMap = page.getByTestId(
            'editable-list-scm-repo-role-map',
          );

          await repoRoleMap
            .getByTestId('editable-list-item-triage-edit')
            .click({ force: true });
          await repoRoleMap
            .getByTestId('input-editable-list-item-triage')
            .fill('triage=write');
          await repoRoleMap
            .getByTestId('editable-list-item-triage-save')
            .click({ force: true });

          await expect(
            repoRoleMap.getByTestId('editable-list-item-triage'),
          ).toContainText('triage=write');
        });
      });
    });
  });
});
