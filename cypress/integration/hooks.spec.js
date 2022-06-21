/*
 * Copyright (c) 2022 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Hooks', () => {
  context('server returning hooks error', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '*api/v1/hooks/github/octocat*',
        status: 500,
        response: 'server error',
      });
      cy.login('/github/octocat/hooks');
    });

    it('hooks table should not show', () => {
      cy.get('[data-test=hooks]').should('not.be.visible');
    });
    it('error should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
    it('error banner should show', () => {
      cy.get('[data-test=hooks-error]')
        .should('exist')
        .contains('try again later');
    });
  });
  context('server returning 5 hooks', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/hooks/github/octocat*',
        'fixture:hooks_5.json',
      ).as('hooks');
      cy.route(
        'GET',
        '*api/v1/repos/*/octocat/builds/1*',
        'fixture:build_success.json',
      );
      cy.route(
        'GET',
        '*api/v1/repos/*/octocat/builds/2*',
        'fixture:build_failure.json',
      );
      cy.route(
        'GET',
        '*api/v1/repos/*/octocat/builds/3*',
        'fixture:build_running.json',
      );
      cy.login('/github/octocat/hooks');
    });

    it('hooks table should show', () => {
      cy.get('[data-test=hooks-table]').should('be.visible');
    });

    it('hooks table should show 5 hooks', () => {
      cy.get('[data-test=hooks-row]').should('have.length', 5);
    });

    it('pagination controls should not show', () => {
      cy.get('[data-test=pager-previous]').should('not.be.visible');
    });

    context('hook', () => {
      beforeEach(() => {
        cy.get('[data-test=hooks-row]').first().as('firstHook');
        cy.get('[data-test=hooks-row]').last().as('lastHook');
      });
      it('should show source id', () => {
        cy.get('@firstHook').within(() => {
          cy.get('.source-id').contains('7bd477e4-4415-11e9-9359-0d41fdf9567e');
        });
      });
      it('should show event', () => {
        cy.get('@firstHook').contains('push');
      });
      it('should show host', () => {
        cy.get('@firstHook').contains('github.com');
      });
      it('should show redeliver hook', () => {
        cy.get('@firstHook').within(() => {
          cy.get('[data-test=redeliver-hook-5]').should('exist');
        });
      });
      context('failure', () => {
        beforeEach(() => {
          cy.get('@lastHook').within(() => {
            cy.get('.hook-status').as('failure');
          });
        });
        it('should have failure styles', () => {
          cy.get('@failure').should('have.class', '-failure');
        });
        context('error', () => {
          beforeEach(() => {
            cy.get('[data-test=hooks-error]').as('error');
          });
          it('should show error', () => {
            cy.get('@error').contains(
              'github/octocat does not have tag events enabled',
            );
          });
        });
      });
      context('successful redeliver hook', () => {
        beforeEach(() => {
          cy.redeliverHook();
          cy.get('[data-test=redeliver-hook-1]').as('redeliverHook');
        });

        it('should show successful toasty.', () => {
          cy.get('@redeliverHook').click();
          cy.get('[data-test=alert]').should('contain', 'hook * redelivered');
        });
      });
      context('unsuccessful redeliver hook', () => {
        beforeEach(() => {
          cy.redeliverHookError();
        });

        it('should show error', () => {
          cy.get('[data-test=alerts]').should('exist').contains('Error');
        });
      });
    });
  });

  context('server returning 10 hooks', () => {
    beforeEach(() => {
      cy.server();
      cy.hookPages();

      cy.login('/github/octocat/hooks');
    });

    it('hooks table should show 10 hooks', () => {
      cy.get('[data-test=hooks-row]').should('have.length', 10);
    });

    it('shows page 2 of the hooks', () => {
      cy.visit('/github/octocat/hooks?page=2');
      cy.get('[data-test=hooks-row]').should('have.length', 10);
      cy.get('[data-test=pager-next]').should('be.disabled');
    });

    it("loads the first page when hitting the 'previous' button", () => {
      cy.visit('/github/octocat/hooks?page=2');
      cy.get('[data-test=pager-previous]')
        .should('have.length', 2)
        .first()
        .click();
      cy.location('pathname').should('eq', '/github/octocat/hooks');
    });

    context('force 550, 750 resolution', () => {
      beforeEach(() => {
        cy.viewport(550, 750);
      });
      it('rows have responsive style', () => {
        cy.get('[data-test=hooks-row]')
          .first()
          .should('have.css', 'border-bottom', '2px solid rgb(149, 94, 166)'); // check for lavender border
        cy.get('[data-test=hooks-table]')
          .first()
          .should('have.css', 'border', '0px none rgb(250, 250, 250)'); // no base border
      });
    });
  });
});
