/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Page } from '@playwright/test';
import { test, expect } from './fixtures';
import { mockBuildsByNumber, mockBuildsList } from './utils/buildMocks';
import {
  mockPipelineConfig,
  mockPipelineConfigError,
  mockPipelineExpand,
  mockPipelineExpandError,
  mockPipelineTemplates,
  mockPipelineTemplatesEmpty,
  mockPipelineTemplatesError,
} from './utils/pipelineMocks';
import { pipelineConfigPattern, pipelineExpandPattern } from './utils/routes';

async function clickExpandAndWait(page: Page) {
  const toggle = page.getByTestId('pipeline-expand-toggle');
  await toggle.scrollIntoViewIfNeeded();
  await Promise.all([
    page.waitForResponse(
      response =>
        pipelineExpandPattern.test(response.url()) &&
        response.request().method() === 'POST',
    ),
    toggle.click({ force: true }),
  ]);
}

async function clickRevertAndWait(page: Page) {
  const toggle = page.getByTestId('pipeline-expand-toggle');
  await toggle.scrollIntoViewIfNeeded();
  await Promise.all([
    page.waitForResponse(
      response =>
        pipelineConfigPattern.test(response.url()) &&
        response.request().method() === 'GET',
    ),
    toggle.click({ force: true }),
  ]);
}

test.describe('Pipeline', () => {
  test.describe('logged in and server returning pipeline configuration error and templates errors', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockPipelineConfigError(page, 500);
      await mockPipelineTemplatesError(page, 500);
      await app.login('/github/octocat/1/pipeline');
    });

    test('pipeline configuration error should show', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-configuration-error'),
      ).toBeVisible();
      await expect(
        page.getByTestId('pipeline-configuration-data'),
      ).toBeHidden();
    });

    test('pipeline templates error should show', async ({ page }) => {
      await expect(page.getByTestId('pipeline-templates-error')).toBeVisible();
      await expect(page.getByTestId('pipeline-templates-error')).toContainText(
        '500',
      );
    });

    test('error alert should show', async ({ page }) => {
      await expect(page.getByTestId('alerts')).toContainText('Error');
    });
  });

  test.describe('logged in and server returning empty pipeline templates', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockPipelineConfig(page, 'pipeline.json');
      await mockPipelineTemplatesEmpty(page);
      await app.login('/github/octocat/1/pipeline');
    });

    test('templates should not show', async ({ page }) => {
      await expect(page.locator('[data-test^=pipeline-template-]')).toHaveCount(
        0,
      );
    });

    test('expand pipeline should be visible', async ({ page }) => {
      await expect(page.getByTestId('pipeline-expand')).toBeVisible();
    });

    test('pipeline configuration data should show', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-configuration-data'),
      ).toBeVisible();
      await expect(
        page.getByTestId('pipeline-configuration-data'),
      ).toContainText('version');
    });
  });

  test.describe('logged in and server returning valid pipeline configuration and templates', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockPipelineConfig(page, 'pipeline.json');
      await mockPipelineExpand(page, 'pipeline_expanded.json');
      await mockPipelineTemplates(page, 'pipeline_templates.json');
      await app.login('/github/octocat/1/pipeline');
    });

    test('should show 3 templates', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-templates').locator('.template'),
      ).toHaveCount(3);
    });

    test('template1 should show name, source and link', async ({ page }) => {
      const template = page.getByTestId('pipeline-template-template1_name');
      await expect(template).toContainText('template1_name');
      await expect(template).toContainText(
        'github.com/github/octocat/template1.yml',
      );
      await expect(template).toContainText(
        'https://github.com/github/octocat/blob/main/template1.yml',
      );
    });

    test('expand templates should be visible', async ({ page }) => {
      await expect(page.getByTestId('pipeline-expand')).toBeVisible();
    });

    test('warnings should not be visible', async ({ page }) => {
      await expect(page.getByTestId('pipeline-warnings')).toBeHidden();
    });

    test.describe('click expand templates', () => {
      test.beforeEach(async ({ page }) => {
        await clickExpandAndWait(page);
      });

      test('should update path with expand query', async ({ page }) => {
        await expect(page).toHaveURL(/\?expand=true/);
      });

      test('should show revert expansion button', async ({ page }) => {
        await expect(page.getByTestId('pipeline-expand-toggle')).toContainText(
          'revert',
        );
      });

      test('pipeline configuration data should show', async ({ page }) => {
        await expect(
          page.getByTestId('pipeline-configuration-data'),
        ).toBeVisible();
        await expect(
          page.getByTestId('pipeline-configuration-data'),
        ).toContainText('version');
      });

      test.describe('click line number', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('config-line-num-2').click({ force: true });
        });

        test('should update path with line num', async ({ page }) => {
          await expect(page).toHaveURL(/#2$/);
        });

        test('other lines should not have focus style', async ({ page }) => {
          await expect(page.getByTestId('config-line-3')).not.toHaveClass(
            /-focus/,
          );
        });

        test('should set focus style on single line', async ({ page }) => {
          await expect(page.getByTestId('config-line-2')).toHaveClass(/-focus/);
        });
      });

      test.describe('click line number, then shift click other line number', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('config-line-num-2').click({ force: true });
          await page.keyboard.down('Shift');
          await page.getByTestId('config-line-num-5').click({ force: true });
          await page.keyboard.up('Shift');
        });

        test('should update path with range', async ({ page }) => {
          await expect(page).toHaveURL(/#2:5$/);
        });

        test('lines outside the range should not have focus style', async ({
          page,
        }) => {
          await expect(page.getByTestId('config-line-6')).not.toHaveClass(
            /-focus/,
          );
        });

        test('lines within the range should have focus style', async ({
          page,
        }) => {
          await expect(page.getByTestId('config-line-2')).toHaveClass(/-focus/);
          await expect(page.getByTestId('config-line-3')).toHaveClass(/-focus/);
          await expect(page.getByTestId('config-line-4')).toHaveClass(/-focus/);
        });
      });
    });

    test('pipeline configuration data should show', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-configuration-data'),
      ).toBeVisible();
      await expect(
        page.getByTestId('pipeline-configuration-data'),
      ).toContainText('version');
    });

    test('pipeline configuration data should respect yaml spacing', async ({
      page,
    }) => {
      await expect(page.getByTestId('config-line-1')).toContainText('version:');
      await expect(page.getByTestId('config-line-2')).toContainText('steps:');
    });

    test.describe('click line number', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('config-line-num-2').click({ force: true });
      });

      test('should update path with line num', async ({ page }) => {
        await expect(page).toHaveURL(/#2$/);
      });

      test('other lines should not have focus style', async ({ page }) => {
        await expect(page.getByTestId('config-line-3')).not.toHaveClass(
          /-focus/,
        );
      });

      test('should set focus style on single line', async ({ page }) => {
        await expect(page.getByTestId('config-line-2')).toHaveClass(/-focus/);
      });
    });

    test.describe('click line number, then shift click other line number', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('config-line-num-2').click({ force: true });
        await page.keyboard.down('Shift');
        await page.getByTestId('config-line-num-5').click({ force: true });
        await page.keyboard.up('Shift');
      });

      test('should update path with range', async ({ page }) => {
        await expect(page).toHaveURL(/#2:5$/);
      });

      test('lines outside the range should not have focus style', async ({
        page,
      }) => {
        await expect(page.getByTestId('config-line-6')).not.toHaveClass(
          /-focus/,
        );
      });

      test('lines within the range should have focus style', async ({
        page,
      }) => {
        await expect(page.getByTestId('config-line-2')).toHaveClass(/-focus/);
        await expect(page.getByTestId('config-line-3')).toHaveClass(/-focus/);
        await expect(page.getByTestId('config-line-4')).toHaveClass(/-focus/);
      });
    });
  });

  test.describe('logged in and server returning valid pipeline configuration and templates with expansion errors', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockPipelineConfig(page, 'pipeline.json');
      await mockPipelineExpandError(page, 500);
      await mockPipelineTemplates(page, 'pipeline_templates.json');
      await app.login('/github/octocat/1/pipeline');
    });

    test('should show 3 templates', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-templates').locator('.template'),
      ).toHaveCount(3);
    });

    test('should show pipeline configuration data', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-configuration-data'),
      ).toBeVisible();
    });

    test.describe('click expand pipeline', () => {
      test.beforeEach(async ({ page }) => {
        await clickExpandAndWait(page);
      });

      test('should update path with expand query', async ({ page }) => {
        await expect(page).toHaveURL(/\?expand=true/);
      });

      test('error alert should show', async ({ page }) => {
        await expect(page.getByTestId('alerts')).toContainText('Error');
      });

      test.describe('click expand pipeline again', () => {
        test.beforeEach(async ({ page }) => {
          await clickRevertAndWait(page);
        });

        test('should revert to valid pipeline configuration', async ({
          page,
        }) => {
          await expect(
            page.getByTestId('pipeline-configuration-error'),
          ).toBeHidden();
          await expect(
            page.getByTestId('pipeline-configuration-data'),
          ).toBeVisible();
        });
      });
    });
  });

  test.describe('logged in and server returning valid pipeline configuration (with warnings) and templates', () => {
    test.beforeEach(async ({ page, app }) => {
      await mockBuildsByNumber(page, { 1: 'build_success.json' });
      await mockBuildsList(page, 'builds_5.json');
      await mockPipelineConfig(page, 'pipeline_warnings.json');
      await mockPipelineExpand(page, 'pipeline_expanded.json');
      await mockPipelineTemplates(page, 'pipeline_templates.json');
      await app.login('/github/octocat/1/pipeline');
    });

    test('warnings should be visible', async ({ page }) => {
      await expect(page.getByTestId('pipeline-warnings')).toBeVisible();
    });

    test('should show 2 warnings', async ({ page }) => {
      await expect(
        page.getByTestId('pipeline-warnings').locator('.warning'),
      ).toHaveCount(2);
    });

    test('warning with line number should show line number button', async ({
      page,
    }) => {
      const button = page.getByTestId('warning-line-num-4');
      await expect(button).toBeVisible();
      await expect(button).not.toHaveClass(/-disabled/);
    });

    test('warning with line number should show content without line number', async ({
      page,
    }) => {
      const warning = page.getByTestId('warning-0').locator('.line-content');
      await expect(warning).toBeVisible();
      await expect(warning).not.toContainText('4');
      await expect(warning).toContainText('template');
    });

    test('warning without line number should replace button with dash', async ({
      page,
    }) => {
      await expect(page.getByTestId('warning-1')).toContainText('-');
    });

    test('warning without line number should content', async ({ page }) => {
      const warning = page.getByTestId('warning-1').locator('.line-content');
      await expect(warning).toBeVisible();
      await expect(warning).toContainText('secrets');
    });

    test('log line with warning should show annotation', async ({ page }) => {
      await expect(page.getByTestId('warning-annotation-line-4')).toBeVisible();
    });

    test('other lines should not show annotations', async ({ page }) => {
      await expect(page.getByTestId('warning-annotation-line-5')).toBeHidden();
    });

    test.describe('click warning line number', () => {
      test.beforeEach(async ({ page }) => {
        await page.getByTestId('warning-line-num-4').click({ force: true });
      });

      test('should update path with line num', async ({ page }) => {
        await expect(page).toHaveURL(/#4$/);
      });

      test('should set focus style on single line', async ({ page }) => {
        await expect(page.getByTestId('config-line-4')).toHaveClass(/-focus/);
      });
    });

    test.describe('click expand templates', () => {
      test.beforeEach(async ({ page }) => {
        await clickExpandAndWait(page);
      });

      test('should update path with expand query', async ({ page }) => {
        await expect(page).toHaveURL(/\?expand=true/);
      });

      test('should show pipeline expansion note', async ({ page }) => {
        await expect(
          page.getByTestId('pipeline-warnings-expand-note'),
        ).toContainText('note');
      });

      test('warning with line number should show disabled line number button', async ({
        page,
      }) => {
        const button = page.getByTestId('warning-line-num-4');
        await expect(button).toBeVisible();
        await expect(button).toHaveClass(/-disabled/);
      });

      test.describe('click warning line number', () => {
        test.beforeEach(async ({ page }) => {
          await page.getByTestId('warning-line-num-4').click({ force: true });
        });

        test('should not update path with line num', async ({ page }) => {
          await expect(page).not.toHaveURL(/#4$/);
        });

        test('other lines should not have focus style', async ({ page }) => {
          await expect(page.getByTestId('config-line-3')).not.toHaveClass(
            /-focus/,
          );
        });
      });
    });
  });
});
