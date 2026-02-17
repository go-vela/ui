/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Artifacts', () => {
  context('server returning artifacts', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubArtifacts();
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show artifacts page', () => {
      cy.get('[data-test=build-artifacts-table]').should('be.visible');
    });

    it('should show artifact links', () => {
      cy.get('[data-test=build-artifacts-table] tbody tr').should(
        'have.length',
        3,
      );
      // Artifacts are sorted alphabetically by file name
      cy.get('[data-test=build-artifacts-table] tbody tr')
        .first()
        .should('contain', 'coverage.html');
      cy.get('[data-test=build-artifacts-table] tbody tr')
        .eq(1)
        .should('contain', 'junit-report.json');
      cy.get('[data-test=build-artifacts-table] tbody tr')
        .eq(2)
        .should('contain', 'test-results.xml');
    });

    it('artifact links should have correct href attributes', () => {
      // Artifacts are sorted alphabetically by file name
      // Links are inside td > span structure
      cy.get('[data-test=build-artifacts-table] a')
        .first()
        .should(
          'have.attr',
          'href',
          'https://example.com/signed-url/coverage.html',
        );
      cy.get('[data-test=build-artifacts-table] a')
        .eq(1)
        .should(
          'have.attr',
          'href',
          'https://example.com/signed-url/junit-report.json',
        );
      cy.get('[data-test=build-artifacts-table] a')
        .eq(2)
        .should(
          'have.attr',
          'href',
          'https://example.com/signed-url/test-results.xml',
        );
    });
  });

  context('server returning artifacts error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubArtifactsError();
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show error message', () => {
      cy.get('.artifact-output').should('contain', 'Failed to load artifacts');
      cy.get('.artifact-output').should('contain', 'HTTP 500');
    });
  });

  context('server returning no artifacts', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds/*/storage/*/names',
        status: 200,
        response: [],
      });
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show empty state message', () => {
      cy.get('[data-test=build-artifacts-table]').should('be.visible');
      cy.get('[data-test=build-artifacts-table]').should(
        'contain',
        'No artifacts found for this build',
      );
    });
  });

  context('artifact table structure', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubArtifacts();
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show all table headers', () => {
      cy.get('[data-test=build-artifacts-table]').should('be.visible');
      cy.get('[data-test=build-artifacts-table] th').should('have.length', 1);
      cy.get('[data-test=build-artifacts-table]').contains('th', 'Name');
    });

    it('should display artifacts in table rows', () => {
      cy.get('[data-test=build-artifacts-table] tbody tr').should(
        'have.length',
        3,
      );
    });
  });

  context('loading state', () => {
    it('should show loading message while artifacts are loading', () => {
      cy.server();
      cy.stubBuild();
      // Delay the artifacts response
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds/*/storage/*/names',
        status: 200,
        response: [],
        delay: 1000,
      });
      cy.login('/github/octocat/1/artifacts');
      cy.get('.artifact-output')
        .should('be.visible')
        .and('contain', 'Loading artifacts...');
    });
  });
});
