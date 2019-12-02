/*
 * Copyright (c) 2019 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context("Hooks", () => {
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
        cy.login("/github/octocat/hooks");
      });

      it("should show an error", () => {
        cy.wait("@hooks")
        cy.get("[data-test=alert]")
          .should("not.exist");
      });
    });
});