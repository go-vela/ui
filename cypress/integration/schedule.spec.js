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
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
        });
        it('default entry value should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch placeholder should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
        });
        it('submit button should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=submit]').should('exist');
=======
          cy.get('[data-test=button-submit]').should('exist');
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
        });
        it('default entry value should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch placeholder should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
        });
        it('submit button should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=submit]').should('exist');
=======
          cy.get('[data-test=button-submit]').should('exist');
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default entry value should show and be disabled', () => {
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default branch placeholder should show and be disabled', () => {
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('submit button should show and be disabled', () => {
<<<<<<< HEAD
          cy.get('[data-test=submit]')
=======
          cy.get('[data-test=button-submit]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .should('have.value', 'Daily');
        });
        it('default entry value should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch value should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .should('have.value', 'main');
        });
        it('submit button should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=submit]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=delete]').should('exist');
=======
          cy.get('[data-test=button-submit]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=button-delete]').should('exist');
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .should('have.value', 'Daily');
        });
        it('default entry value should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
        });
        it('default branch value should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .should('have.value', 'main');
        });
        it('submit button should show', () => {
<<<<<<< HEAD
          cy.get('[data-test=submit]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=delete]').should('exist');
=======
          cy.get('[data-test=button-submit]').should('exist');
        });
        it('delete button should show', () => {
          cy.get('[data-test=button-delete]').should('exist');
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Schedule Name');
            });
<<<<<<< HEAD
          cy.get('[data-test=name]')
=======
          cy.get('[data-test=input-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default entry value should show and be disabled', () => {
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('0 0 * * *');
            });
<<<<<<< HEAD
          cy.get('[data-test=entry]')
=======
          cy.get('[data-test=textarea-entry]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('default branch placeholder should show and be disabled', () => {
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'placeholder')
            .then(placeholder => {
              expect(placeholder).to.include('Branch Name');
            });
<<<<<<< HEAD
          cy.get('[data-test=branch-name]')
=======
          cy.get('[data-test=input-branch-name]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
            .should('exist')
            .and('have.attr', 'disabled');
        });
        it('submit button should show and be disabled', () => {
<<<<<<< HEAD
          cy.get('[data-test=submit]')
=======
          cy.get('[data-test=button-submit]')
>>>>>>> de6be28dc258d28f72be0c65c37a940612fcf3ef
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
