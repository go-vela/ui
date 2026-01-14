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
      cy.get('[data-test=artifacts-container]').should('be.visible');
    });

    it('should show artifact links', () => {
      cy.get('.artifact-link').should('have.length', 3);
      cy.get('.artifact-link').first().should('contain', 'test-results.xml');
      cy.get('.artifact-link').eq(1).should('contain', 'coverage.html');
      cy.get('.artifact-link').eq(2).should('contain', 'junit-report.json');
    });

    it('artifact links should have correct href attributes', () => {
      cy.get('.artifact-link')
        .first()
        .should(
          'have.attr',
          'href',
          'https://example.com/signed-url/test-results.xml',
        );
      cy.get('.artifact-link')
        .eq(1)
        .should(
          'have.attr',
          'href',
          'https://example.com/signed-url/coverage.html',
        );
      cy.get('.artifact-link')
        .eq(2)
        .should(
          'have.attr',
          'href',
          'https://example.com/signed-url/junit-report.json',
        );
    });

    it('artifact links should have download attribute', () => {
      cy.get('.artifact-link')
        .first()
        .should('have.attr', 'download', 'test-results.xml');
      cy.get('.artifact-link')
        .eq(1)
        .should('have.attr', 'download', 'coverage.html');
      cy.get('.artifact-link')
        .eq(2)
        .should('have.attr', 'download', 'junit-report.json');
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
        url: '*api/v1/repos/*/*/builds/*/artifacts',
        status: 200,
        response: [],
      });
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show empty state', () => {
      cy.get('.artifacts-list').should('be.empty');
    });
  });
});
