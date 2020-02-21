/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Builds', () => {
  context('server returning builds error', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds*',
        status: 500,
        response: 'server error',
      });
      cy.stubBuild();
      cy.login('/someorg/somerepo');
    });

    it('builds should not show', () => {
      cy.get('[data-test=builds]').should('not.be.visible');
    });
    it('error should show', () => {
      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('Error');
    });
    it('error banner should show', () => {
      cy.get('[data-test=builds-error]')
        .should('exist')
        .contains('try again later');
    });
  });

  context('logged in and server returning 5 builds', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds*',
        response: 'fixture:builds_5.json',
      });
      cy.stubBuild();
      cy.login('/someorg/somerepo');

      cy.get('[data-test=builds]').as('builds');
    });

    it('builds should show', () => {
      cy.get('@builds').should('be.visible');
    });

    it('pagination controls should not show', () => {
      cy.get('[data-test=pager-previous]').should('not.be.visible');
    });
  });

  context('logged in and server returning 20 builds and running build', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuilds();
      cy.stubBuild();
      cy.login('/someorg/somerepo');

      cy.get('[data-test=builds]').as('builds');
      cy.get('@builds')
        .children()
        .first()
        .as('firstBuild');
      cy.get('@builds')
        .children()
        .last()
        .as('lastBuild');
    });

    it('builds should show', () => {
      cy.get('@builds').should('be.visible');
    });

    it('builds should show build number', () => {
      cy.get('@firstBuild')
        .should('exist')
        .should('contain', '#1');
      cy.get('@lastBuild')
        .should('exist')
        .should('contain', '#10');
    });

    it('build page 2 should show the next set of results', () => {
      cy.visit('/someorg/somerepo?page=2');
      cy.get('@firstBuild')
        .should('exist')
        .should('contain', '#11');
      cy.get('@lastBuild')
        .should('exist')
        .should('contain', '#20');
      cy.get('[data-test="crumb-somerepo-(page-2)"]')
        .should('exist')
        .should('contain', 'page 2');

      cy.get('[data-test=pager-next]').should('be.disabled');
    });

    it("loads the first page when hitting the 'previous' button", () => {
      cy.visit('/someorg/somerepo?page=2');
      cy.get('[data-test=pager-previous]')
        .should('have.length', 2)
        .first()
        .click();
      cy.location('pathname').should('eq', '/someorg/somerepo');
    });

    it('builds should show commit hash', () => {
      cy.get('@firstBuild').should('contain', '9b1d8bd');
      cy.get('@lastBuild').should('contain', '7bd468e');
    });

    it('builds should show branch', () => {
      cy.get('@firstBuild')
        .should('be.visible')
        .should('contain', 'infra');
      cy.get('@lastBuild')
        .should('be.visible')
        .should('contain', 'terra');
    });

    it('build should having running style', () => {
      cy.get('@firstBuild')
        .get('[data-test=build-status]')
        .should('be.visible')
        .should('have.class', '-running');
    });

    it('clicking build number should redirect to build page', () => {
      cy.get('@firstBuild')
        .get('[data-test=build-number]')
        .first()
        .click();
      cy.location('pathname').should('eq', '/someorg/somerepo/1');
    });
  });

  context('logged in and server returning builds error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuildsErrors();
      cy.login('/someorg/somerepo');
    });

    it('error alert should show', () => {
      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('Error');
    });
  });

  context('logged out and server returning 10 builds', () => {
    beforeEach(() => {
      cy.clearSession();
      cy.server();
      cy.stubBuilds();
      cy.visit('/someorg/somerepo');
    });

    it('error alert should not show', () => {
      cy.get('[data-test=alerts]').should('be.not.visible');
    });

    it('builds should show login page', () => {
      cy.get('body').should('contain', 'Authorize Via');
    });
  });

  context('build filters', () => {
    beforeEach(() => {
      cy.stubBuildsFilter();
      cy.login('/someorg/somerepo');
      cy.get('[data-test=build-filter]').as('buildsFilter');
    });

    it('renders builds filter', () => {
      cy.get('@buildsFilter').should('be.visible');
    });

    it('shows all results by default', () => {
      cy.get('[data-test=build]')
        .should('be.visible')
        .should('have.length', 10);
    });

    it('should only show 7 push events', () => {
      cy.get('[data-test=build-filter-push]').click({ force: true });
      cy.get('[data-test=build]')
        .should('be.visible')
        .should('have.length', 7);
    });

    it('should only show two pull events', () => {
      cy.get('[data-test=build-filter-pull_request]').click({ force: true });
      cy.get('[data-test=build]')
        .should('be.visible')
        .should('have.length', 2);
    });

    it('should only show one pull event', () => {
      cy.get('[data-test=build-filter-tag]').click({ force: true });
      cy.get('[data-test=build]')
        .should('be.visible')
        .should('have.length', 1);
    });

    it('should show no results', () => {
      cy.get('[data-test=build-filter-deploy]').click({ force: true });
      cy.get('[data-test=build]').should('not.be.visible');
      cy.get('h1').should('contain', 'No builds for "deploy" event found.');
    });
  });
});
