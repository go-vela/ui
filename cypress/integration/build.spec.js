/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Build', () => {
  context('logged in and server returning build error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuildErrors();
      cy.stubBuildsErrors();
      cy.stubStepsErrors();
      cy.login('/github/octocat/1');
    });
    it('error alert should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
  });
  context('logged in and server returning 5 builds', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.route('GET', '*api/v1/repos/*/*/builds*', 'fixture:builds_5.json');
      cy.login('/github/octocat/1');
      cy.get('[data-test=build-history]').as('buildHistory');
    });

    it('build history should show', () => {
      cy.get('@buildHistory').should('be.visible');
    });

    it('build history should have 5 builds', () => {
      cy.get('@buildHistory').should('be.visible');
      cy.get('@buildHistory').children().should('have.length', 5);
    });

    it('clicking build history item should redirect to build page', () => {
      cy.get('[data-test=recent-build-link-105]').children().last().click();
      cy.location('pathname').should('eq', '/github/octocat/105');
    });
  });

  context('logged in and server returning 0 builds', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: 'api/v1/repos/*/*/builds?page=1&per_page=100',
        response: [],
      });
      cy.login('/github/octocat/1');
    });

    it('build history should not show', () => {
      cy.get('[data-test=build-history]').should('not.exist');
    });
  });

  context('logged in and server returning builds and single build', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubBuilds();
      cy.login('/github/octocat/1');
    });

    context('server returning 55 builds', () => {
      beforeEach(() => {
        cy.get('[data-test=build-history]').as('buildHistory');
      });

      it('build history should show', () => {
        cy.get('@buildHistory').should('be.visible');
      });

      it('build history should have 10 builds', () => {
        cy.get('@buildHistory').should('be.visible');
        cy.get('@buildHistory').children().should('have.length', 10);
      });

      it('clicking build history item should redirect to build page', () => {
        cy.get('[data-test=recent-build-link-1]').children().last().click();
        cy.location('pathname').should('eq', '/github/octocat/1');
      });

      context('hover build history item', () => {
        beforeEach(() => {
          cy.get('[data-test=build-history-tooltip]').last().as('tooltip');
        });

        it('should show build event', () => {
          cy.get('@tooltip').should('contain', 'push');
        });

        it('should show build number', () => {
          cy.get('@tooltip').should('contain', '10');
        });

        it('should show build times', () => {
          cy.get('@tooltip').should('contain', 'started');
          cy.get('@tooltip').should('contain', 'finished');
        });

        it('should show commit', () => {
          cy.get('@tooltip').should('contain', 'commit');
          cy.get('@tooltip').should('contain', '7bd468e');
        });

        it('should show branch', () => {
          cy.get('@tooltip').should('contain', 'branch');
          cy.get('@tooltip').should('contain', 'terra');
        });

        it('should show worker', () => {
          cy.get('@tooltip').should('contain', 'worker');
          cy.get('@tooltip').should('contain', 'https://vela-worker-6.com');
        });
      });
    });

    context('server stubbed Restart Build', () => {
      beforeEach(() => {
        cy.server();
        cy.fixture('build_pending.json').as('restartedBuild');
        cy.route({
          method: 'POST',
          url: 'api/v1/repos/*/*/builds/*',
          status: 200,
          response: '@restartedBuild',
        });
        cy.get('[data-test=restart-build]').as('restartBuild');
      });

      it('clicking restart build should show alert', () => {
        cy.get('@restartBuild').click();
        cy.get('[data-test=alert]').should(
          'contain',
          'github/octocat/1 restarted',
        );
      });

      it('clicking restarted build link should redirect to Build page', () => {
        cy.get('@restartBuild').click({ force: true });
        cy.get('[data-test=alert-hyperlink]').click({ force: true });
        cy.location('pathname').should('eq', '/github/octocat/2');
      });
    });

    context('server failing to restart build', () => {
      beforeEach(() => {
        cy.server();
        cy.fixture('build_pending.json').as('restartedBuild');
        cy.route({
          method: 'POST',
          url: 'api/v1/repos/*/*/builds/*',
          status: 500,
          response: 'server error',
        });
        cy.get('[data-test=restart-build]').as('restartBuild');
      });

      it('clicking restart build should show error alert', () => {
        cy.get('@restartBuild').click();
        cy.get('[data-test=alert]').should('contain', 'Error');
      });
    });

    context('server stubbed Cancel Build', () => {
      beforeEach(() => {
        cy.server();
        cy.route({
          method: 'DELETE',
          url: 'api/v1/repos/*/*/builds/*/cancel',
          status: 200,
          response: 'canceled build github/octocat/1',
        });
        cy.login('/github/octocat/1');
        cy.get('[data-test=cancel-build]').as('cancelBuild');
      });

      it('clicking cancel build should show alert', () => {
        cy.get('@cancelBuild').click();
        cy.get('[data-test=alert]').should(
          'contain',
          'canceled build github/octocat/1',
        );
      });
    });

    context('server failing to cancel build', () => {
      beforeEach(() => {
        cy.server();
        cy.route({
          method: 'DELETE',
          url: 'api/v1/repos/*/*/builds/*/cancel',
          status: 500,
          response: 'server error',
        });
        cy.get('[data-test=cancel-build]').as('cancelBuild');
      });

      it('clicking cancel build should show error alert', () => {
        cy.get('@cancelBuild').click();
        cy.get('[data-test=alert]').should('contain', 'Error');
      });
    });

    context('server stubbed Approve Build', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/8');
        cy.server();
        cy.fixture('build_pending_approval.json').as('approveBuild');
        cy.route({
          method: 'POST',
          url: 'api/v1/repos/*/*/builds/*/approve',
          status: 200,
          response: 'approved build github/octocat/8',
        });
        cy.get('[data-test=approve-build]').as('approvedBuild');
      });

      it('there should be a notice banner', () => {
        cy.get('[data-test=approve-build-notice').should('exist');
      });

      it('clicking cancel build should show alert', () => {
        cy.get('@approvedBuild').click();
        cy.get('[data-test=alert]').should(
          'contain',
          'approved build github/octocat/8',
        );
      });
    });

    context('visit running build', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/1');
        cy.get('[data-test=build]').as('build');
        cy.get('@build').get('[data-test=build-status]').as('buildStatus');
      });

      it('build should show', () => {
        cy.get('@build').should('be.visible');
      });

      it('build should show commit hash', () => {
        cy.get('@build').should('contain', '9b1d8bd');
      });

      it('build should show branch', () => {
        cy.get('@build').should('be.visible').should('contain', 'infra');
      });

      it('build should have running style', () => {
        cy.get('@buildStatus').should('have.class', '-running');
      });

      it('build should display commit message', () => {
        cy.get('@build').find('.commit-msg').should('be.visible');
      });
      it('longer build commit message should be truncated with ellipsis', () => {
        cy.get('@build')
          .find('.commit-msg')
          .should('have.css', 'text-overflow', 'ellipsis');
      });
      it('build should annotate the age with the full timestamp', () => {
        cy.get('@build').find('.time-info .age').should('have.attr', 'title');
      });
    });

    context('visit pending build', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/2');
        cy.get('[data-test=build]').as('build');
        cy.get('@build').get('[data-test=build-status]').as('buildStatus');
      });

      it('build should have pending style', () => {
        cy.get('@buildStatus').should('have.class', '-pending');
      });
    });

    context('visit success build', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/3');
        cy.get('[data-test=build]').as('build');
        cy.get('@build').get('[data-test=build-status]').as('buildStatus');
      });

      it('build should have success style', () => {
        cy.get('@buildStatus').should('have.class', '-success');
      });
    });

    context('visit failure build', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/4');
        cy.get('[data-test=build]').as('build');
        cy.get('@build').get('[data-test=build-status]').as('buildStatus');
      });

      it('build should have failure style', () => {
        cy.get('@buildStatus').should('have.class', '-failure');
      });
    });

    context('visit build with server error', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/5');
        cy.get('[data-test=build]').as('build');
        cy.get('@build').get('[data-test=build-status]').as('buildStatus');
      });

      it('build should have error style', () => {
        cy.get('@buildStatus').should('have.class', '-error');
      });

      it('build error should show', () => {
        cy.get('[data-test=build-error]').should('be.visible');
      });

      it('build error should contain error', () => {
        cy.get('[data-test=build-error]').contains('error:');
        cy.get('[data-test=build-error]').contains('failure authenticating');
      });
    });

    context('visit canceled build', () => {
      beforeEach(() => {
        cy.visit('/github/octocat/6');
        cy.get('[data-test=build]').as('build');
        cy.get('@build').get('[data-test=build-status]').as('buildStatus');
      });

      it('build should have canceled style', () => {
        cy.get('@buildStatus').should('have.class', '-canceled');
      });

      it('build error should show', () => {
        cy.get('[data-test=build-error]').should('be.visible');
      });

      it('build error should contain error', () => {
        cy.get('[data-test=build-error]').contains('auto canceled:');
        cy.get('[data-test=build-error]').contains(
          'build auto canceled in favor of build #7',
        );
      });

      it('clicking superseding build link should direct to new build page', () => {
        cy.get('[data-test=new-build-link]').click({ force: true });
        cy.location('pathname').should('eq', '/github/octocat/7');
      });
    });
  });
});
