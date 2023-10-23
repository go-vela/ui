/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Secrets', () => {
  context('server returning repo secret', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/github/octocat/password*',
        'fixture:secret_repo.json',
      );
      cy.route(
        'GET',
        '*api/v1/secrets/native/org/github/*/password*',
        'fixture:secret_org.json',
      );
      cy.route(
        'DELETE',
        '*api/v1/secrets/native/repo/github/octocat/password*',
        'Secret repo/github/octocat/password deleted from native service',
      );
      cy.login('/-/secrets/native/repo/github/octocat/password');
    });

    it('Remove button should show', () => {
      cy.get('[data-test=secret-delete-button]')
        .should('exist')
        .contains('Remove');
    });

    context(
      'allowlist contains *',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: '*',
        },
      },
      () => {
        it('add button should show', () => {
          cy.get('[data-test=repo-checkbox-schedule]').should('exist');
        });
      },
    );

    context(
      'allowlist is empty',
      {
        env: {
          VELA_SCHEDULE_ALLOWLIST: ' ',
        },
      },
      () => {
        it('add button should not show', () => {
          cy.get('[data-test=repo-checkbox-schedule]').should('not.exist');
        });
      },
    );

    context('click Remove', () => {
      beforeEach(() => {
        cy.get('[data-test=secret-delete-button]').click();
      });

      it('Remove button should show when going to another secrets page', () => {
        cy.visit('/-/secrets/native/org/github/password');
        cy.get('[data-test=secret-delete-button]')
          .should('exist')
          .contains('Remove');
      });
      it('Cancel button should show', () => {
        cy.get('[data-test=secret-cancel-button]')
          .should('exist')
          .contains('Cancel');
      });
      it('Confirm button should show', () => {
        cy.get('[data-test=secret-delete-button]')
          .should('exist')
          .contains('Confirm');
      });
      context('click Cancel', () => {
        beforeEach(() => {
          cy.get('[data-test=secret-cancel-button]').click();
        });

        it('Cancel should revert Confirm to Remove', () => {
          cy.get('[data-test=secret-delete-button]')
            .should('exist')
            .contains('Remove');
        });
        it('Cancel should not show', () => {
          cy.get('[data-test=secret-cancel-button]').should('not.exist');
        });
      });
      context('click Confirm', () => {
        beforeEach(() => {
          cy.get('[data-test=secret-delete-button]').click();
        });

        it('Confirm should redirect to repo secrets page', () => {
          cy.location('pathname').should(
            'eq',
            '/-/secrets/native/repo/github/octocat',
          );
        });
        it('Alert should show', () => {
          cy.get('[data-test=alerts]')
            .should('exist')
            .contains('password')
            .contains('removed')
            .contains('repo');
        });
      });
    });
  });

  context('server returning remove error', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/repo/github/octocat/password*',
        'fixture:secret_repo.json',
      );
      cy.route({
        method: 'DELETE',
        url: '*api/v1/secrets/native/repo/github/octocat/password*',
        status: 500,
        response: { error: 'server error could not remove' },
      });
      cy.login('/-/secrets/native/repo/github/octocat/password');
      cy.get('[data-test=secret-delete-button]').click();
      cy.get('[data-test=secret-delete-button]').click();
    });

    it('error should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('could not remove');
    });
  });

  context('server returning secrets error', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/secrets/native/org/github/**',
        status: 500,
        response: 'server error',
      });
      cy.login('/-/secrets/native/org/github');
    });

    it('secrets table should not show', () => {
      cy.get('[data-test=secrets]').should('not.be.visible');
    });
    it('error should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
    it('error banner should show', () => {
      cy.get('[data-test=org-secrets-error]')
        .should('exist')
        .contains('there was an error');
    });
  });
  context('server returning 5 secrets', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/secrets/native/org/github/**',
        'fixture:secrets_org_5.json',
      ).as('secrets');
      cy.login('/-/secrets/native/org/github');
    });

    it('secrets table should show', () => {
      cy.get('[data-test=org-secrets-table]').should('be.visible');
    });

    it('secrets table should show 5 secrets', () => {
      cy.get('[data-test=secrets-row]').should('have.length', 5);
    });

    it('pagination controls should not show', () => {
      cy.get('[data-test=pager-previous]').should('not.be.visible');
    });

    context('secret', () => {
      beforeEach(() => {
        cy.get('[data-test=secrets-row]').first().as('firstSecret');
        cy.get('[data-test=secrets-row]').last().as('lastSecret');
      });

      it('should show copy', () => {
        cy.get('@firstSecret').within(() => {
          cy.get('[data-test=secrets-row-copy]').should('exist');
        });
        cy.get('@lastSecret').within(() => {
          cy.get('[data-test=secrets-row-copy]').should('exist');
        });
      });

      it('should copy secret to clipboard and alert', () => {
        cy.get('@firstSecret').within(() => {
          cy.get('[data-test=copy-secret]').click();
        });
        cy.get('[data-test=alerts]').should('exist').contains('Copied');
      });

      it('should show key', () => {
        cy.get('@firstSecret').within(() => {
          cy.get('[data-test=secrets-row-key]').contains(
            'github/docker_username',
          );
        });
        cy.get('@lastSecret').within(() => {
          cy.get('[data-test=secrets-row-key]').contains('github/deployment');
        });
      });

      it('should show name', () => {
        cy.get('@firstSecret').within(() => {
          cy.get('[data-test=secrets-row-name]').contains('docker_username');
        });
        cy.get('@lastSecret').within(() => {
          cy.get('[data-test=secrets-row-name]').contains('deployment');
        });
      });

      it('clicking name should route to edit secret page', () => {
        cy.get('@firstSecret').within(() => {
          cy.get('[data-test=secrets-row-name] > a').click({ force: true });
          cy.location('pathname').should(
            'eq',
            '/-/secrets/native/org/github/docker_username',
          );
        });
      });

      it('clicking name with special character should use encoded url', () => {
        cy.get('@lastSecret').within(() => {
          cy.get('[data-test=secrets-row-name] > a').click({ force: true });
          cy.location('pathname').should(
            'eq',
            '/-/secrets/native/org/github/github%2Fdeployment',
          );
        });
      });
    });
  });
});
