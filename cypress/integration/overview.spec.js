/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Overview/Repositories Page', () => {
  context('logged in - favorites loaded', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/user*', 'fixture:favorites.json');
      cy.login();
    });

    it('should show two org groups', () => {
      cy.get('[data-test=repo-org]').should('have.length', 2);
    });

    it('should have one item in the first org and two in the second', () => {
      cy.get('[data-test=repo-org]:nth-child(1) [data-test=repo-item]').should(
        'have.length',
        1,
      );

      cy.get('[data-test=repo-org]:nth-child(2) [data-test=repo-item]').should(
        'have.length',
        2,
      );
    });

    it('should show the Source Repositories button', () => {
      cy.get('[data-test=source-repos]')
        .should('exist')
        .and('contain', 'Source Repositories');
    });

    it('Source Repositories should take you to the respective page', () => {
      cy.get('[data-test=source-repos]').click();
      cy.location('pathname').should('eq', '/account/source-repos');
    });

    it('View button should exist for all repos', () => {
      cy.get('[data-test=repo-view]').should('have.length', 3);
    });

    it('it should take you to the repo build page when utilizing the View button', () => {
      cy.get('[data-test=repo-view]').first().click();
      cy.location('pathname').should('eq', '/github/octocat');
    });
    it('org should show', () => {
      cy.get('[data-test=repo-org]').contains('org');
    });
    it('repo_a should show', () => {
      cy.get('[data-test=repo-item]').contains('repo_a');
    });
    context("type 'octo' into the home search bar", () => {
      beforeEach(() => {
        cy.get('[data-test=home-search-input]')
          .should('be.visible')
          .clear()
          .type('octo');
      });
      it('octocat should show', () => {
        cy.get('[data-test=repo-item]')
          .should('be.visible')
          .contains('octocat');
      });
      it('repo_a should not show', () => {
        cy.get('[data-test=repo-item]').should('not.contain', 'repo_a');
      });
      it('org should not show', () => {
        cy.get('[data-test=repo-org]').should('not.contain', 'org');
      });
    });
  });
});
