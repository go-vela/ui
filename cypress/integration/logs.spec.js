/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */
context('visit Build with ansi encoded logs using url line fragment', () => {
  beforeEach(() => {
    cy.server();
    cy.stubBuild();
    cy.stubStepsWithANSILogs();
    cy.login('/someorg/somerepo/1');
    cy.get('[data-test=step-header-2]').click({ force: true });
    cy.get('[data-test=logs-1]').as('logs');
    cy.get('[data-test=step-header-2]').click({ force: true });
    cy.visit('/someorg/somerepo/1#step:2:31');
    cy.reload();
    cy.wait('@getLogs-2');
  });

  it('line should not contain ansi characters', () => {
    cy.get('[data-test=log-line-2-30]').within(() => {
      cy.get('[class=ansi-red-fg]').should('not.exist');
    });
  });

  it('line should contain ansi color css', () => {
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-green-fg]').should('exist');
      cy.get('[class=ansi-red-fg]').should('exist');
    });
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-bright-black-fg]').should('exist');
    });
  });

  it('ansi fg classes should change css color', () => {
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-green-fg]')
        .should('have.css', 'color')
        .should('eq', 'rgb(125, 209, 35)');
    });
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-red-fg]')
        .should('have.css', 'color')
        .should('eq', 'rgb(235, 102, 117)');
    });
  });

  it('line should respect ansi font style', () => {
    cy.get('[data-test=log-line-2-46]').within(() => {
      cy.get('.ansi-bold').should('exist');
    });
  });

  it('build should have collapse/expand actions', () => {
    cy.get('[data-test=log-actions]')
      .should('exist')
      .within(() => {
        cy.get('[data-test=collapse-all]').should('exist');
        cy.get('[data-test=expand-all]').should('exist');
      });
  });

  it('click collapse all should collapse all steps', () => {
    // expand unopened steps
    cy.get('[data-test=step-header-2]').click({ force: true });
    cy.clickSteps();

    // verify the steps are open
    cy.get('[data-test=step-header-1]').parent().should('have.attr', 'open');
    cy.get('[data-test=step-header-2]').parent().should('have.attr', 'open');
    cy.get('[data-test=step-header-3]').parent().should('have.attr', 'open');

    // collapse all
    cy.get('[data-test=collapse-all]').click({ force: true });

    // verify logs are hidden
    cy.get('[data-test=step-header-1]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-2]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-3]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-4]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-5]')
      .parent()
      .should('not.have.attr', 'open');
  });
  it('click expand all should expand all steps', () => {
    // close opened step
    cy.get('[data-test=step-header-2]').click({ force: true });

    // verify the steps are closed
    cy.get('[data-test=step-header-1]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-2]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-3]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-4]')
      .parent()
      .should('not.have.attr', 'open');
    cy.get('[data-test=step-header-5]')
      .parent()
      .should('not.have.attr', 'open');

    // collapse all
    cy.get('[data-test=expand-all]').click({ force: true });
    cy.wait('@getLogs-2');

    // verify logs are hidden
    cy.get('[data-test=step-header-1]').parent().should('have.attr', 'open');
    cy.get('[data-test=step-header-2]').parent().should('have.attr', 'open');
    cy.get('[data-test=step-header-3]').parent().should('have.attr', 'open');
    cy.get('[data-test=step-header-4]').parent().should('have.attr', 'open');
    cy.get('[data-test=step-header-5]').parent().should('have.attr', 'open');
  });

  it('log should have top and side log actions', () => {
    cy.get('[data-test=logs-2]').within(() => {
      cy.get('[data-test=logs-header-actions-2]').should('exist');
      cy.get('[data-test=logs-sidebar-actions-2]').should('exist');
    });
  });

  context('log with > 25 lines (long)', () => {
    it('top log actions should contain appropriate log actions', () => {
      cy.get('[data-test=logs-header-actions-2]').within(() => {
        cy.get('[data-test=jump-to-bottom-2]').should('not.exist');
        cy.get('[data-test=download-logs-2]').should('exist');
        cy.get('[data-test=follow-logs-2]').should('not.exist');
      });
    });

    it('sidebar should contain appropriate actions', () => {
      cy.get('[data-test=logs-sidebar-actions-2]').within(() => {
        cy.get('[data-test=jump-to-top-2]').should('exist');
        cy.get('[data-test=jump-to-bottom-2]').should('exist');
        cy.get('[data-test=follow-logs-2]').should('exist');
      });
    });

    it('should have trackers', () => {
      cy.get('[data-test=logs-2]').within(() => {
        cy.get('[data-test=bottom-log-tracker-2]').should('exist');
        cy.get('[data-test=top-log-tracker-2]').should('exist');
      });
    });

    it('bottom tracker should not have focus', () => {
      cy.focused().should('not.have.attr', 'data-test', 'bottom-log-tracker-2');
    });

    it('click jump to bottom should focus bottom tracker', () => {
      cy.get('[data-test=jump-to-bottom-2]').click({ force: true });
      cy.focused().should('have.attr', 'data-test', 'bottom-log-tracker-2');
    });

    it('top tracker should not have focus', () => {
      cy.focused().should('not.have.attr', 'data-test', 'top-log-tracker-2');
    });

    it('click jump to top should focus top tracker', () => {
      cy.get('[data-test=jump-to-top-2]').click({ force: true });
      cy.focused().should('have.attr', 'data-test', 'top-log-tracker-2');
    });

    it('click follow logs should focus follow new logs', () => {
      // verify no prior focus
      cy.focused().should('not.have.attr', 'data-test', 'bottom-log-tracker-2');

      // follow logs
      cy.get('[data-test=follow-logs-2]').first().click({ force: true });

      // wait for refresh and check for bottom focus
      cy.wait('@getLogs-2');
      cy.focused().should('have.attr', 'data-test', 'bottom-log-tracker-2');
    });
  });

  context('log with < 25 lines (short)', () => {
    beforeEach(() => {
      cy.get('[data-test=step-header-5]').click({ force: true });
    });

    it('logs header should contain limited actions', () => {
      cy.get('[data-test=logs-header-actions-5]').within(() => {
        cy.get('[data-test=jump-to-bottom-5]').should('not.exist');
        cy.get('[data-test=jump-to-top-5]').should('not.exist');
        cy.get('[data-test=download-logs-5]').should('exist');
      });
    });
  });

  context('log with no data (empty log)', () => {
    beforeEach(() => {
      cy.get('[data-test=step-header-1]').click({ force: true });
    });

    it('logs header actions should not exist', () => {
      cy.get('[data-test=logs-header-actions-1]').should('not.exist');
    });

    it('logs sidebar actions should not exist', () => {
      cy.get('[data-test=logs-sidebar-actions-1]').should('not.exist');
    });
  });
});
