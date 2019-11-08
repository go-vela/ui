context("org/repo/build View Build Page", () => {
  context("logged in and server returning single build", () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubBuilds();
      cy.login("/someorg/somerepo/1");
    });

    context("server returning 55 builds", () => {
      beforeEach(() => {
        cy.get("[data-test=build-history]").as("buildHistory");
      });

      it("build history should show", () => {
        cy.get("@buildHistory").should("be.visible");
      });

      it("build history should have 10 builds", () => {
        cy.get("@buildHistory").should("be.visible");
        cy.get("@buildHistory")
          .children()
          .should("have.length", 10);
      });

      it("clicking build history item should redirect to build page", () => {
        cy.get("@buildHistory")
          .children()
          .last()
          .click();
        cy.location("pathname").should("eq", "/someorg/somerepo/10");
      });

      context("hover build history item", () => {
        beforeEach(() => {
          cy.get("[data-test=build-history-tooltip]")
            .last()
            .as("tooltip");
        });

        it("should show build event", () => {
          cy.get("@tooltip").should("contain", "push");
        });

        it("should show build number", () => {
          cy.get("@tooltip").should("contain", "10");
        });

        it("should show build times", () => {
          cy.get("@tooltip").should("contain", "started");
          cy.get("@tooltip").should("contain", "finished");
        });
      });
    });

    context("server stubbed Restart Build", () => {
      beforeEach(() => {
        cy.server();
        cy.fixture("build_pending.json").as("restartedBuild");
        cy.route({
          method: "POST",
          url: "api/v1/repos/*/*/builds/*",
          status: 200,
          response: "@restartedBuild"
        });
        cy.get("[data-test=restart-build]").as("restartBuild");
      });

      it("clicking Restart Build should show alert", () => {
        cy.get("@restartBuild").click();
        cy.get("[data-test=alert]").should(
          "contain",
          "someorg/somerepo/1 restarted"
        );
      });

      it("clicking restarted build link should redirect to Build page", () => {
        cy.get("@restartBuild").click();
        cy.get("[data-test=alert-hyperlink]").click();
        cy.location("pathname").should("eq", "/someorg/somerepo/2");
      });
    });

    context("visit running build", () => {
      beforeEach(() => {
        cy.visit("/someorg/somerepo/1");
        cy.get("[data-test=full-build]").as("build");
        cy.get("@build")
          .get("[data-test=build-status]")
          .as("buildStatus");
      });

      it("build should show", () => {
        cy.get("@build").should("be.visible");
      });

      it("build should show commit hash", () => {
        cy.get("@build").should("contain", "9b1d8bd");
      });

      it("build should show branch", () => {
        cy.get("@build")
          .should("be.visible")
          .should("contain", "infra");
      });

      it("build should have running style", () => {
        cy.get("@buildStatus").should("have.class", "-running");
      });
    });

    context("visit pending build", () => {
      beforeEach(() => {
        cy.visit("/someorg/somerepo/2");
        cy.get("[data-test=full-build]").as("build");
        cy.get("@build")
          .get("[data-test=build-status]")
          .as("buildStatus");
      });

      it("build should have pending style", () => {
        cy.get("@buildStatus").should("have.class", "-pending");
      });
    });

    context("visit success build", () => {
      beforeEach(() => {
        cy.visit("/someorg/somerepo/3");
        cy.get("[data-test=full-build]").as("build");
        cy.get("@build")
          .get("[data-test=build-status]")
          .as("buildStatus");
      });

      it("build should have success style", () => {
        cy.get("@buildStatus").should("have.class", "-success");
      });
    });

    context("visit failure build", () => {
      beforeEach(() => {
        cy.visit("/someorg/somerepo/4");
        cy.get("[data-test=full-build]").as("build");
        cy.get("@build")
          .get("[data-test=build-status]")
          .as("buildStatus");
      });

      it("build should have failure style", () => {
        cy.get("@buildStatus").should("have.class", "-failure");
      });
    });
  });
});
