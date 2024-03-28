/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Build Graph', () => {
  context('logged in and server returning build graph error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuildErrors();
      cy.stubBuildsErrors();
      cy.stubStepsErrors();
      cy.login('/github/octocat/1/graph');
    });
    it('error alert should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
  });
  context(
    'logged in and server returning a build graph, build and steps',
    () => {
      beforeEach(() => {
        cy.server();
        cy.route('GET', '*api/v1/repos/*/*/builds*', 'fixture:builds_5.json');
        cy.route(
          'GET',
          '*api/v1/repos/*/*/builds/*',
          'fixture:build_success.json',
        );
        cy.route(
          'GET',
          '*api/v1/repos/*/*/builds/*/graph',
          'fixture:build_graph.json',
        );
        cy.route('GET', '*api/v1/repos/*/octocat', 'fixture:repository.json');
        cy.login('/github/octocat/4/graph');
      });
      it('build graph root should be visible', () => {
        cy.get('.elm-build-graph-root').should('be.visible');
      });
      it('node should reflect build information', () => {
        cy.get('.elm-build-graph-node-3').should(
          'have.id',
          '#3,init,success,false',
        );
        cy.get('.d3-build-graph-node-outline-3').should(
          'have.class',
          '-success',
        );
      });
      it('edge should contain build information', () => {
        cy.get('.elm-build-graph-edge-3-4').should(
          'have.id',
          '#3,4,success,false',
        );
        cy.get('.d3-build-graph-edge-path-3-4').should(
          'have.class',
          '-success',
        );
      });
      it('click node should apply focus', () => {
        cy.get('.elm-build-graph-node-3')
          .should('have.id', '#3,init,success,false')
          .within(e => {
            cy.get('a').first().click({ force: true });
          });
        cy.get('.elm-build-graph-node-3').should(
          'have.id',
          '#3,init,success,true',
        );
        cy.get('.d3-build-graph-node-outline-3').should('have.class', '-focus');
      });

      it('node styles should reflect status', () => {
        // services
        cy.get('.d3-build-graph-node-outline-0').should(
          'have.class',
          '-pending',
        );
        cy.get('.d3-build-graph-node-outline-1').should(
          'have.class',
          '-running',
        );
        cy.get('.d3-build-graph-node-outline-2').should(
          'have.class',
          '-canceled',
        );

        // stages
        cy.get('.d3-build-graph-node-outline-3').should(
          'have.class',
          '-success',
        );
        cy.get('.d3-build-graph-node-outline-4').should(
          'have.class',
          '-failure',
        );
        cy.get('.d3-build-graph-node-outline-5').should(
          'have.class',
          '-killed',
        );
      });
      it('legend should show', () => {
        cy.get('.elm-build-graph-legend').should('be.visible');
        cy.get('.elm-build-graph-legend-node').should('have.length', 7);
      });
      it('actions should show', () => {
        cy.get('.elm-build-graph-actions').should('be.visible');
        cy.get('[data-test=build-graph-action-toggle-services]').should(
          'be.visible',
        );
        cy.get('[data-test=build-graph-action-toggle-steps]').should(
          'be.visible',
        );
        cy.get('[data-test=build-graph-action-filter]').should('be.visible');
        cy.get('[data-test=build-graph-action-filter-clear]').should(
          'be.visible',
        );
      });
      it('click "show services" should hide services', () => {
        cy.get('.elm-build-graph-node-0').should('contain', 'postgres');
        cy.get('[data-test=build-graph-action-toggle-services]')
          .should('be.visible')
          .click({ force: true });
        cy.get('.elm-build-graph-node-0').should('not.contain', 'postgres');
        cy.get('[data-test=build-graph-action-toggle-services]')
          .should('be.visible')
          .click({ force: true });
        cy.get('.elm-build-graph-node-0').should('contain', 'postgres');
      });
      it('click "show steps" should hide steps', () => {
        cy.get('.elm-build-graph-node-5').should('contain', 'sleep');
        cy.get('[data-test=build-graph-action-toggle-steps]')
          .should('be.visible')
          .click({ force: true });
        cy.get('.elm-build-graph-node-5').should('not.contain', 'sleep');
        cy.get('[data-test=build-graph-action-toggle-steps]')
          .should('be.visible')
          .click({ force: true });
        cy.get('.elm-build-graph-node-5').should('contain', 'sleep');
      });
      it('filter input and clear button should control focus', () => {
        cy.get('.elm-build-graph-node-5').should(
          'have.id',
          '#5,stage-a,killed,false',
        );
        cy.get('.d3-build-graph-node-outline-5').should(
          'not.have.class',
          '-focus',
        );
        cy.get('[data-test=build-graph-action-filter]')
          .should('be.visible')
          .type('stage-a');
        cy.get('.elm-build-graph-node-5').should(
          'have.id',
          '#5,stage-a,killed,true',
        );
        cy.get('.d3-build-graph-node-outline-5').should('have.class', '-focus');
        // clear button
        cy.get('[data-test=build-graph-action-filter-clear]')
          .should('be.visible')
          .click({ force: true });
        cy.get('.d3-build-graph-node-outline-5').should(
          'not.have.class',
          '-focus',
        );
      });
      it('click on step row should redirect to step logs', () => {
        cy.location('pathname').should('eq', '/github/octocat/4/graph');
        cy.get('.d3-build-graph-node-step-a').first().click({ force: true });
        cy.location('pathname').should('eq', '/github/octocat/4');
        cy.hash().should('eq', '#5');
      });
      it('step should reflect build information', () => {
        cy.get('.d3-build-graph-node-step-a svg')
          .first()
          .should('have.class', '-killed');
        cy.get('.d3-build-graph-node-step-a svg')
          .last()
          .should('have.class', '-success');
      });
    },
  );
});
