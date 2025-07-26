/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('My Settings', () => {
  beforeEach(() => {
    cy.login();
  });

  it('should show settings option in identity dropdown', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').should('exist').should('be.visible');
  });

  it('settings option should bring you to settings page', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();
    cy.location('pathname').should('eq', '/account/settings');
  });

  it('show auth token on page', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();
    cy.fixture('auth').then(auth => {
      cy.get('#token')
        .should('exist')
        .should('be.visible')
        .should('contain', auth.token);
    });
  });
});
