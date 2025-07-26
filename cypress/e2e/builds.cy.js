/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Builds', () => {
  context('server returning builds error', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/repos/*/*/builds*' },
        { statusCode: 500, body: 'server error' },
      );
      cy.stubBuild();
      cy.login('/github/octocat');
    });

    it('builds should not show', () => {
      cy.get('[data-test=builds]').should('not.exist');
    });
    it('error should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
    it('error banner should show', () => {
      cy.get('[data-test=builds-error]')
        .should('exist')
        .contains('try again later');
    });
  });

  context('logged in and server returning 5 builds', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/repos/*/*/builds*' },
        { fixture: 'builds_5.json' },
      );
      cy.stubBuild();
      cy.login('/github/octocat');
    });

    it('builds should show', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=builds]').should('be.visible');
    });

    it('cancel build button should be present when running', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('exist');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .next()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('not.exist');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .next()
        .next()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('not.exist');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .next()
        .next()
        .next()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('not.exist');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .next()
        .next()
        .next()
        .next()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('exist');
    });

    it('build menu should expand and close when action is fired', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('not.be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=restart-build]')
        .should('not.be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=build-menu]')
        .click();
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=restart-build]')
        .should('be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .click();
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('not.be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=restart-build]')
        .should('not.be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=build-menu]')
        .click();
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=restart-build]')
        .should('be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=restart-build]')
        .click();
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=cancel-build]')
        .should('not.be.visible');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .find('[data-test=restart-build]')
        .should('not.be.visible');
    });

    it('restart build button should be present', () => {
      cy.get('[data-test=restart-build]').should('exist');
    });

    it('builds should display commit message', () => {
      cy.get('[data-test=builds]').find('.commit-msg').should('be.visible');
    });

    it('longer build commit message should be truncated with ellipsis', () => {
      cy.get('[data-test=builds]')
        .find('.commit-msg')
        .should('have.css', 'text-overflow', 'ellipsis');
    });

    it('timestamp checkbox should be present', () => {
      cy.get('[data-test=time-toggle]').should('exist');
    });

    it('timestamp checkbox switches time when checked', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .find('.time-info .age')
        .should(elem => {
          expect(elem.text()).to.not.include('at');
        })
        .and('have.attr', 'title')
        .then(title => {
          expect(title).to.include('at');
        });

      cy.get('[data-test=time-toggle]').click({ force: true });

      cy.get('[data-test=builds]')
        .children()
        .first()
        .find('.time-info .age')
        .should(elem => {
          expect(elem.text()).to.include('at');
        })
        .and('have.attr', 'title')
        .then(title => {
          expect(title).to.not.include('at');
        });
    });
  });

  context('logged in and server returning 20 builds and running build', () => {
    beforeEach(() => {
      cy.stubBuilds();
      cy.stubBuild();
      cy.login('/github/octocat');
    });

    it('builds should show', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=builds]').should('be.visible');
    });

    it('builds should show build number', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .should('contain', '#1');
      cy.get('[data-test=builds]')
        .children()
        .last()
        .should('exist')
        .should('contain', '#10');
    });

    it('builds should display commit message', () => {
      cy.get('[data-test=builds]').find('.commit-msg').should('be.visible');
    });
    it('longer build commit message should be truncated with ellipsis', () => {
      cy.get('[data-test=builds]')
        .find('.commit-msg')
        .should('have.css', 'text-overflow', 'ellipsis');
    });

    it('build page 2 should show the next set of results', () => {
      cy.visit('/github/octocat?page=2');
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('exist')
        .should('contain', '#11');
      cy.get('@lastBuild').should('exist').should('contain', '#20');
      cy.get('[data-test=pager-next]').should('be.disabled');
    });

    it("loads the first page when hitting the 'previous' button", () => {
      cy.visit('/github/octocat?page=2');
      cy.get('[data-test=pager-previous]')
        .should('have.length', 2)
        .first()
        .click();
      cy.location('pathname').should('eq', '/github/octocat');
    });

    it('builds should show commit hash', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('contain', '9b1d8bd');
      cy.get('@lastBuild').should('contain', '7bd468e');
    });

    it('builds should show branch', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .should('be.visible')
        .should('contain', 'infra');
      cy.get('@lastBuild').should('be.visible').should('contain', 'terra');
    });

    it('build should having running style', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .get('[data-test=build-status]')
        .should('be.visible')
        .should('have.class', '-running');
    });

    it('build should display commit message', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .find('.commit-msg')
        .should('be.visible');
      cy.get('@lastBuild').find('.commit-msg').should('be.visible');
    });

    it('longer build commit message should be truncated with ellipsis', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .find('.commit-msg')
        .should('have.css', 'text-overflow', 'ellipsis');
      cy.get('@lastBuild')
        .find('.commit-msg')
        .should('have.css', 'text-overflow', 'ellipsis');
    });

    it('clicking build number should redirect to build page', () => {
      cy.get('[data-test=builds]')
        .children()
        .first()
        .get('[data-test=build-number]')
        .first()
        .click();
      cy.location('pathname').should('eq', '/github/octocat/1');
    });
  });

  context('logged in and server returning builds error', () => {
    beforeEach(() => {
      cy.stubBuildsErrors();
      cy.login('/github/octocat');
    });

    it('error alert should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
  });

  context('logged out and server returning 10 builds', () => {
    beforeEach(() => {
      cy.loggedOut();
      cy.stubBuilds();
      cy.visit('/github/octocat');
    });

    it('error alert should not show', () => {
      cy.get('[data-test=alerts]').should('be.not.visible');
    });

    it('builds should show login page', () => {
      cy.get('body').should('contain', 'Authorize Via');
    });
  });

  context('build filters', () => {
    beforeEach(() => {
      cy.stubBuildsFilter();
      cy.login('/github/octocat');
    });

    it('renders builds filter', () => {
      cy.wait(1000); // Wait for filter to load
      cy.get('[data-test=build-filter]').should('be.visible');
    });

    it('shows all results by default', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=build]')
        .should('be.visible')
        .should('have.length', 11);
    });

    it('should only show 7 push events', () => {
      cy.get('[data-test=build-filter-push]').click({ force: true });
      cy.wait(500); // Wait for filter to apply
      cy.get('[data-test=build]').should('be.visible').should('have.length', 7);
      cy.url().should('contain', '?event=push');
    });

    it('should only show two pull events', () => {
      cy.get('[data-test=build-filter-pull_request]').click({ force: true });
      cy.wait(500); // Wait for filter to apply
      cy.get('[data-test=build]').should('be.visible').should('have.length', 2);
      cy.url().should('contain', '?event=pull_request');
    });

    it('should only show one tag event', () => {
      cy.get('[data-test=build-filter-tag]').click({ force: true });
      cy.wait(500); // Wait for filter to apply
      cy.get('[data-test=build]').should('be.visible').should('have.length', 1);
      cy.url().should('contain', '?event=tag');
    });

    it('should show no results', () => {
      cy.get('[data-test=build-filter-deployment]').click({ force: true });
      cy.wait(500); // Wait for filter to apply
      cy.get('[data-test=build]').should('not.exist');
      cy.get('h3').should('contain', 'No builds for "deployment" event found.');
      cy.url().should('contain', '?event=deployment');
    });

    it('should only show one comment event', () => {
      cy.get('[data-test=build-filter-comment]').click({ force: true });
      cy.wait(500); // Wait for filter to apply
      cy.get('[data-test=build]').should('be.visible').should('have.length', 1);
      cy.url().should('contain', '?event=comment');
    });

    it('should only show two schedule event', () => {
      cy.get('[data-test=build-filter-schedule]').click({ force: true });
      cy.wait(500); // Wait for filter to apply
      cy.get('[data-test=build]').should('be.visible').should('have.length', 2);
      cy.url().should('contain', '?event=schedule');
    });
  });

  context('build filter /pulls shortcut', () => {
    beforeEach(() => {
      cy.stubBuildsFilter();
      cy.login('/github/octocat/pulls');
    });

    it('renders builds filter', () => {
      cy.wait(1000); // Wait for filter to load
      cy.get('[data-test=build-filter]').should('be.visible');
    });

    it('should only show two pull events', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=build]').should('be.visible').should('have.length', 2);
    });
  });

  context('build filter /tags shortcut', () => {
    beforeEach(() => {
      cy.stubBuildsFilter();
      cy.login('/github/octocat/tags');
    });

    it('renders builds filter', () => {
      cy.wait(1000); // Wait for filter to load
      cy.get('[data-test=build-filter]').should('be.visible');
    });

    it('should only show one tag event', () => {
      cy.wait(1000); // Wait for builds to load
      cy.get('[data-test=build]').should('be.visible').should('have.length', 1);
    });
  });
});
