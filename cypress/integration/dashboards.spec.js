/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Dashboards', () => {
  context('server returns dashboard with 3 cards, one without builds', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/dashboards/86671eb5-a3ff-49e1-ad85-c3b2f648dcb2',
        'fixture:dashboard.json',
      );
      cy.login('/dashboards/86671eb5-a3ff-49e1-ad85-c3b2f648dcb2');
    });

    it('shows 3 dashboard cards', () => {
      cy.get('[data-test=dashboard-card]').should('have.length', 3);
    });

    it('shows an empty state when there are no builds', () => {
      cy.get('[data-test=dashboard-card]')
        .last()
        .contains('waiting for builds');
    });

    it('shows success build icon in header in the first card', () => {
      cy.get('[data-test=dashboard-card]')
        .first()
        .within(() => {
          cy.get('.-icon').should('have.class', '-success');
        });
    });

    it('shows failure build icon in header in the first card', () => {
      cy.get('[data-test=dashboard-card]')
        .eq(1)
        .within(() => {
          cy.get('.-icon').should('have.class', '-failure');
        });
    });

    it('org link in card header goes to org page', () => {
      cy.get('[data-test=dashboard-card]')
        .first()
        .within(() => {
          cy.get('.card-org').click();
          cy.location('pathname').should('eq', '/github');
        });
    });

    it('repo link in card header goes to repo page', () => {
      cy.get('[data-test=dashboard-card]')
        .first()
        .within(() => {
          cy.get('.card-repo').click();
          cy.location('pathname').should('eq', '/github/repo1');
        });
    });

    it('build link in card goes to build page', () => {
      cy.get('[data-test=dashboard-card]')
        .first()
        .within(() => {
          cy.get('.card-build-data li:first-child a').click();
          cy.location('pathname').should('eq', '/github/repo1/25');
        });
    });

    it('recent build link goes to respective build page', () => {
      cy.get('[data-test=recent-build-link-25]').click();
      cy.location('pathname').should('eq', '/github/repo1/25');
    });
  });

  context('server returning dashboard without repos', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/dashboards/86671eb5-a3ff-49e1-ad85-c3b2f648dcb2',
        'fixture:dashboard_no_repos.json',
      );
      cy.login('/dashboards/86671eb5-a3ff-49e1-ad85-c3b2f648dcb2');
    });

    it('shows message when there are no repositories added', () => {
      cy.get('[data-test=dashboard]').contains(
        `This dashboard doesn't have repositories added yet`,
      );
    });
  });

  context('dashboard not found', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        status: 404,
        url: '*api/v1/dashboards/deadbeef',
        response: {
          error:
            'unable to read dashboard deadbeef: ERROR: invalid input syntax for type uuid: "deadbeef" (SQLSTATE 22P02)',
        },
      });
      cy.login('/dashboards/deadbeef');
    });

    it('shows a not found message', () => {
      cy.get('[data-test=dashboard]').contains(
        'Dashboard "deadbeef" not found. Please check the URL.',
      );
    });
  });

  context('main dashboards page shows message', () => {
    beforeEach(() => {
      cy.server();
      cy.login('/dashboards');
    });

    it('shows the welcome message', () => {
      cy.get('[data-test=dashboards]').contains('Welcome to dashboards!');
    });
  });
});
