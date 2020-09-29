/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Errors', () => {
  context('logged out', () => {
    it('overview should not show the errors tray', () => {
      cy.visit('/');
      cy.get('[data-test=alerts]').should('be.not.visible');
    });
  });

  context('logged in', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/repos*', 'fixture:repositories.json');
      cy.login();
    });

    it('stubbed repositories should not show the errors tray', () => {
      cy.get('[data-test=alerts]').should('be.not.visible');
    });
  });

  context('over 10 errors', () => {
    beforeEach(() => {
      cy.login();

      cy.server();
      cy.route({
        method: 'GET',
        url: 'api/v1/user/source/repos*',
        status: 500,
        response: {
          error: 'error fetching source repositories',
        },
      }).as('sourceRepos');

      cy.visit('/account/source-repos');
      for (var i = 0; i < 10; i++) {
        cy.wait('@sourceRepos');
        cy.get('[data-test=refresh-source-repos]').click();
      }
      cy.wait('@sourceRepos');
    });

    it('should show the errors tray', () => {
      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('error fetching source repositories');
    });

    it('clicking alert should clear it', () => {
      cy.get('[data-test=alert]').first().as('alert');
      cy.get('@alert').should('exist').click({ force: true });
      cy.get('@alert').first().should('not.be.visible');
    });
  });
});
