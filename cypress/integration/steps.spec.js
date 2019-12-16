context("org/repo Builds Page", () => {
  context("logged in and server returning builds, steps, and logs", () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithLogs();
      cy.login("/someorg/somerepo/1");
      cy.get("[data-test=steps]").as("steps");
      cy.get("[data-test=step]").as("step");
      cy.get("[data-test=step-header]")
        .children()
        .as("stepHeaders");
      cy.get("@stepHeaders").click({ force: true, multiple: true });
      cy.get("[data-test=logs-1]").as("logs");
      cy.get("@stepHeaders").click({ force: true, multiple: true });
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

    it("all 5 steps should have logs", () => {
      cy.get("[data-test=logs-1]").should("exist").contains("$");
      cy.get("[data-test=logs-2]").should("exist").contains("$");
      cy.get("[data-test=logs-3]").should("exist").contains("$");
      cy.get("[data-test=logs-4]").should("exist").contains("$");
      cy.get("[data-test=logs-5]").should("exist").contains("$");
      cy.get("[data-test=logs-6]").should("not.exist");
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
    context("click log line number", () => {
      beforeEach(() => {
        cy.get("@stepHeaders").click({ force: true, multiple: true });
        cy.get("@logs")
          .first()
          .within(() => {
            cy.get("[data-test=log-line-3]").as("line");
            cy.get("[data-test=log-line-num-3]").as("lineNumber");
          });
        cy.get("@lineNumber").click({ force: true });
      });

      it("line should be highlighted", () => {
        cy.get("@stepHeaders").click({ force: true, multiple: true });
        cy.get("@line").should("have.class", "-focus");
      });

      it("line number should contain correct link", () => {
        cy.get("@lineNumber").should("have.attr", "href", "#step:1:3");
      });

      it("browser path should contain step and line fragment", () => {
        cy.hash().should("eq", "#step:1:3");
      });

      context("click other log line number", () => {
        beforeEach(() => {
          cy.get("[data-test=logs-5]")
            .within(() => {
              cy.get("[data-test=log-line-2]").as("otherLine");
              cy.get("[data-test=log-line-num-2]").as("otherLineNumber");
            });
          cy.get("@otherLineNumber").click({ force: true });
          cy.get("@stepHeaders").click({ force: true, multiple: true });
        });
        it("original line should not be highlighted", () => {
          cy.get("@line").should("not.have.class", "-focus");
        });

        it("other line should be highlighted", () => {
          cy.get("@otherLine").should("have.class", "-focus");
        });

        it("browser path should contain other step and line fragment", () => {
          cy.hash().should("eq", "#step:5:2");
        });
      });
    });
    context("visit Build, then visit log line with fragment", () => {
      beforeEach(() => {
        cy.visit("/someorg/somerepo/1");
        cy.visit({'url': "/someorg/somerepo/1#step:2:2"});
      });
      it("line should be highlighted", () => {
        cy.get("@stepHeaders").click({ force: true, multiple: true });
        cy.get("[data-test=logs-2]")
        .within(() => {
          cy.get("[data-test=log-line-2]").as("line2:2");
          cy.get("[data-test=log-line-num-2]").as("lineNumber2:2");
        });
        cy.get("@line2:2").should("have.class", "-focus");
      });
    });
    context("visit Build, click log line, then visit log line with fragment", () => {
      beforeEach(() => {
        cy.visit("/someorg/somerepo/1");
        cy.get("@stepHeaders").first().click({ force: true, multiple: true });
        cy.get("[data-test=logs-1]")
          .within(() => {
            cy.get("[data-test=log-line-3]").as("line1:3");
            cy.get("[data-test=log-line-num-3]").as("lineNumber1:3");
          });
          cy.get("[data-test=logs-2]")
          .within(() => {
            cy.get("[data-test=log-line-2]").as("line2:2");
            cy.get("[data-test=log-line-num-2]").as("lineNumber2:2");
          });
        cy.get("@lineNumber1:3").click({ force: true });
        cy.visit({'url': "/someorg/somerepo/1#step:2:2"});
      });
      it("original line should not be highlighted", () => {
        cy.get("@line1:3").should("not.have.class", "-focus");
      });
      it("other line should be highlighted", () => {
        cy.get("@line2:2").should("have.class", "-focus");
      });
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
      cy.get("[data-test=step-header]")
        .children()
        .as("stepHeaders");
      cy.get("@stepHeaders").click({ force: true, multiple: true });
      cy.get("[data-test=logs-2]").as("logs");
      cy.get("@stepHeaders").click({ force: true, multiple: true });
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


    it("first step should not have 'last' styles", () => {
      cy.get("[data-test=step]")
        .first()
        .should("not.have.class", "-last");
    });

    it("last step should not contain error", () => {
      cy.get("[data-test=step]")
        .last()
        .as("echoStep");
      cy.get("@echoStep")
        .should("be.visible")
        .click({ force: true });
      cy.get("@echoStep").should("not.contain", "error:");
      cy.get("@echoStep").contains("$");
    });


    it("last step should have 'last' styles", () => {
      cy.get("[data-test=step]")
        .last()
        .should("have.class", "-last");
    });
  });
});
