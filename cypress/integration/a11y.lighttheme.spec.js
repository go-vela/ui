/*
 * SPDX-License-Identifier: Apache-2.0
 */

const A11Y_OPTS = {
  runOnly: {
    type: 'tag',
    values: ['section508', 'best-practice', 'wcag21aa', 'wcag2aa'],
  },
};

context('Accessibility (a11y)', () => {
   context('Logged out', () => {
     it('overview', () => {
      //cy.clearSession();
      cy.setTheme('theme-light');
      cy.visit('/account/login');
      cy.injectAxe();
      cy.wait(500);
      cy.checkA11y(null, A11Y_OPTS);
    });
  });

  context('Logged in', () => {
    beforeEach(() => {
      //cy.clearSession();
      cy.setTheme('theme-light');
      cy.server();
      // overview page
      cy.route('GET', '*api/v1/repos*', 'fixture:favorites.json');
      // source repos page
      cy.route(
        'GET',
        '*api/v1/user/source/repos*',
        'fixture:source_repositories.json',
      );
      // settings page
      cy.route('GET', '*api/v1/repos/*/octocat', 'fixture:repository.json');
      // repo and build page
      cy.stubBuilds();
      cy.stubBuild();
      cy.stubStepsWithLogs();
      // hooks page
      cy.route('GET', '*api/v1/hooks/github/octocat*', 'fixture:hooks_5.json');
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
    });
    after(() => {
      cy.visit('/');
      cy.server({ enable: false });
    });

    it('overview', () => {
      cy.checkA11yForPage('/', A11Y_OPTS);
    });

    it('source repos', () => {
      cy.checkA11yForPage('/account/source-repos', A11Y_OPTS);
    });

    it('settings', () => {
      cy.checkA11yForPage('/github/octocat/settings', A11Y_OPTS);
    });

    it('repo page', () => {
      cy.checkA11yForPage('/github/octocat', A11Y_OPTS);
    });

    it('hooks page', () => {
      cy.checkA11yForPage('/github/octocat/hooks', A11Y_OPTS);
    });

    it('build page', () => {
      cy.login('/github/octocat/1');
      cy.injectAxe();
      cy.wait(500);
      cy.clickSteps();
      cy.checkA11y(null, A11Y_OPTS);
    });
  });
});
