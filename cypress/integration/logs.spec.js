/*
 * SPDX-License-Identifier: Apache-2.0
 */
context(
  'visit Build with steps and ansi encoded logs using url line fragment',
  () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithANSILogs();
      cy.login('/github/octocat/1');
      cy.get('[data-test=step-header-2]').click({ force: true });
      cy.get('[data-test=logs-2]').as('logs');
      cy.get('[data-test=step-header-2]').click({ force: true });
      cy.visit('/github/octocat/1#2:31');
      cy.reload();
      cy.wait('@getLogs-2');
    });

    it('line should not contain ansi characters', () => {
      cy.get('[data-test=log-line-2-1]').within(() => {
        cy.get('[class=ansi-red-fg]').should('not.exist');
      });
    });

    it('line should contain ansi color css', () => {
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-green-fg]').should('exist');
        cy.get('[class=ansi-red-fg]').should('exist');
      });
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-bright-black-fg]').should('exist');
      });
    });

    it('ansi fg classes should change css color', () => {
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-green-fg]')
          .should('have.css', 'color')
          .should('eq', 'rgb(125, 209, 35)');
      });
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-red-fg]')
          .should('have.css', 'color')
          .should('eq', 'rgb(235, 102, 117)');
      });
    });

    it('line should respect ansi font style', () => {
      cy.get('[data-test=log-line-2-3]').within(() => {
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
        cy.focused().should(
          'not.have.attr',
          'data-test',
          'bottom-log-tracker-2',
        );
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
        // stub short logs
        cy.route({
          method: 'GET',
          url: 'api/v1/repos/*/*/builds/*/steps/2/logs',
          status: 200,
          response: 'fixture:log_step_short.json',
        }).as('getLogs-2');

        // verify no prior focus
        cy.focused().should(
          'not.have.attr',
          'data-test',
          'bottom-log-tracker-2',
        );

        cy.wait('@getLogs-2');

        // follow logs
        cy.get('[data-test=follow-logs-2]').first().click({ force: true });

        // stub long logs to trigger follow
        cy.route({
          method: 'GET',
          url: 'api/v1/repos/*/*/builds/*/steps/2/logs',
          status: 200,
          response: 'fixture:log_step_long.json',
        }).as('getLogs-2');

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

      it('logs header actions should exist', () => {
        cy.get('[data-test=logs-header-actions-1]').should('be.visible');
      });

      it('download button should not be visible', () => {
        cy.get('[data-test=download-logs-1]').should('not.be.visible');
      });

      it('logs data should contain helpful message', () => {
        cy.get('[data-test=log-line-1-1]').should(
          'contain',
          'The build has not written anything to this log yet.',
        );
      });

      it('logs sidebar actions should be visible', () => {
        cy.get('[data-test=logs-sidebar-actions-1]').should('be.visible');
      });
    });
  },
);

context(
  'visit Build with services and ansi encoded logs using url line fragment',
  () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubServicesWithANSILogs();
      cy.login('/github/octocat/1/services');
      cy.get('[data-test=service-header-2]').click({ force: true });
      cy.get('[data-test=logs-2]').as('logs');
      cy.get('[data-test=service-header-2]').click({ force: true });
      cy.visit('/github/octocat/1/services#2:31');
      cy.reload();
      cy.wait('@getLogs-2');
    });

    it('line should not contain ansi characters', () => {
      cy.get('[data-test=log-line-2-1]').within(() => {
        cy.get('[class=ansi-red-fg]').should('not.exist');
      });
    });

    it('line should contain ansi color css', () => {
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-green-fg]').should('exist');
        cy.get('[class=ansi-red-fg]').should('exist');
      });
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-bright-black-fg]').should('exist');
      });
    });

    it('ansi fg classes should change css color', () => {
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-green-fg]')
          .should('have.css', 'color')
          .should('eq', 'rgb(125, 209, 35)');
      });
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[class=ansi-red-fg]')
          .should('have.css', 'color')
          .should('eq', 'rgb(235, 102, 117)');
      });
    });

    it('line should respect ansi font style', () => {
      cy.get('[data-test=log-line-2-3]').within(() => {
        cy.get('.ansi-bold').should('exist');
      });
    });

    it('build services should have collapse/expand actions', () => {
      cy.get('[data-test=log-actions]')
        .should('exist')
        .within(() => {
          cy.get('[data-test=collapse-all]').should('exist');
          cy.get('[data-test=expand-all]').should('exist');
        });
    });

    it('click collapse all should collapse all services', () => {
      // expand unopened services
      cy.get('[data-test=service-header-2]').click({ force: true });
      cy.clickServices();

      // verify the services are open
      cy.get('[data-test=service-header-1]')
        .parent()
        .should('have.attr', 'open');
      cy.get('[data-test=service-header-2]')
        .parent()
        .should('have.attr', 'open');
      cy.get('[data-test=service-header-3]')
        .parent()
        .should('have.attr', 'open');

      // collapse all
      cy.get('[data-test=collapse-all]').click({ force: true });

      // verify logs are hidden
      cy.get('[data-test=service-header-1]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-2]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-3]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-4]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-5]')
        .parent()
        .should('not.have.attr', 'open');
    });
    it('click expand all should expand all services', () => {
      // close opened service
      cy.get('[data-test=service-header-2]').click({ force: true });

      // verify the services are closed
      cy.get('[data-test=service-header-1]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-2]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-3]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-4]')
        .parent()
        .should('not.have.attr', 'open');
      cy.get('[data-test=service-header-5]')
        .parent()
        .should('not.have.attr', 'open');

      // collapse all
      cy.get('[data-test=expand-all]').click({ force: true });
      cy.wait('@getLogs-2');

      // verify logs are hidden
      cy.get('[data-test=service-header-1]')
        .parent()
        .should('have.attr', 'open');
      cy.get('[data-test=service-header-2]')
        .parent()
        .should('have.attr', 'open');
      cy.get('[data-test=service-header-3]')
        .parent()
        .should('have.attr', 'open');
      cy.get('[data-test=service-header-4]')
        .parent()
        .should('have.attr', 'open');
      cy.get('[data-test=service-header-5]')
        .parent()
        .should('have.attr', 'open');
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
        cy.focused().should(
          'not.have.attr',
          'data-test',
          'bottom-log-tracker-2',
        );
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
        // stub short logs
        cy.route({
          method: 'GET',
          url: 'api/v1/repos/*/*/builds/*/services/2/logs',
          status: 200,
          response: 'fixture:log_service_short.json',
        }).as('getLogs-2');

        // verify no prior focus
        cy.focused().should(
          'not.have.attr',
          'data-test',
          'bottom-log-tracker-2',
        );

        cy.wait('@getLogs-2');

        // follow logs
        cy.get('[data-test=follow-logs-2]').first().click({ force: true });

        // stub long logs to trigger follow
        cy.route({
          method: 'GET',
          url: 'api/v1/repos/*/*/builds/*/services/2/logs',
          status: 200,
          response: 'fixture:log_service_long.json',
        }).as('getLogs-2');

        // wait for refresh and check for bottom focus
        cy.wait('@getLogs-2');

        cy.focused().should('have.attr', 'data-test', 'bottom-log-tracker-2');
      });
    });

    context('log with < 25 lines (short)', () => {
      beforeEach(() => {
        cy.get('[data-test=service-header-5]').click({ force: true });
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
        cy.get('[data-test=service-header-1]').click({ force: true });
      });

      it('logs header actions should exist', () => {
        cy.get('[data-test=logs-header-actions-1]').should('be.visible');
      });

      it('download button should not be visible', () => {
        cy.get('[data-test=download-logs-1]').should('not.be.visible');
      });

      it('logs data should contain helpful message', () => {
        cy.get('[data-test=log-line-1-1]').should(
          'contain',
          'The build has not written anything to this log yet.',
        );
      });

      it('logs sidebar actions should be visible', () => {
        cy.get('[data-test=logs-sidebar-actions-1]').should('be.visible');
      });
    });
  },
);

context('visit Build with steps and large logs', () => {
  beforeEach(() => {
    cy.server();
    cy.stubBuild();
    cy.stubStepsWithLargeLogs();
    cy.login('/github/octocat/1');
    cy.get('[data-test=step-header-1]').click({ force: true });
  });

  it('line should contain size exceeded message', () => {
    cy.get('[data-test=log-line-1-1]').should(
      'contain',
      'exceeds the size limit',
    );
  });

  it('second line should contain download tip', () => {
    cy.get('[data-test=log-line-1-2]').should('contain', 'download');
  });

  it('download button should show', () => {
    cy.get('[data-test=download-logs-1]').should('exist');
  });
});
context(
  'visit Build with steps and linked logs using url line fragment',
  () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithLinkedLogs();
      cy.login('/github/octocat/1');
      cy.get('[data-test=step-header-2]').click({ force: true });
      cy.get('[data-test=logs-2]').as('logs');
      cy.get('[data-test=step-header-2]').click({ force: true });
      cy.visit('/github/octocat/1#2:31');
      cy.reload();
      cy.wait('@getLogs-2');
    });

    it('lines should not contain link', () => {
      cy.get('[data-test=log-line-2-1]').within(() => {
        cy.get('[data-test=log-line-link]').should('not.exist');
      });
      cy.get('[data-test=log-line-2-2]').within(() => {
        cy.get('[data-test=log-line-link]').should('not.exist');
      });
      cy.get('[data-test=log-line-2-3]').within(() => {
        cy.get('[data-test=log-line-link]').should('not.exist');
      });
    });

    it('lines should contain https link', () => {
      cy.get('[data-test=log-line-2-4]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-5]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-6]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-7]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-8]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-9]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-10]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-11]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
      cy.get('[data-test=log-line-2-12]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
      });
    });

    it('line should contain ansi color and link', () => {
      cy.get('[data-test=log-line-2-13]').within(() => {
        cy.get('[data-test=log-line-link]').should('exist');
        cy.get('[class=ansi-magenta-bg]').should('exist');
        cy.get('[class=ansi-magenta-bg]').should(
          'have.css',
          'background-color',
        );
      });
    });
  },
);
