/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Schedules', () => {
  context('server returning schedules', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/schedules/github/octocat',
        'fixture:schedules.json',
      );
      cy.login('/github/octocat/schedules');
    });
    context(
      'allowlist contains github/octocat',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: 'github/octocat',
        },
      },
      () => {
        it('Schedules tab should exist', () => {
          cy.get('[data-test=jump-Schedules]')
            .should('exist')
            .contains('Schedules');
        });
        it('Add Schedule button should exist', () => {
          cy.get('[data-test=add-repo-schedule]')
            .should('exist')
            .contains('Add');
        });
        it('schedules table should show 2 rows', () => {
          cy.get('[data-test=schedules-row]').should('have.length', 2);
        });
      },
    );
    context(
      'allowlist contains *',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: '*',
        },
      },
      () => {
        it('Schedules tab should exist', () => {
          cy.get('[data-test=jump-Schedules]')
            .should('exist')
            .contains('Schedules');
        });
        it('Add Schedule button should exist', () => {
          cy.get('[data-test=add-repo-schedule]')
            .should('exist')
            .contains('Add');
        });
        it('schedules table should show 2 rows', () => {
          cy.get('[data-test=schedules-row]').should('have.length', 2);
        });
      },
    );
    context(
      'allowlist is empty',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: ' ', // use a space character to override the default flag value '*'
        },
      },
      () => {
        it('Schedules tab should not exist', () => {
          cy.get('[data-test=jump-Schedules]').should('not.exist');
        });
        it('Add Schedule button should not exist', () => {
          cy.get('[data-test=add-repo-schedule]').should('not.exist');
        });
        it('should show not allowed warning', () => {
          cy.get('[data-test=repo-schedule-not-allowed]').should('exist');
        });
        it('schedules table should not show rows', () => {
          cy.get('[data-test=schedules-row]').should('have.length', 0);
        });
      },
    );
  });
});
