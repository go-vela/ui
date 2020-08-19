/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */
context('visit Build with ansi encoded logs using url line fragment', () => {
  beforeEach(() => {
    cy.server();
    cy.stubBuild();
    cy.stubStepsWithANSILogs();
    cy.login('/someorg/somerepo/1');
    cy.get('[data-test=step-header-2]').click({ force: true });
    cy.get('[data-test=logs-1]').as('logs');
    cy.get('[data-test=step-header-2]').click({ force: true });
    cy.visit('/someorg/somerepo/1#step:2:31');
    cy.reload();
    cy.wait('@getLogs-2');
  });
  it('line should not contain ansi characters', () => {
    cy.get('[data-test=log-line-2-30]').within(() => {
      cy.get('[class=ansi-red-fg]').should('not.exist');
    });
  });
  it('line should contain ansi color css', () => {
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-green-fg]').should('exist');
      cy.get('[class=ansi-red-fg]').should('exist');
    });
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-bright-black-fg]').should('exist');
    });
  });
  it('ansi fg classes should change css color', () => {
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-green-fg]')
        .should('have.css', 'color')
        .should('eq', 'rgb(125, 209, 35)');
    });
    cy.get('[data-test=log-line-2-31]').within(() => {
      cy.get('[class=ansi-red-fg]')
        .should('have.css', 'color')
        .should('eq', 'rgb(235, 102, 117)');
    });
  });
  it('line should respect ansi font style', () => {
    cy.get('[data-test=log-line-2-46]').within(() => {
      cy.get('.ansi-bold').should('exist');
    });
  });
  it('build preview should have log actions', () => {
    cy.get('[data-test=1-log-actions]').should('exist');
  });
});
