context("org/repo View Repository Builds Page", () => {
  context("logged in and server returning 55 builds and running build", () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuilds();
      cy.stubBuild();
      cy.login("/someorg/somerepo");

      cy.get("[data-test=builds]").as("builds");
      cy.get("@builds")
        .children()
        .first()
        .as("firstBuild");
      cy.get("@builds")
        .children()
        .last()
        .as("lastBuild");
    });

    it("builds should show", () => {
      cy.get("@builds").should("be.visible");
    });

    it("builds should show build number", () => {
      cy.get("@firstBuild")
        .should("exist")
        .should("contain", "#1");
      cy.get("@lastBuild")
        .should("exist")
        .should("contain", "#105");
    });

    it("builds should show commit hash", () => {
      cy.get("@firstBuild").should("contain", "9b1d8bd");
      cy.get("@lastBuild").should("contain", "7bd468e");
    });

    it("builds should show branch", () => {
      cy.get("@firstBuild")
        .should("be.visible")
        .should("contain", "infra");
      cy.get("@lastBuild")
        .should("be.visible")
        .should("contain", "feature/demo");
    });

    it("build should having running style", () => {
      cy.get("@firstBuild")
        .get("[data-test=build-status]")
        .should("be.visible")
        .should("have.class", "-running");
    });

    it("clicking build number should redirect to build page", () => {
      cy.get("@firstBuild")
        .get("[data-test=build-number]")
        .first()
        .click();
      cy.location("pathname").should("eq", "/someorg/somerepo/1");
    });
  });

  context("logged in and server returning builds error", () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuildsErrors();
      cy.login("/someorg/somerepo");
    });

    it("error alert should show", () => {
      cy.get("[data-test=alerts]")
        .should("exist")
        .contains("Error");
    });
  });

  context("logged out and server returning 55 builds", () => {
    beforeEach(() => {
      cy.clearSession();
      cy.server();
      cy.stubBuilds();
      cy.visit("/someorg/somerepo");
    });

    it("error alert should not show", () => {
      cy.get("[data-test=alerts]").should("be.not.visible");
    });

    it("builds should redirect to login", () => {
      cy.location("pathname").should("eq", "/account/login");
    });
  });
});
