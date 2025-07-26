/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Schedules', () => {
  context('server returning schedules', () => {
    beforeEach(() => {
      cy.intercept('GET', '*api/v1/schedules/github/octocat', {
        fixture: 'schedules.json',
      });
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
    context(
      'schedule',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: '*',
        },
      },
      () => {
        beforeEach(() => {
          cy.get('[data-test=schedules-row]').first().as('dailySchedule');
        });
        it('should show name', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('.name').contains('Daily');
          });
        });
        it('should show entry', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=cron-expression]').contains('0 0 * * *');
          });
        });
        it('should show enabled', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=enabled]').contains('yes');
          });
        });
        it('should show branch', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=branch]').contains('main');
          });
        });
        it('should show last scheduled at', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=scheduled-at]').should('exist');
          });
        });
        it('should show next run', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=next-run]').should('exist');
          });
        });
        it('should show updated by', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=updated-by]').contains('CookieCat');
          });
        });
        it('should show updated at', () => {
          cy.get('@dailySchedule').within(() => {
            cy.get('[data-label=updated-at]').should('exist');
          });
        });
        context('failure', () => {
          beforeEach(() => {
            cy.get('[data-test=schedules-error]').as('error');
          });
          it('should show error', () => {
            cy.get('@error').contains(
              'unable to trigger build for schedule Hourly: unable to schedule build: unable to compile pipeline configuration for github/octocat: 1 error occurred: * no "version:" YAML property provided',
            );
          });
        });
      },
    );
  });
});
