// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

// Login helper (accepts initial path to vist and sessionstorage fixture)
Cypress.Commands.add("login", (path = "/", fixture = "sessionstorage") => {
  cy.fixture(fixture).then(sessionstorageSample => {
    cy.visit(path, {
      onBeforeLoad: win => {
        const serialized = JSON.stringify(sessionstorageSample);
        win.sessionStorage.setItem("vela", serialized);
      }
    });
  });
});

// Clear session storage helper
Cypress.Commands.add("clearSession", () => {
  cy.window().then(win => {
    win.sessionStorage.clear();
  });
});

// Route stubbing helpers
Cypress.Commands.add("stubBuild", () => {
  cy.server();
  cy.fixture("build_running.json").as("runningBuild");
  cy.fixture("build_pending.json").as("pendingBuild");
  cy.fixture("build_success.json").as("successBuild");
  cy.fixture("build_failure.json").as("failureBuild");
  cy.fixture("build_error.json").as("errorBuild");
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/1",
    status: 200,
    response: "@runningBuild"
  });
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/2",
    status: 200,
    response: "@pendingBuild"
  });
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/3",
    status: 200,
    response: "@successBuild"
  });
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/4",
    status: 200,
    response: "@failureBuild"
  });
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/5",
    status: 200,
    response: "@errorBuild"
  });
});

Cypress.Commands.add("stubBuilds", () => {
  cy.server();
  cy.fixture("builds_10a.json").as("buildsPage1");
  cy.fixture("builds_10b.json").as("buildsPage2");
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds*",
    headers: {
      link: `<http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=2&per_page=10>; rel="last",`
    },
    response: "@buildsPage1"
  });
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds?page=2*",
    headers: {
      link: `<http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=1&per_page=10>; rel="prev",`
    },
    response: "@buildsPage2"
  });
});

Cypress.Commands.add("stubStepsWithLogs", () => {
  cy.server();
  cy.fixture("steps_5.json").as("steps");
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/*/steps",
    status: 200,
    response: "@steps"
  });
  cy.fixture("logs").then(logs => {
    for (let i = 0; i < logs.length; i++) {
      cy.route({
        method: "GET",
        url: "api/v1/repos/*/*/builds/*/steps/" + logs[i]["step_id"] + "/logs",
        status: 200,
        response: logs[i]
      });
    }
  });
});

Cypress.Commands.add("stubStepsWithErrorLogs", () => {
  cy.server();
  cy.fixture("steps_error.json").as("steps");
  cy.route({
    method: "GET",
    url: "api/v1/repos/*/*/builds/*/steps",
    status: 200,
    response: "@steps"
  });
  cy.fixture("logs").then(logs => {
    for (let i = 0; i < logs.length; i++) {
      cy.route({
        method: "GET",
        url: "api/v1/repos/*/*/builds/*/steps/" + logs[i]["step_id"] + "/logs",
        status: 200,
        response: logs[i]
      });
    }
  });
});

Cypress.Commands.add("stubBuildsErrors", () => {
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds*",
    status: 500,
    response: "server error"
  });
});

Cypress.Commands.add("stubBuildErrors", () => {
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds/*",
    status: 500,
    response: "server error"
  });
});

Cypress.Commands.add("stubStepsErrors", () => {
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds/*/steps*",
    status: 500,
    response: "server error"
  });
});

Cypress.Commands.add("hookPages", () => {
  cy.server();
  cy.fixture("hooks_10a.json").as("hooksPage1");
  cy.fixture("hooks_10b.json").as("hooksPage2");
  cy.route({
    method: "GET",
    url: "*api/v1/hooks/github/octocat*",
    headers: {
      link: `<http://localhost:8888/api/v1/hooks/someorg/somerepo?page=2&per_page=10>; rel="next", <http://localhost:8888/api/v1/hooks/someorg/somerepo?page=2&per_page=10>; rel="last",`
    },
    response: "@hooksPage1"
  });
  cy.route({
    method: "GET",
    url: "*api/v1/hooks/github/octocat?page=2*",
    headers: {
      link: `<http://localhost:8888/api/v1/hooks/someorg/somerepo?page=1&per_page=10>; rel="first", <http://localhost:8888/api/v1/hooks/someorg/somerepo?page=1&per_page=10>; rel="prev",`
    },
    response: "@hooksPage2"
  });
});

Cypress.Commands.add("checkA11yForPage", (path = "/", opts = {}) => {
  cy.login(path);
  cy.injectAxe();
  cy.wait(500);
  cy.checkA11y(opts);
});
