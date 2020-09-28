/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Source Repositories', () => {
  context('logged in', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/user/source/repos*',
        'fixture:source_repositories.json',
      ).as('sourceRepos');
      cy.route('POST', '*api/v1/repos*', 'fixture:enable_repo_response.json');
      cy.login('/account/source-repos');
    });

    it('should show the orgs', () => {
      cy.get('[data-test=source-repos] .details').should('have.length', 3);
    });

    it('toggles visibility of repos in an org', () => {
      cy.get('[data-test=source-org-cat]').as('catOrg');
      cy.get('[data-test=source-org-cat] ~ [data-test^=source-repo]').as(
        'catRepos',
      );

      // show
      cy.get('@catOrg').click();
      cy.get('@catRepos').should('have.length', 3).and('be.visible');

      // hide
      cy.get('@catOrg').click();
      cy.get('@catRepos').should('not.be.visible');
    });

    it('shows the enabled label when a repo is enabled', () => {
      cy.get('[data-test=source-org-cat]').click();
      cy.get('[data-test=enable-cat-purr]').click();

      cy.get('[data-test=enabled-cat-purr]')
        .first()
        .should('be.visible')
        .and('contain', 'Enabled');
    });

    it('shows the failed button and alert when the enable is unsuccessful', () => {
      cy.route({
        method: 'POST',
        url: '*api/v1/repos*',
        status: 500,
        response: `{"error":"unable to create webhook for : something went wrong"}`,
      });

      cy.get('[data-test=source-org-cat]').click();
      cy.get('[data-test=enable-cat-purr').click();

      cy.get('[data-test=enabled-cat-purr').should('not.be.visible');

      cy.get('[data-test=failed-cat-purr')
        .should('be.visible')
        .and('contain', 'Failed');

      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });

    it('disables the refresh list button while loading', () => {
      cy.get('[data-test=refresh-source-repos]')
        .should('be.visible')
        .should('be.disabled');
      cy.wait('@sourceRepos');
    });

    it('shows the loading labels when all repos for org are enabled', () => {
      cy.get('[data-test=source-org-github]').click();
      cy.get('[data-test=enable-org-github]').click({ force: true });

      cy.get('[data-test=source-repo-octocat]')
        .should('be.visible')
        .and('contain', 'Enabling');

      cy.get('[data-test=source-repo-octocat-1]')
        .should('be.visible')
        .and('contain', 'Enabling');

      cy.get('[data-test=source-repo-octocat-2]')
        .should('be.visible')
        .and('contain', 'Enabling');
    });
  });

  context('logged in - api error', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/user/source/repos*',
        status: 500,
        response: 'server error',
      }).as('error');
      cy.login('/account/source-repos');
    });

    it('show a message and an alert when there is a server error', () => {
      cy.wait('@error');
      cy.get('.content-wrap').contains(
        'There was an error fetching your available repositories, please refresh or try again later!',
      );
    });
  });

  context('logged in - unexpected response', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/user/source/repos*',
        'fixture:source_repositories_bad.json',
      ).as('badSourceRepos');
      cy.login('/account/source-repos');
    });

    it('show a message and an alert when the response is malformed', () => {
      cy.get('.content-wrap').contains(
        'There was an error fetching your available repositories, please refresh or try again later!',
      );

      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('Expecting an OBJECT with a field named `org`');
    });
  });
});
