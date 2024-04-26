/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Workers', () => {
  beforeEach(() => {
    cy.server();
    cy.route({
      method: 'GET',
      url: '*api/v1/user*',
      status: 200,
      response: 'fixture:user_admin.json',
    });
  });
  context('server returning workers error', () => {
    beforeEach(() => {
      cy.route({
        method: 'GET',
        url: '*api/v1/workers*',
        status: 500,
        response: 'server error',
      });
      cy.loginAdmin('/admin/workers');
    });
    it('workers table should not show', () => {
      cy.get('[data-test=workers]').should('not.be.visible');
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
      cy.server();
      cy.route(
        'GET',
        '*api/v1/workers*',
        'fixture:workers_5.json',
      ).as('workers');
      cy.loginAdmin('/admin/workers');
    });
    it('workers table should show', () => {
      cy.get('[data-test=workers-table]').should('be.visible');
    });
    it('workers table should show 5 workers', () => {
      cy.get('[data-test=workers-row]').should('have.length', 5);
    });
    it('pagination controls should not show', () => {
      cy.get('[data-test=pager-previous]').should('not.be.visible');
    });
    context('worker', () => {
      beforeEach(() => {
        cy.get('[data-test=workers-row]').first().as('firstWorker');
        cy.get('[data-test=workers-row]').last().as('lastWorker');
        cy.get('[data-test=workers-row]').last().prev().prev().as('skipWorker');
      });
      it('should show status', () => {
        cy.get('@firstWorker').within(() => {
          cy.get('[data-test=cell-status]').contains('busy');
        });
      });
      context('error', () => {
        it('should have error styles', () => {
          cy.get('@lastWorker').should('have.class', '-error');
        });
      });
    });
  });
  context('server returning 10 workers', () => {
    beforeEach(() => {
      cy.server();
      cy.workerPages();
      cy.loginAdmin('/admin/workers');
    });
    it('workers table should show 10 workers', () => {
      cy.get('[data-test=workers-row]').should('have.length', 10);
    });
    it('shows page 2 of the workers', () => {
      cy.visit('/admin/workers?page=2');
      cy.get('[data-test=workers-row]').should('have.length', 10);
      cy.get('[data-test=pager-next]').should('be.disabled');
    });
    it("loads the first page when hitting the 'previous' button", () => {
      cy.visit('/admin/workers?page=2');
      cy.get('[data-test=pager-previous]')
        .should('have.length', 2)
        .first()
        .click();
      cy.location('pathname').should('eq', '/admin/workers');
    });
    context('force 550, 750 resolution', () => {
      beforeEach(() => {
        cy.viewport(550, 750);
      });
      // TODO: skip test for now; fix by updating to newer cypress/playwright
      it.skip('rows have responsive style', () => {
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
