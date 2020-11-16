/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Pipeline', () => {
  context('logged in and server returning pipeline error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubPipelineErrors();
      cy.login('/someorg/somerepo/pipeline');
    });
    it('error alert should show', () => {
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });
  });
});
