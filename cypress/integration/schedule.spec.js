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
      cy.login('/github/octocat/schedules/add');
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
          cy.get('[data-test=input-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
        });
        it('default entry value should show', () => {
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch placeholder should show', () => {
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
        });
        it('submit button should show', () => {
          cy.get('[data-test=button-submit]').should('exist');
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
        it('default entry value should show', () => {
          cy.get('[data-test=input-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
        });
        it('default entry value should show', () => {
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch placeholder should show', () => {
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
        });
        it('submit button should show', () => {
          cy.get('[data-test=button-submit]').should('exist');
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
        it('default entry value should show and be disabled', () => {
          cy.get('[data-test=input-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
          cy.get('[data-test=input-name]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default entry value should show and be disabled', () => {
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default branch placeholder should show and be disabled', () => {
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('submit button should show and be disabled', () => {
          cy.get('[data-test=button-submit]')
            .should('exist')
            .and('have.attr', 'disabled');
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
          cy.get('[data-test=input-name]')
            .should('exist')
            .should('have.value', 'Daily');
        });
        it('default entry value should show', () => {
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch value should show', () => {
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .should('have.value', 'main');
        });
        it('submit button should show', () => {
          cy.get('[data-test=button-submit]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=button-delete]').should('exist');
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
          cy.get('[data-test=input-name]')
            .should('exist')
            .should('have.value', 'Daily');
        });
        it('default entry value should show', () => {
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch value should show', () => {
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .should('have.value', 'main');
        });
        it('submit button should show', () => {
          cy.get('[data-test=button-submit]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=button-delete]').should('exist');
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
        it('default entry value should show and be disabled', () => {
          cy.get('[data-test=input-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
          cy.get('[data-test=input-name]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default entry value should show and be disabled', () => {
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
          cy.get('[data-test=textarea-entry]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default branch placeholder should show and be disabled', () => {
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
          cy.get('[data-test=input-branch-name]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('submit button should show and be disabled', () => {
          cy.get('[data-test=button-submit]')
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('should show not allowed warning', () => {
          cy.get('[data-test=repo-schedule-not-allowed]').should('exist');
        });
      },
    );
  });
});
