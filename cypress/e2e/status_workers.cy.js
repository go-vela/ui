/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Workers', () => {
  beforeEach(() => {
    cy.intercept(
      { method: 'GET', url: '**/api/v1/user*' },
      {
        statusCode: 200,
        fixture: 'user.json',
      },
    );
  });
  context('server returning workers error', () => {
    beforeEach(() => {
      cy.login('/status/workers');
      // Override the success intercept from login with an error
      cy.intercept(
        { method: 'GET', url: '**/api/v1/workers*' },
        {
          statusCode: 500,
          body: 'server error',
        },
      );
      // Reload to trigger the error intercept
      cy.reload();
    });
    it('workers table should show error state', () => {
      cy.get('[data-test=workers-table]').should('be.visible');
      cy.get('[data-test=workers-error]').should('be.visible');
    });
    it('error should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
    it('error banner should show', () => {
      cy.get('[data-test=workers-error]')
        .should('exist')
        .contains('there was an error');
    });
  });
  context('server returning 5 workers', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/workers*' },
        { fixture: 'workers_5.json' },
      ).as('workers');
      cy.login('/status/workers');
    });
    it('workers table should show', () => {
      cy.get('[data-test=workers-table]').should('be.visible');
    });
    it('workers table should show 5 workers', () => {
      cy.wait(2000); // Wait for workers to load
      cy.get('[data-test=workers-row]').should('have.length', 5);
    });
    it('pagination controls should not show', () => {
      cy.wait(1000); // Wait for pagination check
      cy.get('[data-test=pager-previous]').should('not.exist');
    });
    context('worker', () => {
      beforeEach(() => {
        cy.wait(2000); // Wait for workers to load
        cy.get('[data-test=workers-row]').first().as('firstWorker');
        cy.get('[data-test=workers-row]').last().as('lastWorker');
        cy.get('[data-test=workers-row]').last().prev().prev().as('skipWorker');
      });
      it('should show status', () => {
        cy.get('@firstWorker').within(() => {
          cy.get('[data-test=cell-status]').contains('busy');
          cy.get('[data-test=cell-running-builds]').contains(
            'github/octocat/1',
          );
        });
      });
      context('error', () => {
        it('should have error styles', () => {
          cy.get('@lastWorker').should('have.class', 'status-error');
        });
      });
    });
  });
  context('server returning 10 workers', () => {
    beforeEach(() => {
      cy.workerPages();
      cy.login('/status/workers');
    });
    it('workers table should show 10 workers', () => {
      cy.wait(2000); // Wait for workers to load
      cy.get('[data-test=workers-row]').should('have.length', 10);
    });
    it('shows page 2 of the workers', () => {
      cy.visit('/status/workers?page=2');
      cy.wait(2000); // Wait for page 2 workers to load
      cy.get('[data-test=workers-row]').should('have.length', 10);
      cy.get('[data-test=pager-next]').should('be.disabled');
    });
    it("loads the first page when hitting the 'previous' button", () => {
      cy.visit('/status/workers?page=2');
      cy.wait(2000); // Wait for page 2 to load
      cy.get('[data-test=pager-previous]')
        .should('have.length', 2)
        .first()
        .should('not.be.disabled')
        .click();
      cy.location('pathname').should('eq', '/status/workers');
    });
    context('force 550, 750 resolution', () => {
      beforeEach(() => {
        cy.viewport(550, 750);
      });
      it('rows have responsive style', () => {
        cy.wait(2000); // Wait for workers to load with responsive styling
        cy.get('[data-test=workers-row]')
          .first()
          .should('have.css', 'border-bottom', '2px solid rgb(149, 94, 166)'); // check for lavender border
        cy.get('[data-test=workers-table]')
          .first()
          .should('have.css', 'border', '0px none rgb(250, 250, 250)'); // no base border
      });
    });
  });
});
