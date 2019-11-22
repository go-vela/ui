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
      cy.visit("/");
      cy.injectAxe();
      cy.checkA11y(A11Y_OPTS);
    });
  });

  context("Logged in", () => {
    beforeEach(() => {
      cy.clearSession();
      cy.server();
      cy.route("GET", "*api/v1/repos*", "fixture:overview_page.json");
      cy.route(
        "GET",
        "*api/v1/user/source/repos*",
        "fixture:add_repositories.json"
      );
      cy.login();
      cy.injectAxe();
    });

    it("overview", () => {
      cy.checkA11y(A11Y_OPTS);
    });

    it("add repos", () => {
      cy.visit("/account/add-repos");
      cy.injectAxe();
      cy.checkA11y(A11Y_OPTS);
    });
  });
});
