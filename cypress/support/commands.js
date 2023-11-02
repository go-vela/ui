// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

// Fail on first error if not running in CI
// (until Cypress has built-in way to deal with this)
if (!Cypress.env('CI')) {
  afterEach(function onAfterEach() {
    // Skips all subsequent tests in a spec, and flags the whole run as failed
    if (this.currentTest.state === 'failed') {
      Cypress.runner.stop();
    }
  });
}

// Login helper (accepts initial path to visit)
Cypress.Commands.add('login', (path = '/') => {
  cy.server();
  cy.route('/token-refresh', 'fixture:auth.json');
  cy.visit(path);
});

// Faking the act of logging in helper
Cypress.Commands.add('loggingIn', (path = '/') => {
  cy.server();
  cy.route('/token-refresh', 'fixture:auth.json');
  cy.route('/authenticate*', 'fixture:auth.json');
  cy.visit('/account/authenticate?code=deadbeef&state=1337', {
    onBeforeLoad: win => {
      win.localStorage.setItem(
        'vela-redirect',
        `${Cypress.config('baseUrl')}${path}`,
      );
    },
  });
});

// Logout helper, clears refresh cookie
Cypress.Commands.add('loggedOut', (path = '/') => {
  cy.server();
  cy.route({
    method: 'GET',
    url: '/token-refresh',
    status: 401,
    response: { message: 'unauthorized' },
  });

  cy.visit(path);
});

// Route stubbing helpers
Cypress.Commands.add('stubBuild', () => {
  cy.server();
  cy.fixture('build_running.json').as('runningBuild');
  cy.fixture('build_pending.json').as('pendingBuild');
  cy.fixture('build_success.json').as('successBuild');
  cy.fixture('build_failure.json').as('failureBuild');
  cy.fixture('build_error.json').as('errorBuild');
  cy.fixture('build_canceled.json').as('cancelBuild');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/1',
    status: 200,
    response: '@runningBuild',
  });
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/2',
    status: 200,
    response: '@pendingBuild',
  });
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/3',
    status: 200,
    response: '@successBuild',
  });
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/4',
    status: 200,
    response: '@failureBuild',
  });
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/5',
    status: 200,
    response: '@errorBuild',
  });
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/6',
    status: 200,
    response: '@cancelBuild',
  });
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/7',
    status: 200,
    response: '@successBuild',
  });
});

Cypress.Commands.add('stubBuilds', () => {
  cy.server();
  cy.fixture('builds_10a.json').as('buildsPage1');
  cy.fixture('builds_10b.json').as('buildsPage2');

  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds*',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/github/octocat/builds?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/github/octocat/builds?page=2&per_page=10>; rel="last",`,
    },
    response: '@buildsPage1',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?page=2*',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/github/octocat/builds?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/github/octocat/builds?page=1&per_page=10>; rel="prev",`,
    },
    response: '@buildsPage2',
  });
});

Cypress.Commands.add('stubOrgBuilds', () => {
  cy.server();
  cy.fixture('builds_10a.json').as('buildsPage1');
  cy.fixture('builds_10b.json').as('buildsPage2');

  cy.route({
    method: 'GET',
    url: '*api/v1/repos/vela/builds*',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela/builds?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/vela/builds?page=2&per_page=10>; rel="last",`,
    },
    response: '@buildsPage1',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/vela/builds?page=2*',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela/builds?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/vela/builds?page=1&per_page=10>; rel="prev",`,
    },
    response: '@buildsPage2',
  });
});

Cypress.Commands.add('stubRepos', () => {
  cy.server();
  cy.fixture('repositories_10a.json').as('reposPage1');
  cy.fixture('repositories_10b.json').as('reposPage2');
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/vela*',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/vela?page=2&per_page=10>; rel="last",`,
    },
    response: '@reposPage1',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/vela?page=2*',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/vela?page=1&per_page=10>; rel="prev",`,
    },
    response: '@reposPage2',
  });
});

Cypress.Commands.add('stubBuildsFilter', () => {
  cy.server();
  cy.fixture('builds_all.json').as('buildsAll');
  cy.fixture('builds_push.json').as('buildsPush');
  cy.fixture('builds_pull.json').as('buildsPull');
  cy.fixture('builds_tag.json').as('buildsTag');
  cy.fixture('builds_comment.json').as('buildsComment');
  cy.fixture('builds_schedule.json').as('buildsSchedule');
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds*',
    response: '@buildsAll',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?event=push*',
    response: '@buildsPush',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?event=pull*',
    response: '@buildsPull',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?event=tag*',
    response: '@buildsTag',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?event=deploy*',
    response: '[]',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?event=comment*',
    response: '@buildsComment',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds?event=schedule*',
    response: '@buildsSchedule',
  });
});

Cypress.Commands.add('stubStepsWithLogsAndSkipped', () => {
  cy.server();
  cy.fixture('steps_5_skipped_step.json').as('steps');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/steps*',
    status: 200,
    response: '@steps',
  });
  cy.fixture('logs').then(logs => {
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/1/logs',
      status: 200,
      response: logs[0],
    }).as('getLogs-1');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/2/logs',
      status: 200,
      response: logs[1],
    }).as('getLogs-2');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/3/logs',
      status: 200,
      response: logs[2],
    }).as('getLogs-3');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/4/logs',
      status: 200,
      response: logs[3],
    }).as('getLogs-4');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/5/logs',
      status: 200,
      response: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithLogs', () => {
  cy.server();
  cy.fixture('steps_5.json').as('steps');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/steps*',
    status: 200,
    response: '@steps',
  });
  cy.fixture('logs').then(logs => {
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/1/logs',
      status: 200,
      response: logs[0],
    }).as('getLogs-1');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/2/logs',
      status: 200,
      response: logs[1],
    }).as('getLogs-2');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/3/logs',
      status: 200,
      response: logs[2],
    }).as('getLogs-3');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/4/logs',
      status: 200,
      response: logs[3],
    }).as('getLogs-4');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/5/logs',
      status: 200,
      response: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithANSILogs', () => {
  cy.server();
  cy.fixture('steps_5.json').as('steps');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/steps*',
    status: 200,
    response: '@steps',
  });
  cy.fixture('logs_ansi').then(logs => {
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/1/logs',
      status: 200,
      response: logs[0],
    }).as('getLogs-1');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/2/logs',
      status: 200,
      response: logs[1],
    }).as('getLogs-2');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/3/logs',
      status: 200,
      response: logs[2],
    }).as('getLogs-3');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/4/logs',
      status: 200,
      response: logs[3],
    }).as('getLogs-4');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/5/logs',
      status: 200,
      response: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithLinkedLogs', () => {
  cy.server();
  cy.fixture('steps_5.json').as('steps');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/steps*',
    status: 200,
    response: '@steps',
  });
  cy.fixture('logs_links').then(logs => {
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/1/logs',
      status: 200,
      response: logs[0],
    }).as('getLogs-1');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/2/logs',
      status: 200,
      response: logs[1],
    }).as('getLogs-2');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/3/logs',
      status: 200,
      response: logs[2],
    }).as('getLogs-3');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/4/logs',
      status: 200,
      response: logs[3],
    }).as('getLogs-4');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/5/logs',
      status: 200,
      response: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithLargeLogs', () => {
  cy.server();
  cy.fixture('steps_5.json').as('steps');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/steps*',
    status: 200,
    response: '@steps',
  });
  cy.fixture('logs_large').then(log => {
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/steps/1/logs',
      status: 200,
      response: log,
    }).as('getLogs-1');
  });
});

Cypress.Commands.add('stubServicesWithANSILogs', () => {
  cy.server();
  cy.fixture('services_5.json').as('services');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/services*',
    status: 200,
    response: '@services',
  });
  cy.fixture('logs_services_ansi').then(logs => {
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/services/1/logs',
      status: 200,
      response: logs[0],
    }).as('getLogs-1');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/services/2/logs',
      status: 200,
      response: logs[1],
    }).as('getLogs-2');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/services/3/logs',
      status: 200,
      response: logs[2],
    }).as('getLogs-3');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/services/4/logs',
      status: 200,
      response: logs[3],
    }).as('getLogs-4');
    cy.route({
      method: 'GET',
      url: 'api/v1/repos/*/*/builds/*/services/5/logs',
      status: 200,
      response: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithErrorLogs', () => {
  cy.server();
  cy.fixture('steps_error.json').as('steps');
  cy.route({
    method: 'GET',
    url: 'api/v1/repos/*/*/builds/*/steps*',
    status: 200,
    response: '@steps',
  });
  cy.fixture('logs').then(logs => {
    for (let i = 0; i < logs.length; i++) {
      cy.route({
        method: 'GET',
        url: 'api/v1/repos/*/*/builds/*/steps/' + logs[i]['step_id'] + '/logs',
        status: 200,
        response: logs[i],
      });
    }
  });
});

Cypress.Commands.add('stubBuildsErrors', () => {
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds*',
    status: 500,
    response: 'server error',
  });
});

Cypress.Commands.add('stubBuildErrors', () => {
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds/*',
    status: 500,
    response: 'server error',
  });
});

Cypress.Commands.add('stubStepsErrors', () => {
  cy.route({
    method: 'GET',
    url: '*api/v1/repos/*/*/builds/*/steps*',
    status: 500,
    response: 'server error',
  });
});

Cypress.Commands.add('stubPipeline', () => {
  cy.fixture('pipeline.json').as('pipeline');
  cy.route({
    method: 'GET',
    url: '*api/v1/pipelines/*/*/*',
    status: 200,
    response: '@pipeline',
  });
});

Cypress.Commands.add('stubPipelineErrors', () => {
  cy.route({
    method: 'GET',
    url: '*api/v1/pipelines/*/*/*',
    status: 500,
    response: 'server error',
  });
});

Cypress.Commands.add('stubPipelineExpand', () => {
  cy.fixture('pipeline_expanded').as('expanded');
  cy.route({
    method: 'POST',
    url: '*api/v1/pipelines/*/*/*/expand*',
    status: 200,
    response: '@expanded',
  });
});

Cypress.Commands.add('stubPipelineExpandErrors', () => {
  cy.route({
    method: 'POST',
    url: '*api/v1/pipelines/*/*/*/expand*',
    status: 500,
    response: 'server error',
  });
});

Cypress.Commands.add('stubPipelineTemplates', () => {
  cy.fixture('pipeline_templates.json').as('templates');
  cy.route({
    method: 'GET',
    url: '*api/v1/pipelines/*/*/*/templates*',
    status: 200,
    response: '@templates',
  });
});

Cypress.Commands.add('stubPipelineTemplatesEmpty', () => {
  cy.route({
    method: 'GET',
    url: '*api/v1/pipelines/*/*/*/templates*',
    status: 200,
    response: {},
  });
});

Cypress.Commands.add('stubPipelineTemplatesErrors', () => {
  cy.route({
    method: 'GET',
    url: '*api/v1/pipelines/*/*/*/templates*',
    status: 500,
    response: 'server error',
  });
});

Cypress.Commands.add('hookPages', () => {
  cy.server();
  cy.fixture('hooks_10a.json').as('hooksPage1');
  cy.fixture('hooks_10b.json').as('hooksPage2');
  cy.route({
    method: 'GET',
    url: '*api/v1/hooks/github/octocat*',
    headers: {
      link: `<http://localhost:8888/api/v1/hooks/github/octocat?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/hooks/github/octocat?page=2&per_page=10>; rel="last",`,
    },
    response: '@hooksPage1',
  });
  cy.route({
    method: 'GET',
    url: '*api/v1/hooks/github/octocat?page=2*',
    headers: {
      link: `<http://localhost:8888/api/v1/hooks/github/octocat?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/hooks/github/octocat?page=1&per_page=10>; rel="prev",`,
    },
    response: '@hooksPage2',
  });
});

Cypress.Commands.add('redeliverHook', () => {
  cy.server();
  cy.route({
    method: 'POST',
    url: '*api/v1/hooks/*/*/*/redeliver',
    response: 'hook * redelivered',
  });
});

Cypress.Commands.add('redeliverHookError', () => {
  cy.server();
  cy.route({
    method: 'POST',
    url: '*api/v1/hooks/github/octocat/*/redeliver',
    status: 500,
    response: 'unable to redeliver hook',
  });
});

Cypress.Commands.add('checkA11yForPage', (path = '/', opts = {}) => {
  cy.login(path);
  cy.injectAxe();
  cy.wait(500);
  // excludes accessibility testing for Elm pop-up that only appears in Cypress and not on the actual UI
  cy.checkA11y({ exclude: ['[style*="padding-left: calc(1ch + 6px)"]'] }, opts);
});

Cypress.Commands.add('setTheme', theme => {
  cy.window().then(win => {
    win.localStorage.setItem('vela-theme', theme);
  });
});

Cypress.Commands.add('clickSteps', theme => {
  cy.get('[data-test=step-header-1]').click({ force: true });
  cy.get('[data-test=step-header-2]').click({ force: true });
  cy.get('[data-test=step-header-3]').click({ force: true });
  cy.get('[data-test=step-header-4]').click({ force: true });
  cy.get('[data-test=step-header-5]').click({ force: true });
});

Cypress.Commands.add('clickServices', theme => {
  cy.get('[data-test=service-header-1]').click({ force: true });
  cy.get('[data-test=service-header-2]').click({ force: true });
  cy.get('[data-test=service-header-3]').click({ force: true });
  cy.get('[data-test=service-header-4]').click({ force: true });
  cy.get('[data-test=service-header-5]').click({ force: true });
});
