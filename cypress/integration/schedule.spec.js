/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Add Schedule', () => {
  context('server returning schedule', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/schedules/github/octocat/Daily',
        'fixture:schedule.json',
      );
      cy.login('/github/octocat/add-schedule');
    });
    context(
      'allowlist contains github/octocat',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: 'github/octocat',
        },
      },
      () => {
        it('default name placeholder should show', () => {
          cy.get('[data-test=schedule-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
        });
        it('default entry value should show', () => {
          cy.get('[data-test=schedule-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch placeholder should show', () => {
          cy.get('[data-test=schedule-branch-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
        });
        it('add button should show', () => {
          cy.get('[data-test=schedule-add-button]').should('exist');
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
        it('default name placeholder should show', () => {
          cy.get('[data-test=schedule-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
        });
        it('default entry value should show', () => {
          cy.get('[data-test=schedule-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch placeholder should show', () => {
          cy.get('[data-test=schedule-branch-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
        });
        it('add button should show', () => {
          cy.get('[data-test=schedule-add-button]').should('exist');
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
        it('default name value should not show', () => {
          cy.get('[data-test=schedule-name]').should('not.exist');
        });
        it('default entry value should not show', () => {
          cy.get('[data-test=schedule-entry]').should('not.exist');
        });
        it('default branch value should not show', () => {
          cy.get('[data-test=schedule-branch-name]').should('not.exist');
        });
        it('add button should not show', () => {
          cy.get('[data-test=schedule-add-button]').should('not.exist');
        });
        it('should show not allowed warning', () => {
          cy.get('[data-test=repo-schedule-not-allowed]').should('exist');
        });
      },
    );
  });
});

context('View/Edit Schedule', () => {
  context('server returning schedule', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/schedules/github/octocat/Daily',
        'fixture:schedule.json',
      );
      cy.login('/github/octocat/schedules/Daily');
    });
    context(
      'allowlist contains github/octocat',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: 'github/octocat',
        },
      },
      () => {
        it('default name value should show', () => {
          cy.get('[data-test=schedule-name]')
            .should('exist')
            .should('have.value', 'Daily');
        });
        it('default entry value should show', () => {
          cy.get('[data-test=schedule-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch value should show', () => {
          cy.get('[data-test=schedule-branch-name]')
            .should('exist')
            .should('have.value', 'master');
        });
        it('update button should show', () => {
          cy.get('[data-test=schedule-update-button]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=schedule-delete-button]').should('exist');
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
        it('default name value should show', () => {
          cy.get('[data-test=schedule-name]')
            .should('exist')
            .should('have.value', 'Daily');
        });
        it('default entry value should show', () => {
          cy.get('[data-test=schedule-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch value should show', () => {
          cy.get('[data-test=schedule-branch-name]')
            .should('exist')
            .should('have.value', 'master');
        });
        it('update button should show', () => {
          cy.get('[data-test=schedule-update-button]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=schedule-delete-button]').should('exist');
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
        it('default name value should not show', () => {
          cy.get('[data-test=schedule-name]').should('not.exist');
        });
        it('default entry value should not show', () => {
          cy.get('[data-test=schedule-entry]').should('not.exist');
        });
        it('default branch value should not show', () => {
          cy.get('[data-test=schedule-branch-name]').should('not.exist');
        });
        it('update button should not show', () => {
          cy.get('[data-test=schedule-update-button]').should('not.exist');
        });
        it('delete button should not show', () => {
          cy.get('[data-test=schedule-delete-button]').should('not.exist');
        });
        it('should show not allowed warning', () => {
          cy.get('[data-test=repo-schedule-not-allowed]').should('exist');
        });
      },
    );
  });
});
