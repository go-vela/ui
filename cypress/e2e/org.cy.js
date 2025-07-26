/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Org', () => {
  context('Tabs', () => {
    beforeEach(() => {
      cy.intercept({
        method: 'GET',
        url: '*api/v1/repos/vela',
        body: { fixture: 'repositories_5.json' },
      });
      cy.login('/vela');
    });

    it('should show 3 tabs', () => {
      cy.get('[data-test=jump-Repositories]').should('be.visible');
      cy.get('[data-test=jump-Builds]').should('be.visible');
      cy.get('[data-test=jump-Secrets]').should('be.visible');
    });
  });

  context('Repositories Tab', () => {
    context('logged in and server returning 5 repos', () => {
      beforeEach(() => {
        cy.intercept({
          method: 'GET',
          url: '*api/v1/repos/vela',
          body: { fixture: 'repositories_5.json' },
        });
        cy.login('/vela');

        cy.get('[data-test=repo-item]').as('repos');
      });

      it('should show 5 repos', () => {
        cy.get('@repos').should('have.length', 5);
      });

      it('should show 5 action buttons for each item', () => {
        cy.get('@repos').each(($repo, i, $list) => {
          cy.wrap($repo)
            .find('.button')
            .should('have.length', 5)
            .should('be.visible');
        });
      });
    });

    context('logged in and server returning > 10 repos', () => {
      beforeEach(() => {
        cy.stubRepos();
        cy.login('/vela');

        cy.get('[data-test=repo-item]').as('repos');
      });

      it('should show the repos', () => {
        cy.get('@repos').should('be.visible');
      });

      it('should show the pager', () => {
        cy.get('[data-test=pager-previous]')
          .should('have.length', 2)
          .should('be.visible')
          .should('be.disabled');

        cy.get('[data-test=pager-next]')
          .should('have.length', 2)
          .should('be.visible')
          .should('not.be.disabled');
      });

      it('should contain the page number on page 2', () => {
        cy.visit('/vela?page=2');
        cy.title().should('include', 'page 2');
      });

      it('should still show the pager on page 2', () => {
        cy.visit('/vela?page=2');
        cy.get('[data-test=pager-previous]')
          .should('have.length', 2)
          .should('be.visible')
          .should('not.be.disabled');

        cy.get('[data-test=pager-next]')
          .should('have.length', 2)
          .should('be.visible')
          .should('be.disabled');
      });
    });
  });

  context('Builds Tab', () => {
    context('logged in and returning 5 builds', () => {
      beforeEach(() => {
        cy.intercept({
          method: 'GET',
          url: '*api/v1/repos/vela/builds*',
          body: { fixture: 'builds_5.json' },
        });
        cy.login('/vela/builds');
      });

      it('should show 5 builds', () => {
        cy.get('[data-test=builds]').should('be.visible');
      });

      it('should show the filter control', () => {
        cy.get('[data-test=build-filter]').should('be.visible');
      });
    });

    context('logged in and returning 20 builds', () => {
      beforeEach(() => {
        cy.stubOrgBuilds();
        cy.login('/vela/builds');
      });

      it('should show builds', () => {
        cy.get('[data-test=builds]').should('be.visible');
      });

      it('should show the pager', () => {
        cy.get('[data-test=pager-previous]')
          .should('have.length', 2)
          .should('be.visible')
          .should('be.disabled');

        cy.get('[data-test=pager-next]')
          .should('have.length', 2)
          .should('be.visible')
          .should('not.be.disabled');
      });

      it('should update page title for page 2', () => {
        cy.visit('/vela/builds?page=2');
        cy.title().should('include', 'page 2');
      });
    });
  });

  context('Secrets Tab', () => {
    beforeEach(() => {
      cy.intercept({
        method: 'GET',
        url: '*api/v1/repos/vela',
        body: { fixture: 'repositories_5.json' },
      });
      cy.login('/vela');
    });

    it('should navigate to the org secrets page', () => {
      cy.get('[data-test=jump-Secrets').click();

      // just testing navigation, secrets specific tests should cover this route
      cy.location('pathname').should('eq', '/-/secrets/native/org/vela');
    });
  });
});
