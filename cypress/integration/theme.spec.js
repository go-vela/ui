const A11Y_OPTS = {
  runOnly: {
    type: "tag",
    values: ["section508", "best-practice", "wcag21aa", "wcag2aa"]
  }
};

context("Accessibility (a11y)", () => {
  context("Logged out", () => {
    it("overview", () => {
      cy.clearSession();
      cy.setTheme("theme-light");
      cy.visit("/account/login");
      cy.injectAxe();
      cy.wait(500);
      cy.checkA11y(A11Y_OPTS);
    });
  });

  context("Logged in", () => {
    beforeEach(() => {
      cy.clearSession();
      cy.setTheme("theme-light");
      cy.server();
      // overview page
      cy.route("GET", "*api/v1/repos*", "fixture:overview_page.json");
      // add repos page
      cy.route(
        "GET",
        "*api/v1/user/source/repos*",
        "fixture:add_repositories.json"
      );
      // settings page
      cy.route("GET", "*api/v1/repos/*/octocat", "fixture:repository.json");
      // repo and build page
      cy.stubBuilds();
      cy.stubBuild();
      cy.stubStepsWithLogs();
      // hooks page
      cy.route("GET", "*api/v1/hooks/github/octocat*", "fixture:hooks_5.json");
      cy.route(
        "GET",
        "*api/v1/repos/*/octocat/builds/1*",
        "fixture:build_success.json"
      );
      cy.route(
        "GET",
        "*api/v1/repos/*/octocat/builds/2*",
        "fixture:build_failure.json"
      );
      cy.route(
        "GET",
        "*api/v1/repos/*/octocat/builds/3*",
        "fixture:build_running.json"
      );
    });
    after(() => {
      cy.visit("/");
      cy.server({ enable: false });
    });

    it("overview", () => {
      cy.checkA11yForPage("/", A11Y_OPTS);
    });

    it("add repos", () => {
      cy.checkA11yForPage("/account/add-repos", A11Y_OPTS);
    });

    it("settings", () => {
      cy.checkA11yForPage("/github/octocat/settings", A11Y_OPTS);
    });

    it("repo page", () => {
      cy.checkA11yForPage("/someorg/somerepo", A11Y_OPTS);
    });

    it("hooks page", () => {
      cy.login("/github/octocat/hooks");
      cy.injectAxe();
      cy.wait(500);
      cy.get("[data-test=hook]").click({ multiple: true });
      cy.checkA11y(A11Y_OPTS);
    });

    it("build page", () => {
      cy.login("/someorg/somerepo/1");
      cy.injectAxe();
      cy.wait(500);
      cy.get("[data-test=step-header]").click({ multiple: true });
      cy.checkA11y(A11Y_OPTS);
    });
  });
});
