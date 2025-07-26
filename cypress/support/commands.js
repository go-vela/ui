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
  cy.intercept('GET', '/token-refresh*', { fixture: 'auth.json' });
  cy.visit(path);
});

// Login helper for site admin auth (accepts initial path to visit)
Cypress.Commands.add('loginAdmin', (path = '/') => {
  cy.intercept('GET', '/token-refresh*', { fixture: 'auth_admin.json' });
  cy.visit(path);
});

// Faking the act of logging in helper
Cypress.Commands.add('loggingIn', (path = '/') => {
  cy.intercept('GET', '*/token-refresh', { fixture: 'auth.json' });
  cy.intercept('GET', '/authenticate*', { fixture: 'auth.json' });

  cy.visit('/account/authenticate?code=deadbeef&state=1337', {
    onBeforeLoad: win => {
      win.localStorage.setItem('vela-redirect', `${path}`);
    },
  });
});

// Logout helper, clears refresh cookie
Cypress.Commands.add('loggedOut', (path = '/') => {
  cy.intercept('GET', '/token-refresh', {
    statusCode: 401,
    body: { message: 'unauthorized' },
  });

  cy.visit(path);
});

// Route stubbing helpers
Cypress.Commands.add('stubBuild', () => {
  cy.fixture('build_running.json').as('runningBuild');
  cy.fixture('build_pending.json').as('pendingBuild');
  cy.fixture('build_success.json').as('successBuild');
  cy.fixture('build_failure.json').as('failureBuild');
  cy.fixture('build_error.json').as('errorBuild');
  cy.fixture('build_canceled.json').as('cancelBuild');
  cy.fixture('build_pending_approval.json').as('pendingApprovalBuild');
  cy.fixture('build_approved.json').as('approvedBuild');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/1', {
    fixture: 'build_running.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/2', {
    fixture: 'build_pending.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/3', {
    fixture: 'build_success.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/4', {
    fixture: 'build_failure.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/5', {
    fixture: 'build_error.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/6', {
    fixture: 'build_canceled.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/7', {
    fixture: 'build_success.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/8', {
    fixture: 'build_pending_approval.json',
  });
  cy.intercept('GET', 'api/v1/repos/*/*/builds/9', {
    fixture: 'build_approved.json',
  });
});

Cypress.Commands.add('stubBuilds', () => {
  cy.fixture('builds_10a.json').as('buildsPage1');
  cy.fixture('builds_10b.json').as('buildsPage2');

  cy.intercept('GET', '*api/v1/repos/*/*/builds*', {
    fixture: 'builds_10a.json',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/github/octocat/builds?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/github/octocat/builds?page=2&per_page=10>; rel="last",`,
    },
  });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?page=2*', {
    fixture: 'builds_10b.json',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/github/octocat/builds?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/github/octocat/builds?page=1&per_page=10>; rel="prev",`,
    },
  });
});

Cypress.Commands.add('stubOrgBuilds', () => {
  cy.fixture('builds_10a.json').as('buildsPage1');
  cy.fixture('builds_10b.json').as('buildsPage2');

  cy.intercept('GET', '*api/v1/repos/vela/builds*', {
    fixture: 'builds_10a.json',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela/builds?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/vela/builds?page=2&per_page=10>; rel="last",`,
    },
  });
  cy.intercept('GET', '*api/v1/repos/vela/builds?page=2*', {
    fixture: 'builds_10b.json',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela/builds?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/vela/builds?page=1&per_page=10>; rel="prev",`,
    },
  });
});

Cypress.Commands.add('stubRepos', () => {
  cy.fixture('repositories_10a.json').as('reposPage1');
  cy.fixture('repositories_10b.json').as('reposPage2');
  cy.intercept('GET', '*api/v1/repos/vela*', {
    fixture: 'repositories_10a.json',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/vela?page=2&per_page=10>; rel="last",`,
    },
  });
  cy.intercept('GET', '*api/v1/repos/vela?page=2*', {
    fixture: 'repositories_10b.json',
    headers: {
      link: `<http://localhost:8888/api/v1/repos/vela?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/vela?page=1&per_page=10>; rel="prev",`,
    },
  });
});

Cypress.Commands.add('stubBuildsFilter', () => {
  cy.fixture('builds_all.json').as('buildsAll');
  cy.fixture('builds_push.json').as('buildsPush');
  cy.fixture('builds_pull.json').as('buildsPull');
  cy.fixture('builds_tag.json').as('buildsTag');
  cy.fixture('builds_comment.json').as('buildsComment');
  cy.fixture('builds_schedule.json').as('buildsSchedule');
  cy.intercept('GET', '*api/v1/repos/*/*/builds*', {
    fixture: 'builds_all.json',
  });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?event=push*', {
    fixture: 'builds_push.json',
  });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?event=pull*', {
    fixture: 'builds_pull.json',
  });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?event=tag*', {
    fixture: 'builds_tag.json',
  });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?event=deploy*', { body: '[]' });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?event=comment*', {
    fixture: 'builds_comment.json',
  });
  cy.intercept('GET', '*api/v1/repos/*/*/builds?event=schedule*', {
    fixture: 'builds_schedule.json',
  });
});

Cypress.Commands.add('stubStepsWithLogsAndSkipped', () => {
  cy.fixture('steps_5_skipped_step.json').as('steps');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 200,
    fixture: 'steps_5_skipped_step.json',
  });
  cy.fixture('logs').then(logs => {
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/1/logs', {
      statusCode: 200,
      body: logs[0],
    }).as('getLogs-1');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/2/logs', {
      statusCode: 200,
      body: logs[1],
    }).as('getLogs-2');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/3/logs', {
      statusCode: 200,
      body: logs[2],
    }).as('getLogs-3');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/4/logs', {
      statusCode: 200,
      body: logs[3],
    }).as('getLogs-4');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/5/logs', {
      statusCode: 200,
      body: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithLogs', () => {
  cy.fixture('steps_5.json').as('steps');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 200,
    fixture: 'steps_5.json',
  });
  cy.fixture('logs').then(logs => {
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/1/logs', {
      statusCode: 200,
      body: logs[0],
    }).as('getLogs-1');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/2/logs', {
      statusCode: 200,
      body: logs[1],
    }).as('getLogs-2');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/3/logs', {
      statusCode: 200,
      body: logs[2],
    }).as('getLogs-3');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/4/logs', {
      statusCode: 200,
      body: logs[3],
    }).as('getLogs-4');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/5/logs', {
      statusCode: 200,
      body: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithANSILogs', () => {
  cy.fixture('steps_5.json').as('steps');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 200,
    fixture: 'steps_5.json',
  });
  cy.fixture('logs_ansi').then(logs => {
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/1/logs', {
      statusCode: 200,
      body: logs[0],
    }).as('getLogs-1');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/2/logs', {
      statusCode: 200,
      body: logs[1],
    }).as('getLogs-2');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/3/logs', {
      statusCode: 200,
      body: logs[2],
    }).as('getLogs-3');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/4/logs', {
      statusCode: 200,
      body: logs[3],
    }).as('getLogs-4');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/5/logs', {
      statusCode: 200,
      body: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithLinkedLogs', () => {
  cy.fixture('steps_5.json').as('steps');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 200,
    fixture: 'steps_5.json',
  });
  cy.fixture('logs_links').then(logs => {
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/1/logs', {
      statusCode: 200,
      body: logs[0],
    }).as('getLogs-1');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/2/logs', {
      statusCode: 200,
      body: logs[1],
    }).as('getLogs-2');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/3/logs', {
      statusCode: 200,
      body: logs[2],
    }).as('getLogs-3');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/4/logs', {
      statusCode: 200,
      body: logs[3],
    }).as('getLogs-4');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/5/logs', {
      statusCode: 200,
      body: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithLargeLogs', () => {
  cy.fixture('steps_5.json').as('steps');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 200,
    fixture: 'steps_5.json',
  });
  cy.fixture('logs_large').then(log => {
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps/1/logs', {
      statusCode: 200,
      body: log,
    }).as('getLogs-1');
  });
});

Cypress.Commands.add('stubServicesWithANSILogs', () => {
  cy.fixture('services_5.json').as('services');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/services*', {
    statusCode: 200,
    fixture: 'services_5.json',
  });
  cy.fixture('logs_services_ansi').then(logs => {
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/services/1/logs', {
      statusCode: 200,
      body: logs[0],
    }).as('getLogs-1');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/services/2/logs', {
      statusCode: 200,
      body: logs[1],
    }).as('getLogs-2');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/services/3/logs', {
      statusCode: 200,
      body: logs[2],
    }).as('getLogs-3');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/services/4/logs', {
      statusCode: 200,
      body: logs[3],
    }).as('getLogs-4');
    cy.intercept('GET', 'api/v1/repos/*/*/builds/*/services/5/logs', {
      statusCode: 200,
      body: logs[4],
    }).as('getLogs-5');
  });
});

Cypress.Commands.add('stubStepsWithErrorLogs', () => {
  cy.fixture('steps_error.json').as('steps');
  cy.intercept('GET', 'api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 200,
    fixture: 'steps_error.json',
  });
  cy.fixture('logs').then(logs => {
    for (let i = 0; i < logs.length; i++) {
      cy.intercept(
        'GET',
        'api/v1/repos/*/*/builds/*/steps/' + logs[i]['step_id'] + '/logs',
        {
          statusCode: 200,
          body: logs[i],
        },
      );
    }
  });
});

Cypress.Commands.add('stubBuildsErrors', () => {
  cy.intercept('GET', '*api/v1/repos/*/*/builds*', {
    statusCode: 500,
    body: 'server error',
  });
});

Cypress.Commands.add('stubBuildErrors', () => {
  cy.intercept('GET', '*api/v1/repos/*/*/builds/*', {
    statusCode: 500,
    body: 'server error',
  });
});

Cypress.Commands.add('stubStepsErrors', () => {
  cy.intercept('GET', '*api/v1/repos/*/*/builds/*/steps*', {
    statusCode: 500,
    body: 'server error',
  });
});

Cypress.Commands.add('stubPipeline', () => {
  cy.fixture('pipeline.json').as('pipeline');
  cy.intercept('GET', '*api/v1/pipelines/*/*/*', {
    statusCode: 200,
    fixture: 'pipeline.json',
  });
});

Cypress.Commands.add('stubPipelineWithWarnings', () => {
  cy.fixture('pipeline_warnings.json').as('pipeline');
  cy.intercept('GET', '*api/v1/pipelines/*/*/*', {
    statusCode: 200,
    fixture: 'pipeline_warnings.json',
  });
});

Cypress.Commands.add('stubPipelineErrors', () => {
  cy.intercept('GET', '*api/v1/pipelines/*/*/*', {
    statusCode: 500,
    body: 'server error',
  });
});

Cypress.Commands.add('stubPipelineExpand', () => {
  cy.fixture('pipeline_expanded').as('expanded');
  cy.intercept('POST', '*api/v1/pipelines/*/*/*/expand*', {
    statusCode: 200,
    fixture: 'pipeline_expanded',
  }).as('expand');
});

Cypress.Commands.add('stubPipelineExpandErrors', () => {
  cy.intercept('POST', '*api/v1/pipelines/*/*/*/expand*', {
    statusCode: 500,
    body: 'server error',
  });
});

Cypress.Commands.add('stubPipelineTemplates', () => {
  cy.fixture('pipeline_templates.json').as('templates');
  cy.intercept('GET', '*api/v1/pipelines/*/*/*/templates*', {
    statusCode: 200,
    fixture: 'pipeline_templates.json',
  });
});

Cypress.Commands.add('stubPipelineTemplatesEmpty', () => {
  cy.intercept('GET', '*api/v1/pipelines/*/*/*/templates*', {
    statusCode: 200,
    body: {},
  });
});

Cypress.Commands.add('stubPipelineTemplatesErrors', () => {
  cy.intercept('GET', '*api/v1/pipelines/*/*/*/templates*', {
    statusCode: 500,
    body: 'server error',
  });
});

Cypress.Commands.add('hookPages', () => {
  cy.fixture('hooks_10a.json').as('hooksPage1');
  cy.fixture('hooks_10b.json').as('hooksPage2');
  cy.intercept('GET', '*api/v1/hooks/github/octocat*', {
    fixture: 'hooks_10a.json',
    headers: {
      link: `<http://localhost:8888/api/v1/hooks/github/octocat?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/hooks/github/octocat?page=2&per_page=10>; rel="last",`,
    },
  });
  cy.intercept('GET', '*api/v1/hooks/github/octocat?page=2*', {
    fixture: 'hooks_10b.json',
    headers: {
      link: `<http://localhost:8888/api/v1/hooks/github/octocat?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/hooks/github/octocat?page=1&per_page=10>; rel="prev",`,
    },
  });
});

Cypress.Commands.add('redeliverHook', () => {
  cy.intercept('POST', '*api/v1/hooks/*/*/*/redeliver', {
    body: 'hook * redelivered',
  });
});

Cypress.Commands.add('redeliverHookError', () => {
  cy.intercept('POST', '*api/v1/hooks/github/octocat/*/redeliver', {
    statusCode: 500,
    body: 'unable to redeliver hook',
  });
});

Cypress.Commands.add('workerPages', () => {
  cy.fixture('workers_10a.json').as('workersPage1');
  cy.fixture('workers_10b.json').as('workersPage2');
  cy.intercept('GET', '*api/v1/workers*', {
    fixture: 'workers_10a.json',
    headers: {
      link: `<http://localhost:8888/api/v1/workers?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/workers?page=2&per_page=10>; rel="last",`,
    },
  });
  cy.intercept('GET', '*api/v1/workers?page=2*', {
    fixture: 'workers_10b.json',
    headers: {
      link: `<http://localhost:8888/api/v1/workers?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/workers?page=1&per_page=10>; rel="prev",`,
    },
  });
});

Cypress.Commands.add('checkA11yForPage', (path = '/', opts = {}) => {
  cy.login(path);
  cy.injectAxe();
  cy.wait(2000);
  // excludes accessibility testing for Elm pop-up that only appears in Cypress and not on the actual UI
  cy.checkA11y(
    { exclude: ['[style*="padding-left: calc(1ch + 6px)"]'] },
    opts,
    terminalLog,
  );
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

function terminalLog(violations) {
  cy.task(
    'log',
    `${violations.length} accessibility violation${
      violations.length === 1 ? '' : 's'
    } ${violations.length === 1 ? 'was' : 'were'} detected`,
  );
  // pluck specific keys to keep the table readable
  const violationData = violations.map(
    ({ id, impact, description, nodes }) => ({
      id,
      impact,
      description,
      nodes: nodes.length,
    }),
  );

  cy.task('table', violationData);
}
