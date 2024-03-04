/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Deployment', () => {
  context('server returning deployment', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'POST',
        '*api/v1/deployments/github/octocat',
        'fixture:deployment.json',
      );
      cy.login('/github/octocat/deployments/add');
    });

    it('add parameter button should be disabled', () => {
      cy.get('[data-test=add-parameter-button]')
        .should('exist')
        .should('not.be.enabled')
        .contains('Add');
    });
    it('add parameter should work as intended', () => {
      cy.get('[data-test=parameters-list]')
        .should('exist')
        .children()
        .first()
        .should('contain.text', 'no parameters defined');
      cy.get('[data-test=parameter-key]').should('exist').type('key1');
      cy.get('[data-test=parameter-value]').should('exist').type('val1');
      cy.get('[data-test=add-parameter-button]')
        .should('exist')
        .should('be.enabled')
        .contains('Add')
        .click();
      it('toast should show', () => {
        cy.get('[data-test=alerts]').should('exist').contains('Success');
      });
      cy.get('[data-test=parameters-list]')
        .should('exist')
        .children()
        .first()
        .children()
        .last()
        .should('contain.text', 'remove');
      cy.get('[data-test=parameter-key]')
        .should('exist')
        .should('have.value', '');
      cy.get('[data-test=parameter-value]')
        .should('exist')
        .should('have.value', '');
    });
  });
});
