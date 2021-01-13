/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Authentication', () => {
  context('logged in - session exists', () => {
    beforeEach(() => {
      cy.login();
    });

    it('stays on the overview page', () => {
      cy.location('pathname').should('eq', '/');
    });

    it('shows the username near the logo', () => {
      cy.get('[data-test=identity]').contains('cookie cat');
    });

    it('redirects back to the overview page when trying to access login page', () => {
      cy.visit('/account/login');
      cy.location('pathname').should('eq', '/');
    });

    it('source-repos page does not redirect', () => {
      cy.visit('/account/source-repos');
      cy.location('pathname').should('eq', '/account/source-repos');
    });

    it('provides a logout link', () => {
      cy.get('[data-test=logout-link]')
        .should('have.prop', 'href')
        .and('equal', Cypress.config().baseUrl + '/account/logout');
    });

    // TODO: need to dynamically change return from call to
    // /refresh-token .. FIXTHIS
    //
    // it('logout redirects to login page', () => {
    //   cy.get('[data-test=identity]').click();
    //   cy.get('[data-test=logout-link]').click();
    //   cy.location('pathname').should('eq', '/account/login');
    // });
  });

  context('logged out', () => {
    beforeEach(() => {
      cy.loggedOut();
    });

    it('should show login page when visiting root', () => {
      cy.get('body').should('contain', 'Authorize Via');
    });

    it('should keep you on login page when visiting it', () => {
      cy.visit('/account/login');
      cy.location('pathname').should('eq', '/account/login');
    });

    it('visiting non-existent page should show login page', () => {
      cy.visit('/asdf');
      cy.get('body').should('contain', 'Authorize Via');
    });

    it('should say the application name near the logo', () => {
      cy.get('[data-test=identity]').contains('Vela');
    });

    it('should show the log in button', () => {
      cy.get('[data-test=login-button]')
        .should('be.visible')
        .and('have.text', 'GitHub');
    });
  });

  context('post-login redirect', () => {
    beforeEach(() => {
      cy.loggingIn('/Cookie/Cat');
    });

    it('should go directly to page requested', () => {
      cy.location('pathname').should('eq', '/Cookie/Cat');
    });
  });
});
