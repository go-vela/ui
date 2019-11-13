/*
 * Copyright (c) 2019 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context("Authentication", () => {
  context("logged in - sessionstorage item exists", () => {
    beforeEach(() => {
      cy.login();
    });

    it("stays on the overview page", () => {
      cy.location("pathname").should("eq", "/");
    });

    it("shows the username near the logo", () => {
      cy.get("[data-test=identity]").contains("cookie cat");
    });

    it("redirects back to the overview page when trying to access login page", () => {
      cy.visit("/account/login");
      cy.location("pathname").should("eq", "/");
    });

    it("add-repos page does not redirect", () => {
      cy.visit("/account/add-repos");
      cy.location("pathname").should("eq", "/account/add-repos");
    });

    it("provides a logout link", () => {
      cy.get("[data-test=logout-link]")
        .should("have.prop", "href")
        .and("equal", Cypress.config().baseUrl + "/account/logout");
    });

    it("logout redirects to login page", () => {
      cy.get("[data-test=identity]").click();
      cy.get("[data-test=logout-link]").click();
      cy.location("pathname").should("eq", "/account/login");
    });

    it("should wipe out sesionstorage on logout", () => {
      cy.get("[data-test=identity]").click();
      cy.get("[data-test=logout-link]").click();
      cy.window().then(win => {
        const ss = win.sessionStorage.getItem("vela");
        cy.expect(ss).to.be.null;
      });
    });
  });

  context("logged out", () => {
    beforeEach(() => {
      cy.window().then(win => {
        win.sessionStorage.removeItem("vela");
      });
    });

    it("empty values in sessionstorage object should redirect to login page", () => {
      cy.visit("/");
      cy.location("pathname").should("eq", "/account/login");
    });

    it("no sessionstorage item should redirect to login page", () => {
      cy.visit("/account/login");
      cy.location("pathname").should("eq", "/account/login");
    });

    it("visiting random pages sends you to login", () => {
      cy.visit("/asdf");
      cy.location("pathname").should("eq", "/account/login");
    });

    it("should say the application name near the logo", () => {
      cy.visit("/");
      cy.get("[data-test=identity]").contains("Vela");
    });

    it("should show the log in button", () => {
      cy.visit("/");
      cy.get("[data-test=login-button]")
        .should("be.visible")
        .and("have.text", "GitHub");
    });

    it("should send you to main page after authentication comes back from OAuth provider", () => {
      cy.server();
      cy.route({
        method: "GET",
        url: "/authenticate*",
        response: "fixture:auth.json",
        delay: 1000
      });
      cy.visit("/account/authenticate?code=deadbeef&state=1337", {
        onBeforeLoad: win => {
          win.sessionStorage.clear();
        }
      });

      cy.get("[data-test=page-h1]").contains("Authenticating");

      cy.location("pathname").should("eq", "/");
    });

    it("should redirect to login page and show an error if authentication fails", () => {
      cy.server();
      cy.route({
        method: "GET",
        url: "/authenticate*",
        status: 500,
        response: "server error"
      });
      cy.visit("/account/authenticate?code=deadbeef&state=1337", {
        onBeforeLoad: win => {
          win.sessionStorage.clear();
        }
      });

      cy.get("[data-test=page-h1]").contains("Authenticating");

      cy.get("[data-test=alerts]")
        .should("exist")
        .contains("Error");

      cy.location("pathname").should("eq", "/account/login");
    });
  });

  context("post-login redirect", () => {
    beforeEach(() => {
      cy.login("/Cookie/Cat", "redirect");
    });

    it("should redirect to the login page", () => {
      cy.location("pathname").should("eq", "/account/login");
    });

    it("shows the app name near the logo since no user has logged in yet", () => {
      cy.get("[data-test=identity]").contains("Vela");
    });

    it("should redirect to the original entrypoint after logging in", () => {
      cy.server();
      cy.route({
        method: "GET",
        url: "/authenticate*",
        response: "fixture:auth.json"
      });

      cy.visit("/account/authenticate?code=deadbeef&state=1337");

      cy.location("pathname").should("eq", "/Cookie/Cat");
    });
  });
});
