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
      cy.route(
        'GET',
        '*api/v1/deployments/github/octocat/config',
        'fixture:deployment_config.json',
      )
      cy.route(
        'GET',
        '*api/v1/deployments/github/octocat/config?',
        'fixture:deployment_parameters.json',
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
      cy.get('[data-test=input-parameter-key]')
        .should('exist')
        .should('have.value', '');
      cy.get('[data-test=input-parameter-value]')
        .should('exist')
        .should('have.value', '');
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
