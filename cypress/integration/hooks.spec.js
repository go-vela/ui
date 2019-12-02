/*
 * Copyright (c) 2019 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context("Hooks", () => {
  context("server returning hooks error", () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: "GET",
        url: "*api/v1/hooks/github/octocat*",
        status: 500,
        response: "server error"
      });
      cy.login("/github/octocat/hooks");
    });

    it("hooks table should not show", () => {
      cy.get("[data-test=hooks]").should("not.be.visible");
    });
    it("error should show", () => {
      cy.get("[data-test=alerts]")
        .should("exist")
        .contains("Error");
    });
    it("error banner should show", () => {
      cy.get("[data-test=hooks-error]")
        .should("exist")
        .contains("sorry");
    });
  });
  context("server returning 5 hooks", () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        "GET",
        "*api/v1/hooks/github/octocat*",
        "fixture:hooks_5.json"
      ).as("hooks");
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
      cy.login("/github/octocat/hooks");
    });

    it("hooks table should show", () => {
      cy.get("[data-test=hooks]").should("be.visible");
    });

    it("hooks table should show 5 hooks", () => {
      cy.get("[data-test=hook]").should("have.length", 5);
    });
    context("hook", () => {
      beforeEach(() => {
        cy.get("[data-test=hook]")
          .first()
          .as("firstHook");
        cy.get("[data-test=hook]")
          .last()
          .as("lastHook");
      });
      it("should show source id", () => {
        cy.get("@firstHook").within(() => {
          cy.get(".source-id").contains("7bd477e4-4415-11e9-9359-0d41fdf9567e");
        });
      });
      it("should show event", () => {
        cy.get("@firstHook").within(() => {
          cy.get(".event").contains("push");
        });
      });
      it("should show host", () => {
        cy.get("@firstHook").within(() => {
          cy.get(".host").contains("github.com");
        });
      });
      context("success", () => {
        beforeEach(() => {
          cy.get("@firstHook").within(() => {
            cy.get(".status").as("success");
          });
        });
        it("should contain success", () => {
          cy.get("@success").contains("success");
        });
        it("should have success styles", () => {
          cy.get("@success").should("have.class", "success");
        });
        context("expanded", () => {
          beforeEach(() => {
            cy.get("@firstHook").click();
          });
          context("build", () => {
            beforeEach(() => {
              cy.get("@firstHook").within(() => {
                cy.get(".info").as("build");
              });
            });
            it("should show number", () => {
              cy.get("@build")
                .should("be.visible")
                .contains("build:");
              cy.get("@build")
                .should("be.visible")
                .contains("github/octocat/3");
            });
            it("build number should redirect to build page", () => {
              cy.get("@build").within(() => {
                cy.get("[data-test=build-link]").click();
                cy.location("pathname").should("eq", "/github/octocat/3");
              });
            });
            it("should be running", () => {
              cy.get("@build")
                .get(".hook-build-status")
                .should("have.class", "-running");
            });
            it("should show duration", () => {
              cy.get("@build").contains("duration");
            });
          });
        });
      });
      context("failure", () => {
        beforeEach(() => {
          cy.get("@lastHook").within(() => {
            cy.get(".status").as("failure");
          });
        });
        it("should contain failure", () => {
          cy.get("@failure").contains("failure");
        });
        it("should have failure styles", () => {
          cy.get("@failure").should("have.class", "failure");
        });
        context("expanded", () => {
          beforeEach(() => {
            cy.get("@lastHook").click();
          });
          context("error", () => {
            beforeEach(() => {
              cy.get("@lastHook").within(() => {
                cy.get(".info").as("error");
              });
            });
            it("should show error", () => {
              cy.get("@error").contains(
                "github/octocat does not have tag events enabled"
              );
            });
          });
        });
      });
    });
  });
});
