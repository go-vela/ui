/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Contextual Help', () => {
  context('error loading resource', () => {
    beforeEach(() => {
      cy.login();
      cy.get('[data-test=help-trigger]').as('trigger');
    });

    it('should show the help button', () => {
      cy.get('@trigger').should('be.visible');
    });

    context('clicking help button', () => {
      beforeEach(() => {
        cy.get('@trigger').click();
      });
      it('should show the dropdown', () => {
        cy.get('[data-test=help-tooltip]').should('be.visible');
      });
    });
  });

  context('successfully loading resource with cli support', () => {
    beforeEach(() => {
      cy.intercept('GET', '*api/v1/repos/*/*/builds*', {
        fixture: 'builds_5.json',
      });
      cy.login('/github/octocat');
      cy.get('[data-test=help-trigger]').as('trigger');
    });

    it('should show the help button', () => {
      cy.get('@trigger').should('be.visible');
    });

    context('clicking help button', () => {
      beforeEach(() => {
        cy.get('@trigger').click();
      });
      it('should show the dropdown', () => {
        cy.get('[data-test=help-tooltip]').should('be.visible');
      });
      it('cmd header should contain docs link', () => {
        cy.get('[data-test=help-cmd-header]').contains('(docs)');
      });
      it('cmd should contain cli command', () => {
        cy.get('[data-test=help-row] input')
          .invoke('val')
          .should('eq', 'vela get builds --org github --repo octocat');
      });
      it('dropdown footer should contain installation and authentication docs', () => {
        cy.get('[data-test=help-footer]').contains('CLI Installation Docs');
        cy.get('[data-test=help-footer]').contains('CLI Authentication Docs');
      });
      context('clicking copy button', () => {
        beforeEach(() => {
          cy.get('[data-test=help-copy]').as('copy');
        });
        it('should show copied alert', () => {
          cy.get('@copy').click();
          cy.get('[data-test=alerts]').contains('copied');
        });
      });
    });
  });
});
