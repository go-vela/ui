const A11Y_OPTS = {
  runOnly: {
    type: "tag",
    values: ["section508", "best-practice", "wcag21aa", "wcag2aa"]
  }
};

context("Accessibility (a11y)", () => {
  context("Logged out", () => {
    it.skip("overview", () => {
      cy.clearSession();
      cy.visit("/account/login");
      cy.injectAxe();
      cy.wait(500);
      cy.checkA11y(A11Y_OPTS);
    });
  });

  context("Logged in", () => {
    beforeEach(() => {
      cy.clearSession();
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
    });

    it.skip("overview", () => {
      cy.checkA11yForPage("/", A11Y_OPTS);
    });

    it.skip("add repos", () => {
      cy.checkA11yForPage("/account/add-repos", A11Y_OPTS);
    });

    it.skip("settings", () => {
      cy.checkA11yForPage("/github/octocat/settings", A11Y_OPTS);
    });

    it.skip("repo page", () => {
      cy.checkA11yForPage("/someorg/somerepo", A11Y_OPTS);
    });

    it.skip("build page", () => {
      cy.login("/someorg/somerepo/1");
      cy.injectAxe();
      cy.wait(500);
      cy.get(".-last [data-test=step-header]").click();
      cy.checkA11y(A11Y_OPTS);
    });
  });
});
