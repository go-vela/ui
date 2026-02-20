/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Reports', () => {
  context('server returning test attachments', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubTestAttachments();
      cy.login('/github/octocat/1/reports');
    });

    it('should show reports page', () => {
      cy.get('[data-test=reports-container]').should('be.visible');
    });

    it('should show attachments button', () => {
      cy.get('.reports-button').contains('attachments').should('be.visible');
    });

    it('should show test results button', () => {
      cy.get('.reports-button').contains('test results').should('be.visible');
    });

    it('should show attachment links', () => {
      cy.get('.attachment-link').should('have.length', 3);
      cy.get('.attachment-link').first().should('contain', 'test-results.xml');
      cy.get('.attachment-link').eq(1).should('contain', 'coverage.html');
      cy.get('.attachment-link').eq(2).should('contain', 'junit-report.json');
    });

    it('attachment links should have correct href attributes', () => {
      cy.get('.attachment-link').first().should('have.attr', 'href', 'https://example.com/signed-url/test-results.xml');
      cy.get('.attachment-link').eq(1).should('have.attr', 'href', 'https://example.com/signed-url/coverage.html');
      cy.get('.attachment-link').eq(2).should('have.attr', 'href', 'https://example.com/signed-url/junit-report.json');
    });

    it('attachment links should have download attribute', () => {
      cy.get('.attachment-link').first().should('have.attr', 'download', 'test-results.xml');
      cy.get('.attachment-link').eq(1).should('have.attr', 'download', 'coverage.html');
      cy.get('.attachment-link').eq(2).should('have.attr', 'download', 'junit-report.json');
    });
  });

  context('server returning test attachments error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubTestAttachmentsError();
      cy.login('/github/octocat/1/reports');
    });

    it('should show error message', () => {
      cy.get('.report-output').should('contain', 'Failed to load attachments');
      cy.get('.report-output').should('contain', 'HTTP 500');
    });
  });

  context('server returning no attachments', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds/*/reports*',
        status: 200,
        response: [],
      });
      cy.login('/github/octocat/1/reports');
    });

    it('should show empty state', () => {
      cy.get('.attachments-list').should('be.empty');
    });
  });
});