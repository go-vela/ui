/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Crumbs', () => {
  context('logged in - sessionstorage item exists', () => {
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

    it('visit /someorg/somerepo should show org and repo crumbs', () => {
      cy.visit('/someorg/somerepo');
      cy.get('[data-test=crumb-someorg]').should('exist');
      cy.get('[data-test=crumb-somerepo]').should('exist');
    });

    it('visit /someorg/somerepo Overview crumb should redirect to Overview page', () => {
      cy.visit('/someorg/somerepo');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit /someorg/somerepo/build Overview crumb should redirect to Overview page', () => {
      cy.visit('/someorg/somerepo/1');
      cy.get('[data-test=crumb-overview]').click();
      cy.location('pathname').should('eq', '/');
    });

    it('visit bad build /someorg/somerepo/build should not show not-found crumb', () => {
      cy.visit('/someorg/somerepo/1');
      cy.get('[data-test=crumb-not-found]').should('not.be.visible');
    });
  });
  context('visit org secrets', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/someorg/**',
        'fixture:secrets_org_5.json',
      ).as('secret');
      cy.login('/-/secrets/native/org/someorg');
    });
    it('should show appropriate secrets crumbs', () => {
      cy.get('[data-test=crumb-someorg]').should('exist');
      cy.get('[data-test=crumb-org-secrets]').should('exist');
    });
  });
  context('visit repo secret', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/someorg/**',
        'fixture:secret_repo.json',
      ).as('secret');
      cy.login('/-/secrets/native/repo/someorg/somerepo/password');
    });
    it('should show appropriate secrets crumbs', () => {
      cy.get('[data-test=crumb-someorg]').should('exist');
      cy.get('[data-test=crumb-somerepo]').should('exist');
      cy.get('[data-test=crumb-repo-secrets]').should('exist');
      cy.get('[data-test=crumb-password]').should('exist');
    });
    it('repo crumb should redirect to repo builds', () => {
      cy.get('[data-test=crumb-somerepo]').click();
      cy.location('pathname').should('eq', '/someorg/somerepo');
    });
    it('Secrets crumb should redirect to repo secrets', () => {
      cy.get('[data-test=crumb-repo-secrets]').click();
      cy.location('pathname').should(
        'eq',
        '/-/secrets/native/repo/someorg/somerepo',
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
          '*api/v1/secrets/native/shared/someorg/**',
          'fixture:secret_shared.json',
        ).as('secret');
        cy.login(
          '/-/secrets/native/shared/someorg/some%2Fteam/docker%2Fpassword',
        );
      });
      it('should show appropriate secrets crumbs', () => {
        cy.get('[data-test=crumb-someorg]').should('exist');
        cy.get('[data-test="crumb-some/team"]').should('exist');
        cy.get('[data-test=crumb-shared-secrets]').should('exist');
        cy.get('[data-test="crumb-docker/password"]').should('exist');
      });
    },
  );
  context('visit add repo secret', () => {
    beforeEach(() => {
      cy.server();
      cy.login('/-/secrets/native/repo/someorg/somerepo/add');
    });
    it('should show appropriate secrets crumbs', () => {
      cy.get('[data-test=crumb-someorg]').should('exist');
      cy.get('[data-test=crumb-somerepo]').should('exist');
      cy.get('[data-test=crumb-repo-secrets]').should('exist');
      cy.get('[data-test=crumb-add]').should('exist');
    });
  });
});
