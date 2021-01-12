/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Crumbs', () => {
  context('logged in', () => {
    beforeEach(() => {
      cy.login();
    });

    it('visit / should show overview', () => {
      cy.get('[data-test=crumb-overview]').should('exist').contains('Overview');
    });

    it('visit /account/source-repos should have Overview with link', () => {
      cy.visit('/account/source-repos');
      cy.get('[data-test=crumb-overview]')
        .should('exist')
        .contains('a', 'Overview');
    });

    it('visit /account/source-repos should have Account without link', () => {
      cy.visit('/account/source-repos');
      cy.get('[data-test=crumb-account]').should('exist').contains('Account');
    });

    it('visit /account/source-repos should have Source Repositories without link', () => {
      cy.visit('/account/source-repos');
      cy.get('[data-test=crumb-source-repositories]')
        .should('exist')
        .contains('Source Repositories');
    });

    it('visit /account/source-repos Overview crumb should redirect to Overview page', () => {
      cy.visit('/account/source-repos');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit /github/octocat should show org and repo crumbs', () => {
      cy.visit('/github/octocat');
      cy.get('[data-test=crumb-github]').should('exist');
      cy.get('[data-test=crumb-octocat]').should('exist');
    });

    it('visit /github/octocat Overview crumb should redirect to Overview page', () => {
      cy.visit('/github/octocat');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit /github/octocat/build Overview crumb should redirect to Overview page', () => {
      cy.visit('/github/octocat/1');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit bad build /github/octocat/build should not show not-found crumb', () => {
      cy.visit('/github/octocat/1');
      cy.get('[data-test=crumb-not-found]').should('not.be.visible');
    });
  });
  context('visit org secrets', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/github/**',
        'fixture:secrets_org_5.json',
      ).as('secret');
      cy.login('/-/secrets/native/org/github');
    });
    it('should show appropriate secrets crumbs', () => {
      cy.get('[data-test=crumb-github]').should('exist');
      cy.get('[data-test=crumb-org-secrets]').should('exist');
    });
  });
  context('visit repo secret', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/github/**',
        'fixture:secret_repo.json',
      ).as('secret');
      cy.login('/-/secrets/native/repo/github/octocat/password');
    });
    it('should show appropriate secrets crumbs', () => {
      cy.get('[data-test=crumb-github]').should('exist');
      cy.get('[data-test=crumb-octocat]').should('exist');
      cy.get('[data-test=crumb-password]').should('exist');
    });
    it('Secrets crumb should redirect to repo secrets', () => {
      cy.get('[data-test=crumb-octocat]').click();
      cy.location('pathname').should(
        'eq',
        '/-/secrets/native/repo/github/octocat',
      );
    });
  });
  context(
    'visit shared secret with special characters in team and name',
    () => {
      beforeEach(() => {
        cy.server();
        cy.route(
          'GET',
          '*api/v1/secrets/native/shared/github/**',
          'fixture:secret_shared.json',
        ).as('secret');
        cy.login(
          '/-/secrets/native/shared/github/some%2Fteam/docker%2Fpassword',
        );
      });
      it('should show appropriate secrets crumbs', () => {
        cy.get('[data-test=crumb-github]').should('exist');
        cy.get('[data-test="crumb-some/team"]').should('exist');
        cy.get('[data-test=crumb-shared-secrets]').should('exist');
        cy.get('[data-test="crumb-docker/password"]').should('exist');
      });
    },
  );
  context('visit add repo secret', () => {
    beforeEach(() => {
      cy.server();
      cy.login('/-/secrets/native/repo/github/octocat/add');
    });
    it('should show appropriate secrets crumbs', () => {
      cy.get('[data-test=crumb-github]').should('exist');
      cy.get('[data-test=crumb-octocat]').should('exist');
    });
  });
  context('visit pipeline', () => {
    beforeEach(() => {
      cy.server();
      cy.login('/github/octocat/pipeline?ref=somebranch');
    });
    it('should show appropriate pipeline crumbs', () => {
      cy.get('[data-test=crumb-github]').should('exist');
      cy.get('[data-test=crumb-octocat]').should('exist');
      cy.get('[data-test=crumb-somebranch]').should('exist');
    });
  });
});
