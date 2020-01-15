/*
 * Copyright (c) 2019 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context("Favorites", () => {
    context("logged out", () => {
      it("overview should not show the errors tray", () => {
        cy.visit("/");
        cy.get("[data-test=alerts]").should("be.not.visible");
      });
    });
  
    context("logged in", () => {
      beforeEach(() => {
        cy.server();
        cy.route("GET", "*api/v1/repos*", "fixture:repositories.json");
        cy.login();
      });
  
      it("stubbed repositories should not show the errors tray", () => {
        cy.get("[data-test=alerts]").should("be.not.visible");
      });
    });
  });
  