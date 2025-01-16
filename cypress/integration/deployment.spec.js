/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Deployment', () => {
  context('server returning deployments', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'POST',
        '*api/v1/deployments/github/octocat',
        'fixture:deployment.json',
      );
      cy.route(
        'GET',
        '*api/v1/deployments/github/octocat*',
        'fixture:deployments_5.json',
      );
      cy.route('GET', '*api/v1/hooks/github/octocat*', []);
      cy.route('GET', '*api/v1/user', 'fixture:user_admin.json');
      cy.route(
        'GET',
        '*api/v1/repos/github/octocat',
        'fixture:repository.json',
      );
      cy.route(
        'GET',
        '*api/v1/repos/github/octocat/builds*',
        'fixture:builds_5.json',
      );
    });
    it('add parameter button should be disabled', () => {
      cy.login('/github/octocat/deployments/add');
      cy.get('[data-test=button-parameter-add]')
        .should('exist')
        .should('not.be.enabled')
        .contains('Add');
    });

    it('add parameter should work as intended', () => {
      cy.login('/github/octocat/deployments/add');
      cy.get('[data-test=parameters-list]')
        .should('exist')
        .children()
        .first()
        .should('contain.text', 'no parameters defined');
      cy.get('[data-test=input-parameter-key]').should('exist').type('key1');
      cy.get('[data-test=input-parameter-value]').should('exist').type('val1');
      cy.get('[data-test=button-parameter-add]')
        .should('exist')
        .should('be.enabled')
        .contains('Add')
        .click();

      cy.get('[data-test=parameters-list]')
        .should('exist');

      cy.get('[data-test=button-parameter-remove-key1]').should(
        'contain.text',
        'remove',
      );
      cy.get('[data-test=input-parameter-key]')
        .should('exist')
        .should('have.value', '');
      cy.get('[data-test=input-parameter-value]')
        .should('exist')
        .should('have.value', '');

      cy.get('[data-test=input-parameter-key]').type('key2');
      cy.get('[data-test=input-parameter-value]').type('val2');
      cy.get('[data-test=button-parameter-add]').click();
      cy.get('[data-test=copy-parameter-key2]').should('exist');

      cy.get('[data-test=input-parameter-key]').type('key3');
      cy.get('[data-test=input-parameter-value]').type('val3');
      cy.get('[data-test=button-parameter-add]').click();
      cy.get('[data-test=parameters-list]')
        .children()
        .first()
        .contains('remove')
        .click();
      cy.get('[data-test=parameters-list]')
        .should('exist')
        .children()
        .first()
        .should('contain.text', 'key2=val2remove$DEPLOYMENT_PARAMETER_KEY2');
    });

    it('should handle multiple parameters', () => {
      cy.login('/github/octocat/deployments/add');
      cy.get('[data-test=input-parameter-key]').type('key4');
      cy.get('[data-test=input-parameter-value]').type('val4');
      cy.get('[data-test=button-parameter-add]').click();
      cy.get('[data-test=input-parameter-key]').type('key5');
      cy.get('[data-test=input-parameter-value]').type('val5');
      cy.get('[data-test=button-parameter-add]').click();
      cy.get('[data-test=parameters-list]').children().should('have.length', 2);
      cy.get('[data-test=parameters-list]')
        .children()
        .first()
        .children()
        .first()
        .should('contain.text', 'key4=val4');
      cy.get('[data-test=parameters-list]')
        .children()
        .last()
        .children()
        .first()
        .should('contain.text', 'key5=val5');
    });

    it('deployments table should show', () => {
      cy.login('/github/octocat/deployments');
      cy.get('[data-test=deployments-table]').should('be.visible');
    });
    it('deployments table should contain deployments', () => {
      cy.login('/github/octocat/deployments');
      cy.get('[data-test=deployments-row]')
        .should('exist')
        .contains('Deployment request from Vela');
    });
    it('deployments table should list of parameters', () => {
      cy.login('/github/octocat/deployments');
      cy.get('[data-test=cell-list-item-parameters]')
        .should('exist')
        .contains('foo=bar');
    });
  });
});
