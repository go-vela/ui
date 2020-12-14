/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Contextual Help', () => {
  context('error loading resource', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: 'api/v1/user*',
        status: 500,
        response: {
          error: 'error fetching user',
        },
      });
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
      it('dropdown should contain error msg', () => {
        cy.get('[data-test=help-row] input')
          .invoke('val')
          .should('eq', 'something went wrong!');
      });
      it('dropdown footer should contain getting started docs', () => {
        cy.get('[data-test=help-footer]').contains('Getting Started Docs');
      });
    });
  });

  context('successfully loading resource with no cli support (yet)', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/user*', 'fixture:favorites_none.json');
      cy.visit('/');
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
      it('cmd header should contain feature request upvote link', () => {
        cy.get('[data-test=help-cmd-header]').contains('(upvote feature)');
      });
      it('cmd should contain not supported message', () => {
        cy.get('[data-test=help-row] input')
          .invoke('val')
          .should('eq', 'not yet supported via the CLI');
      });
      it('dropdown footer should contain installation and authentication docs', () => {
        cy.get('[data-test=help-footer]').contains('CLI Installation Docs');
        cy.get('[data-test=help-footer]').contains('CLI Authentication Docs');
      });
    });
  });
  context('successfully loading resource with cli support', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/repos/*/*/builds*', 'fixture:builds_5.json');
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
          cy.get('[data-test=alerts]').contains('Copied');
        });
      });
    });
  });
  context('visit page with no resources (not found)', () => {
    beforeEach(() => {
      cy.server();
      cy.visit('/notfound');
      cy.get('[data-test=help-trigger]').as('trigger');
    });

    it('should show the help button', () => {
      cy.get('@trigger').should('be.visible');
    });
    context('clicking help button', () => {
      beforeEach(() => {
        cy.get('@trigger').click();
      });
      it('dropdown should contain error msg', () => {
        cy.get('[data-test=help-row] input')
          .invoke('val')
          .should('eq', 'something went wrong!');
      });
      it('dropdown footer should contain getting started docs', () => {
        cy.get('[data-test=help-footer]').contains('Getting Started Docs');
      });
    });
  });
});
