/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */
context('visit Build with log line with fragment', () => {
  beforeEach(() => {
    cy.server();
    cy.stubBuild();
    cy.stubStepsWithANSILogs();
    cy.login('/someorg/somerepo/1');
    cy.get('[data-test=steps]').as('steps');
    cy.get('[data-test=step]').as('step');
    cy.get('[data-test=step-header]').as('stepHeaders');
    cy.get('@stepHeaders').click({ force: true, multiple: true });
    cy.get('[data-test=logs-1]').as('logs');
    cy.get('@stepHeaders').click({ force: true, multiple: true });
    cy.visit('/someorg/somerepo/1#step:2:2');
    cy.reload();
  });
  it('line should be highlighted', () => {
    cy.wait('@getLogs-2');
    cy.get('[data-test=logs-2]').within(() => {
      cy.get('[data-test=log-line-2]').as('line2:2');
      cy.get('[data-test=log-line-num-2]').as('lineNumber2:2');
    });
    cy.get('@line2:2').should('have.class', '-focus');
  });
});
