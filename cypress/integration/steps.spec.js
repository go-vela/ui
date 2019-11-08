context("org/repo Builds Page", () => {
  context("logged in and server returning builds, steps, and logs", () => {
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

    it("steps should show", () => {
      cy.get("@steps").should("be.visible");
    });

    it("5 steps should show", () => {
      cy.get("@steps")
        .children()
        .should("have.length", 5);
    });

    it("steps should be in order by number", () => {
      cy.get("@steps")
        .children()
        .first()
        .should("contain", "clone");

      cy.get("@steps")
        .children()
        .last()
        .should("contain", "echo");
    });

    it("all steps should have logs", () => {
      cy.get("@logs").should("have.length", 5);
    });

    it("logs should be base64 decoded", () => {
      // all test logs have a '$' encoded in the source
      cy.get("@logs")
        .children()
        .should("contain", "$");
    });

    it("clicking steps should show/hide logs", () => {
      cy.get("@logs")
        .children()
        .should("be.not.visible");

      cy.get("@stepHeaders").click({ force: true, multiple: true });

      cy.get("@logs")
        .children()
        .should("be.visible");

      cy.get("@stepHeaders").click({ force: true, multiple: true });
      cy.get("@logs")
        .children()
        .should("be.not.visible");
    });
  });
});
