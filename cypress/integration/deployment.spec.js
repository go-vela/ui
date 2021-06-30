/*
 * Copyright (c) 2021 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Deployment', () => {
  context('server returning deployment', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/github/octocat/password*',
        'fixture:secret_repo.json',
      );
      cy.route(
        'POST',
        '*api/v1/deployments/github/octocat',
        'fixture:deployment.json',
      );
      cy.login('/github/octocat/deployment');
    });

    it('Add Parameter button should be disabled', () => {
      cy.get('[data-test=add-parameter-button]')
        .should('exist').should('not.be.enabled')
        .contains('Add');
    });
    it('Add Parameter should work as intended', () => {
      cy.get('[data-test=parameters-list]')
        .should('exist').children().first().should('contain.text', 'No Parameters defined');
      cy.get('[data-test=parameter-key-input]')
        .should('exist').type('key1');
      cy.get('[data-test=parameter-value-input]')
        .should('exist').type('val1');
      cy.get('[data-test=add-parameter-button]')
        .should('exist').should('be.enabled')
        .contains('Add').click();
      it('toast should show', () => {
        cy.get('[data-test=alerts]').should('exist').contains('Success');
      });
      cy.get('[data-test=parameters-list]')
        .should('exist').children().first().children().first().should('contain.text', 'key1=val1');
      cy.get('[data-test=parameter-key-input]')
        .should('exist').should('have.value', '');
      cy.get('[data-test=parameter-value-input]')
        .should('exist').should('have.value', '');
    });
  });
});
