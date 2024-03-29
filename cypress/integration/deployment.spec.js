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
<<<<<<< HEAD
      cy.get('[data-test=add-parameter-button]')
=======
      cy.get('[data-test=button-parameter-add]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
      cy.get('[data-test=parameter-key]').should('exist').type('key1');
      cy.get('[data-test=parameter-value]').should('exist').type('val1');
      cy.get('[data-test=add-parameter-button]')
=======
      cy.get('[data-test=input-parameter-key]').should('exist').type('key1');
      cy.get('[data-test=input-parameter-value]').should('exist').type('val1');
      cy.get('[data-test=button-parameter-add]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
      cy.get('[data-test=parameter-key]')
        .should('exist')
        .should('have.value', '');
      cy.get('[data-test=parameter-value]')
=======
      cy.get('[data-test=input-parameter-key]')
        .should('exist')
        .should('have.value', '');
      cy.get('[data-test=input-parameter-value]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
        .should('exist')
        .should('have.value', '');
    });
  });
});
