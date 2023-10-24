/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Repo', () => {
  context('logged in and server returning 5 builds', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/repos/*/*/builds*',
        response: 'fixture:builds_5.json',
      });
      cy.stubBuild();
      cy.hookPages();
      cy.login('/github/octocat');

      cy.get('[data-test=builds]').as('builds');
    });

    it('repo jump tabs should show', () => {
      cy.get('[data-test=jump-bar-repo]').should('be.visible');
    });

    context('click audit in nav tabs', () => {
      beforeEach(() => {
        cy.get('[data-test=jump-Audit]').click();
      });

      it('loads the first page of hooks', () => {
        cy.location('pathname').should('eq', '/github/octocat/hooks');
      });

      context('click next page of hooks', () => {
        beforeEach(() => {
          cy.get('[data-test=pager-next]')
            .should('have.length', 2)
            .first()
            .click();
        });

        it('loads the second page of hooks', () => {
          cy.location('pathname').should('eq', '/github/octocat/hooks');
          cy.location().should(loc => {
            expect(loc.search).to.eq('?page=2');
          });
        });

        context('click settings in nav tabs', () => {
          beforeEach(() => {
            cy.get('[data-test=jump-Settings]').click();
          });

          it('loads repo settings', () => {
            cy.location('pathname').should('eq', '/github/octocat/settings');
          });
        });
        context('click schedules in nav tabs', () => {
          beforeEach(() => {
            cy.get('[data-test=jump-Schedules]').click();
          });

          it('loads repo schedules', () => {
            cy.location('pathname').should('eq', '/github/octocat/schedules');
          });
        });
        context('click audit in nav tabs, again', () => {
          beforeEach(() => {
            cy.get('[data-test=jump-Audit]').click();
          });

          it('retains pagination, loads the second page of hooks', () => {
            cy.location('pathname').should('eq', '/github/octocat/hooks');
            cy.location().should(loc => {
              expect(loc.search).to.eq('?page=2');
            });
          });
        });

        context('click secrets in nav tabs', () => {
          beforeEach(() => {
            cy.route('GET', '*api/v1/secrets/native/repo/github/octocat*', []);
            cy.route('GET', '*api/v1/secrets/native/org/github/**', []);
            cy.get('[data-test=jump-Secrets]').click();
          });

          it('loads repo secrets page', () => {
            cy.location('pathname').should(
              'eq',
              '/-/secrets/native/repo/github/octocat',
            );
            cy.get('[data-test=repo-secrets-table]').should('be.visible');
          });

          it('also loads org secrets', () => {
            cy.get('[data-test=org-secrets-table]').should('be.visible');
          });

          it('link to manage org secrets shows', () => {
            cy.get('[data-test=manage-org-secrets]').should('be.visible');
          });

          it('clink link to manage org secrets should redirect to org secrets', () => {
            cy.get('[data-test=manage-org-secrets]').click();
            cy.location('pathname').should(
              'eq',
              '/-/secrets/native/org/github',
            );
          });
        });
      });
    });
  });
});
