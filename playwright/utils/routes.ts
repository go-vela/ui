/*
 * SPDX-License-Identifier: Apache-2.0
 */

export const buildDetailPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/(\d+)$/;

export const buildListPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds(\?.*)?$/;

export const stepsListPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/steps(\?.*)?$/;

export const servicesListPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/services(\?.*)?$/;

export const buildCancelPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/cancel$/;

export const buildApprovePattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/approve$/;

export const sourceReposPattern = /\/api\/v1\/user\/source\/repos(\?.*)?$/;

export const repoEnablePattern = /\/api\/v1\/repos(\/[^/]+\/[^/]+)?$/;

export const adminSettingsPattern = /\/api\/v1\/admin\/settings(\?.*)?$/;

export const secretsListPattern =
  /\/api\/v1\/secrets\/[^/]+\/[^/]+\/[^/]+\/[^/]+(\?.*)?$/;

export const secretDetailPattern =
  /\/api\/v1\/secrets\/[^/]+\/[^/]+\/[^/]+\/[^/]+\/[^/]+$/;

export function stepLogsPattern(stepNumber: number): RegExp {
  return new RegExp(
    `/api/v1/repos/[^/]+/[^/]+/builds/\\d+/steps/${stepNumber}/logs$`,
  );
}

export function serviceLogsPattern(serviceNumber: number): RegExp {
  return new RegExp(
    `/api/v1/repos/[^/]+/[^/]+/builds/\\d+/services/${serviceNumber}/logs$`,
  );
}
