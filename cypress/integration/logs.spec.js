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
        cy.get('[data-test=steps]').as('steps');
        cy.get('[data-test=step]').as('step');
        cy.get('[data-test=step-header]').as('stepHeaders');
        cy.get('@stepHeaders').click({ force: true, multiple: true });
        cy.get('[data-test=logs-1]').as('logs');
        cy.get('@stepHeaders').click({ force: true, multiple: true });
        cy.visit('/someorg/somerepo/1#step:2:31');
        cy.reload();
    });
    it('line should be highlighted', () => {
        cy.wait('@getLogs-2');
        cy.get('[data-test=log-line-2-31]').as('line2:31');
        cy.get('@line2:31').should('have.class', '-focus');
    });
    it('line should not contain ansi characters', () => {
        cy.wait('@getLogs-2');
    });
    it('line should contain ansi css', () => {
        cy.wait('@getLogs-2');
        cy.get('[class=ansi-red-fg]').as('red');
        cy.get('@red').should('exist');
    });
    it('line should respect ansi spacing', () => {
        cy.wait('@getLogs-2');
        cy.get('[class=ansi-red-fg]').as('red');
        cy.get('@red').should('exist');
    });
});
