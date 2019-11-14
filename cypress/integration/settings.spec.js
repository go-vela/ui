context("org/repo/settings Repo Settings Page", () => {
  context("logged in and X", () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithLogs();
      cy.login("/someorg/somerepo/1");
      cy.get("[data-test=steps]").as("steps");
      cy.get("[data-test=step]").as("step");
      cy.get("[data-test=logs]").as("logs");
      cy.get("[data-test=step-header]")
        .children()
        .as("stepHeaders");
    });

    it("X should show", () => {
    });
  });
});
