/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Source Repositories', () => {
  context('logged in', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user' },
        {
          fixture: 'favorites_overview.json',
        },
      );
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user/source/repos' },
        {
          fixture: 'source_repositories.json',
        },
      ).as('sourceRepos');
      cy.intercept(
        { method: 'POST', url: '*api/v1/repos*' },
        {
          fixture: 'enable_repo_response.json',
        },
      );
      cy.intercept(
        { method: 'PUT', url: '*api/v1/repos*' },
        {
          fixture: 'enable_repo_response.json',
        },
      );
      cy.login('/account/source-repos');
    });

    it('should show the orgs', () => {
      cy.get('[data-test=source-repos] .details').should('have.length', 3);
    });

    it('toggles visibility of repos in an org', () => {
      cy.skipInCI('Visibility toggle timing issue in CI');
      
      cy.get('[data-test=source-org-cat]').as('catOrg');
      cy.get('[data-test=source-org-cat] ~ [data-test^=source-repo]').as(
        'catRepos',
      );

      // show
      cy.get('@catOrg').click();
      cy.wait(500); // Wait for animation/transition
      cy.get('@catRepos').should('have.length', 3).and('be.visible');

      // hide
      cy.get('@catOrg').click();
      cy.wait(500); // Wait for animation/transition
      cy.get('@catRepos').should('not.be.visible');
    });

    it('shows the enabled label when a repo is enabled', () => {
      cy.get('[data-test=source-org-github]').click();
      cy.get('[data-test=enable-github-octocat]').click();

      cy.get('[data-test=enabled-github-octocat]')
        .first()
        .should('be.visible')
        .and('contain', 'Enabled');
    });

    it('shows the failed button and alert when the enable is unsuccessful', () => {
      cy.intercept(
        { method: 'POST', url: '*api/v1/repos*' },
        {
          statusCode: 500,
          body: `{"error":"unable to create webhook for : something went wrong"}`,
        },
      ).as('enableRepoError');

      cy.get('[data-test=source-org-cat]').click();
      cy.get('[data-test=enable-cat-purr').click();
      cy.wait('@enableRepoError');

      cy.get('[data-test=enabled-cat-purr').should('not.be.visible');

      cy.get('[data-test=failed-cat-purr')
        .should('be.visible')
        .and('contain', 'Fail');

      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });

    it('shows the loading labels when all repos for org are enabled', () => {
      cy.get('[data-test=source-org-github]').click();
      cy.get('[data-test=enable-org-github]').click({ force: true });

      cy.get('[data-test=source-repo-octocat-1]')
        .should('be.visible')
        .and('contain', 'Enabling');

      cy.get('[data-test=source-repo-octocat-2]')
        .should('be.visible')
        .and('contain', 'Enabling');

      cy.get('[data-test=source-repo-server]')
        .should('be.visible')
        .and('contain', 'Enabling');
    });
  });

  context('logged in - artificial 1s load delay', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '*api/v1/user*' },
        {
          fixture: 'favorites_overview.json',
        },
      );
      cy.intercept(
        { method: 'GET', url: '*api/v1/user/source/repos*' },
        {
          delay: 1000,
          body: {},
        },
      ).as('sourceRepos');
      cy.intercept(
        { method: 'POST', url: '*api/v1/repos*' },
        {
          fixture: 'enable_repo_response.json',
        },
      );
      cy.login('/account/source-repos');
    });

    it('disables the refresh list button while loading', () => {
      cy.get('[data-test=refresh-source-repos]')
        .should('be.visible')
        .should('be.disabled');
      cy.wait('@sourceRepos');
    });
  });

  context('logged in - api error', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '*api/v1/user*' },
        {
          fixture: 'favorites_overview.json',
        },
      );
      cy.intercept(
        { method: 'GET', url: '*api/v1/user/source/repos*' },
        {
          statusCode: 500,
          body: 'server error',
        },
      ).as('error');
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
      cy.intercept(
        { method: 'GET', url: '*api/v1/user*' },
        {
          fixture: 'favorites_overview.json',
        },
      );
      cy.intercept(
        { method: 'GET', url: '*api/v1/user/source/repos*' },
        {
          fixture: 'source_repositories_bad.json',
        },
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
