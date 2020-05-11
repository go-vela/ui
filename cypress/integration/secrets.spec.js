/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Secrets', () => {
  context('server returning secrets error', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/secrets/native/org/github/**',
        status: 500,
        response: 'server error',
      });
      cy.login('/-/secrets/native/org/github');
    });

    it('hooks table should not show', () => {
      cy.get('[data-test=secrets]').should('not.be.visible');
    });
    it('error should show', () => {
      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('Error');
    });
    it('error banner should show', () => {
      cy.get('[data-test=secrets-error]')
        .should('exist')
        .contains('try again later');
    });
  });
  context('server returning 5 secrets', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/org/github/**',
        'fixture:secrets_org_5.json',
      ).as('secrets');
      cy.login('/-/secrets/native/org/github');
    });

    it('secrets table should show', () => {
      cy.get('[data-test=secrets-table]').should('be.visible');
    });

    it('secrets table should show 5 secrets', () => {
      cy.get('[data-test=secrets-row]').should('have.length', 5);
    });

    it('pagination controls should not show', () => {
      cy.get('[data-test=pager-previous]').should('not.be.visible');
    });

    context('secret', () => {
      beforeEach(() => {
        cy.get('[data-test=secrets-row]')
          .first()
          .as('firstSecret');
        cy.get('[data-test=secrets-row]')
          .last()
          .as('lastSecret');
      });
      it('should show name', () => {
        cy.get('@firstSecret').within(() => {
          cy.get('[data-test=secrets-row-name]').contains('docker_username');
        });
        cy.get('@lastSecret').within(() => {
          cy.get('[data-test=secrets-row-name]').contains('deployment');
        });
      });
    });
  });

  // context('server returning 10 hooks', () => {
  //   beforeEach(() => {
  //     cy.server();
  //     cy.hookPages();

  //     cy.login('/github/octocat/hooks');
  //   });

  //   it('hooks table should show 10 hooks', () => {
  //     cy.get('[data-test=hook]').should('have.length', 10);
  //   });

  //   it('shows page 2 of the hooks', () => {
  //     cy.visit('/github/octocat/hooks?page=2');
  //     cy.get('[data-test=hook]').should('have.length', 10);
  //     cy.get('[data-test="crumb-hooks-(page-2)"]')
  //       .should('exist')
  //       .should('contain', 'page 2');

  //     cy.get('[data-test=pager-next]').should('be.disabled');
  //   });

  //   it("loads the first page when hitting the 'previous' button", () => {
  //     cy.visit('/github/octocat/hooks?page=2');
  //     cy.get('[data-test=pager-previous]')
  //       .should('have.length', 2)
  //       .first()
  //       .click();
  //     cy.location('pathname').should('eq', '/github/octocat/hooks');
  //   });
  // });
});
