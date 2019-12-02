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
  context("visit build/steps with server error", () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithErrorLogs();
      cy.login("/someorg/somerepo/5");
      cy.get("[data-test=steps]").as("steps");
      cy.get("[data-test=step]").as("step");
      cy.get("[data-test=logs]").as("logs");
      cy.get("[data-test=step-header]")
        .children()
        .as("stepHeaders");
      cy.get("[data-test=full-build]").as("build");
      cy.get("@build")
        .get("[data-test=build-status]")
        .as("buildStatus");
    });

    it("build should have error style", () => {
      cy.get("@buildStatus").should("have.class", "-error");
    });

    it("build error should show", () => {
      cy.get("[data-test=build-error]").should("be.visible");
    });

    it("build error should contain error", () => {
      cy.get("[data-test=build-error]").contains("error:");
      cy.get("[data-test=build-error]").contains("failure authenticating");
    });

    it("first step should contain error", () => {
      cy.get("[data-test=step]")
        .first()
        .as("cloneStep");
      cy.get("@cloneStep")
        .should("be.visible")
        .click();
      cy.get("@cloneStep").contains("error:");
      cy.get("@cloneStep").contains("problem starting container");
    });

    it("last step should not contain error", () => {
      cy.get("[data-test=step]")
        .last()
        .as("echoStep");
      cy.get("@echoStep")
        .should("be.visible")
        .click({ force: true });
      cy.get("@echoStep").should("not.contain",  "error:");
      cy.get("@echoStep").contains("$");
      });
  });
});
