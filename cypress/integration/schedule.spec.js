/*
 * Copyright (c) 2022 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Schedule', () => {
  context('server returning schedule', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/schedules/github/octocat/Daily',
        'fixture:schedule.json',
      );
      cy.login('/github/octocat/schedules/Daily');
    });
    it('Add Schedule should work as intended', () => {
      cy.get('[id=schedule-name]')
        .should('exist').should('have.value', 'Daily');
      cy.get('[id=schedule-entry]').should('exist').should('have.value', '0 0 * * *');
      cy.get('[data-test=schedule-update-button]').should('exist');
      cy.get('[data-test=schedule-delete-button]').should('exist');

    });
  });
});
