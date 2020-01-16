/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Overview/Repositories Page', () => {
  context('logged in - repos loaded', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/repos*', 'fixture:overview_page.json');
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

    it('should show the Add Repositories button', () => {
      cy.get('[data-test=repo-enable]')
        .should('exist')
        .and('contain', 'Add Repositories');
    });

    it('Add Repositories should take you to the respective page', () => {
      cy.get('[data-test=repo-enable]').click();
      cy.location('pathname').should('eq', '/account/add-repos');
    });

    it('View button should exist for all repos', () => {
      cy.get('[data-test=repo-view]').should('have.length', 3);
    });

    it('it should take you to the repo build page when utilizing the View button', () => {
      cy.get('[data-test=repo-view]')
        .first()
        .click();
      cy.location('pathname').should('eq', '/DavidVader/applications');
    });
  });

  context('logged in - api returns paginated data', () => {
    it('should grab all the results', () => {
      cy.server();
      cy.fixture('repositories_100.json').as('reposPage1');
      cy.fixture('repositories_5.json').as('reposPage2');

      cy.route({
        method: 'GET',
        url: '*api/v1/repos?page=1&per_page=100*',
        headers: {
          link: `<http://localhost:8888/api/v1/repos?page=2&per_page=100>; rel="next", <http://localhost:8888/api/v1/repos?page=2&per_page=100>; rel="last",`,
        },
        response: '@reposPage1',
      });

      cy.route({
        method: 'GET',
        url: '*api/v1/repos?page=2&per_page=100*',
        headers: {
          link: `<http://localhost:8888/api/v1/repos?page=1&per_page=100>; rel="first", <http://localhost:8888/api/v1/repos?page=1&per_page=100>; rel="prev",`,
        },
        response: '@reposPage2',
      });
      cy.login();

      cy.get('[data-test=repo-item]').should('have.length', 105);
    });
  });
});
