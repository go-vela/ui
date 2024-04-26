/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Admin Settings', () => {
  beforeEach(() => {
    cy.server();
    cy.route({
      method: 'GET',
      url: '*api/v1/user*',
      status: 200,
      response: 'fixture:user_admin.json',
    });
  });
  context('server returning bad repo', () => {
    beforeEach(() => {
      cy.route({
        method: 'GET',
        url: '*api/v1/admin/settings*',
        status: 500,
      });
      cy.loginAdmin('/admin/settings');
    });
    it('should show an error', () => {
      cy.get('[data-test=alert]').should('be.visible').contains('Error');
    });
  });
  context('server returning settings', () => {
    beforeEach(() => {
      cy.route({
        method: 'GET',
        url: '*api/v1/admin/settings*',
        status: 200,
        response: 'fixture:settings.json',
      });
      cy.loginAdmin('/admin/settings');
    });
    it('compiler clone image should show', () => {
      cy.get('[data-test=input-clone-image]').should('be.visible');
    });
    it('compiler template depth should show', () => {
      cy.get('[data-test=input-template-depth]').should('be.visible');
    });
    it('compiler starlark exec limit should show', () => {
      cy.get('[data-test=input-starlark-exec-limit]').should('be.visible');
    });

    // todo: test for modifying queue routes using the editable list
    // todo: read
    // todo: empty
    // todo: add
    // todo: modify
    // todo: modify submit no change
    // todo: modify submit empty string
    // todo: remove

    // todo: test for modifying above limits
  });
});
