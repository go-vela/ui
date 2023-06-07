/*
 * Copyright (c) 2022 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Schedules', () => {
  context('server returning schedules', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/schedules/github/octocat',
        'fixture:schedules.json',
      );
      cy.login('/github/octocat/schedules');
    });

    it('Add Schedule button should exist', () => {
      cy.get('[data-test=add-repo-schedule]')
        .should('exist')
        .contains('Add');
    });
    it('schedules table should show 2 rows', () => {
      cy.get('[data-test=schedules-row]').should('have.length', 2);
    });
  });
});
