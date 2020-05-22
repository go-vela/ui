/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Crumbs', () => {
  context('logged in - sessionstorage item exists', () => {
    beforeEach(() => {
      cy.login();
    });

    it('visit / should show overview', () => {
      cy.get('[data-test=crumb-overview]').should('exist').contains('Overview');
    });

    it('visit /account/add-repos should have Overview with link', () => {
      cy.visit('/account/add-repos');
      cy.get('[data-test=crumb-overview]')
        .should('exist')
        .contains('a', 'Overview');
    });

    it('visit /account/add-repos should have Account without link', () => {
      cy.visit('/account/add-repos');
      cy.get('[data-test=crumb-account]').should('exist').contains('Account');
    });

    it('visit /account/add-repos should have Add Repositories without link', () => {
      cy.visit('/account/add-repos');
      cy.get('[data-test=crumb-add-repositories]')
        .should('exist')
        .contains('Add Repositories');
    });

    it('visit /account/add-repos Overview crumb should redirect to Overview page', () => {
      cy.visit('/account/add-repos');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit /org/repo should show org and repo crumbs', () => {
      cy.visit('/org/repo');
      cy.get('[data-test=crumb-org]').should('exist');
      cy.get('[data-test=crumb-repo]').should('exist');
    });

    it('visit /org/repo Overview crumb should redirect to Overview page', () => {
      cy.visit('/org/repo');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit /org/repo/build Overview crumb should redirect to Overview page', () => {
      cy.visit('/org/repo/1');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit bad build /org/repo/build should not show not-found crumb', () => {
      cy.visit('/org/repo/1');
      cy.get('[data-test=crumb-not-found]').should('not', 'exist');
    });
  });
});
