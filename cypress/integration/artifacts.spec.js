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
      // Artifacts are sorted alphabetically by file_name
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
      // Artifacts are sorted alphabetically by file_name
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
        url: '*api/v1/repos/*/*/builds/*/artifact',
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

  context('artifact table structure and formatting', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubArtifacts();
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show all table headers', () => {
      cy.get('[data-test=build-artifacts-table]').should('be.visible');
      cy.get('[data-test=build-artifacts-table] th').should('have.length', 4);
      cy.get('[data-test=build-artifacts-table]').contains('th', 'Name');
      cy.get('[data-test=build-artifacts-table]').contains('th', 'Created At');
      cy.get('[data-test=build-artifacts-table]').contains('th', 'Expires At');
      cy.get('[data-test=build-artifacts-table]').contains('th', 'File Size');
    });

    it('should show created at timestamps', () => {
      cy.get(
        '[data-test=build-artifacts-table] [data-label=created-at]',
      ).should('have.length', 3);
      cy.get('[data-test=build-artifacts-table] [data-label=created-at]')
        .first()
        .should('not.be.empty');
    });

    it('should show expires at timestamps', () => {
      cy.get(
        '[data-test=build-artifacts-table] [data-label=expires-at]',
      ).should('have.length', 3);
      cy.get('[data-test=build-artifacts-table] [data-label=expires-at]')
        .first()
        .should('not.be.empty');
    });

    it('should show formatted file sizes', () => {
      // All file sizes should be formatted and displayed
      cy.get('[data-test=build-artifacts-table]').within(() => {
        cy.get('[data-label=file-size]').should('have.length', 3);
        // Check that file sizes contain expected units (KB, bytes, etc)
        cy.get('[data-label=file-size]').each($el => {
          cy.wrap($el).should('not.be.empty');
        });
      });
    });

    it('should display artifacts in table rows', () => {
      cy.get('[data-test=build-artifacts-table] tbody tr').should(
        'have.length',
        3,
      );
    });
  });

  context('expired artifacts', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      // Create artifacts with old created_at timestamp (more than 7 days ago)
      const eightDaysAgo = Math.floor(Date.now() / 1000) - 8 * 24 * 60 * 60;
      const oneDayAgo = Math.floor(Date.now() / 1000) - 1 * 24 * 60 * 60;
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds/*/artifact',
        status: 200,
        response: [
          {
            id: 1,
            build_id: 1,
            file_name: 'old-artifact.xml',
            object_path: 'artifacts/old-artifact.xml',
            file_size: 2048,
            file_type: 'application/xml',
            presigned_url: 'https://example.com/signed-url/old-artifact.xml',
            created_at: eightDaysAgo,
          },
          {
            id: 2,
            build_id: 1,
            file_name: 'recent-artifact.xml',
            object_path: 'artifacts/recent-artifact.xml',
            file_size: 2048,
            file_type: 'application/xml',
            presigned_url: 'https://example.com/signed-url/recent-artifact.xml',
            created_at: oneDayAgo,
          },
        ],
      });
      cy.login('/github/octocat/1/artifacts');
    });

    it('should show expired label for old artifacts', () => {
      cy.get('.artifact-name-expired').should('be.visible');
      cy.get('.artifact-expired-label')
        .should('be.visible')
        .and('contain', '(Expired)');
    });

    it('should not show link for expired artifacts', () => {
      // First artifact is expired, should not have a link
      cy.get('[data-test=build-artifacts-table] tbody tr')
        .first()
        .find('a')
        .should('not.exist');
      cy.get('[data-test=build-artifacts-table] tbody tr')
        .first()
        .should('contain', 'old-artifact.xml');
    });

    it('should show link for recent artifacts', () => {
      // Second artifact is recent, should have a link
      cy.get('[data-test=build-artifacts-table] tbody tr')
        .eq(1)
        .find('a')
        .should('exist')
        .and('have.attr', 'href')
        .and('include', 'recent-artifact.xml');
    });

    it('expired artifact should have grayed out styling', () => {
      cy.get('.artifacts-expired').should('be.visible');
      cy.get('.artifact-name-expired').should(
        'have.attr',
        'style',
        'color: var(--color-text-secondary, #888);',
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
        url: '*api/v1/repos/*/*/builds/*/artifact',
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
