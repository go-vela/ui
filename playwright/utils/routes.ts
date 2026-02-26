/*
 * SPDX-License-Identifier: Apache-2.0
 */

export const buildDetailPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/(\d+)$/;

export const buildListPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/?(\?.*)?$/;

export const stepsListPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/steps(\?.*)?$/;

export const servicesListPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/services(\?.*)?$/;

export const buildCancelPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/cancel$/;

export const buildApprovePattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/approve$/;

export const buildGraphPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/graph$/;

export const buildArtifactsPattern =
  /\/api\/v1\/repos\/[^/]+\/[^/]+\/builds\/\d+\/storage\/?$/;

export const orgBuildsPattern = /\/api\/v1\/repos\/[^/]+\/builds(\?.*)?$/;

export const pipelineConfigPattern =
  /\/api\/v1\/pipelines\/[^/]+\/[^/]+\/[^/]+(\?.*)?$/;

export const pipelineExpandPattern =
  /\/api\/v1\/pipelines\/[^/]+\/[^/]+\/[^/]+\/expand(\?.*)?$/;

export const pipelineTemplatesPattern =
  /\/api\/v1\/pipelines\/[^/]+\/[^/]+\/[^/]+\/templates(\?.*)?$/;

export const sourceReposPattern = /\/api\/v1\/user\/source\/repos(\?.*)?$/;

export const repoEnablePattern = /\/api\/v1\/repos(\/[^/]+\/[^/]+)?\/?(\?.*)?$/;

export const adminSettingsPattern = /\/api\/v1\/admin\/settings(\?.*)?$/;

export const secretsListPattern =
  /\/api\/v1\/secrets\/[^/]+\/[^/]+\/[^/]+\/[^/]+(\?.*)?$/;

export const secretDetailPattern =
  /\/api\/v1\/secrets\/[^/]+\/[^/]+\/[^/]+\/[^/]+\/[^/]+$/;

export const userDashboardsPattern = /\/api\/v1\/user\/dashboards(\?.*)?$/;

export const dashboardDetailPattern = /\/api\/v1\/dashboards\/[^/]+(\?.*)?$/;

export const deploymentsListPattern =
  /\/api\/v1\/deployments\/[^/]+\/[^/]+(\?.*)?$/;

export const deploymentConfigPattern =
  /\/api\/v1\/deployments\/[^/]+\/[^/]+\/config(\?.*)?$/;

export const hooksListPattern = /\/api\/v1\/hooks\/[^/]+\/[^/]+(\?.*)?$/;

export const hookRedeliverPattern =
  /\/api\/v1\/hooks\/[^/]+\/[^/]+\/[^/]+\/redeliver$/;

export const schedulesListPattern =
  /\/api\/v1\/schedules\/[^/]+\/[^/]+(\?.*)?$/;

export const scheduleDetailPattern =
  /\/api\/v1\/schedules\/[^/]+\/[^/]+\/[^/]+$/;

export const repoDetailPattern = /\/api\/v1\/repos\/[^/]+\/[^/]+(\?.*)?$/;

export const repoChownPattern = /\/api\/v1\/repos\/[^/]+\/[^/]+\/chown$/;

export const repoRepairPattern = /\/api\/v1\/repos\/[^/]+\/[^/]+\/repair$/;

export const orgReposPattern = /\/api\/v1\/repos\/[^/]+(\?.*)?$/;

export const reposListPattern = /\/api\/v1\/repos(\/[^/]+)?(\?.*)?$/;

export const userPattern = /\/api\/v1\/user\/?(\?.*)?$/;

export const workersListPattern = /\/api\/v1\/workers\/?(\?.*)?$/;

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
