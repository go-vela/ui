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
  context('server returning error', () => {
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
    it('queue routes list should show', () => {
      cy.get('[data-test=editable-list-queue-routes]')
        .should('be.visible')
        .within(() => {
          cy.get('[data-test=editable-list-item-vela]').should(
            'contain',
            'vela',
          );
        });
    });

    context('form should allow editing', () => {
      beforeEach(() => {
        cy.route({
          method: 'PUT',
          url: '*api/v1/admin/settings*',
          status: 200,
          response: 'fixture:settings_updated.json',
        });
      });
      it('clone image should allow editing', () => {
        cy.get('[data-test=input-clone-image]')
          .should('be.visible')
          .clear()
          .type('target/vela-git:abc123');
        cy.get('[data-test=button-clone-image-update]').click();
        cy.get('[data-test=alert]').should('be.visible').contains('Success');
        cy.get('[data-test=input-clone-image]')
          .should('be.visible')
          .should('have.value', 'target/vela-git:abc123');
      });
      it('editing above or below a limit should disable button', () => {
        cy.get('[data-test=input-template-depth]')
          .should('be.visible')
          .clear()
          .type('999999');
        cy.get('[data-test=button-template-depth-update]').should(
          'be.disabled',
        );

        cy.get('[data-test=input-template-depth]')
          .should('be.visible')
          .type('0');
        cy.get('[data-test=button-template-depth-update]').should(
          'be.disabled',
        );
      });
      // context('list item should allow editing', () => {
      //   it('edit button should toggle save and remove buttons', () => {
      //     cy.get('[data-test=editable-list-queue-routes]')
      //       .should('be.visible')
      //       .within(() => {
      //         cy.get('[data-test=editable-list-item-vela-edit]').should(
      //           'be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-remove]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-edit]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=editable-list-item-vela-edit]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-remove]').should(
      //           'be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-save]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //       });
      //   });
      //   it('save button should skip non-edits', () => {
      //     cy.get('[data-test=editable-list-queue-routes]')
      //       .should('be.visible')
      //       .within(() => {
      //         cy.get('[data-test=editable-list-item-vela-edit]').should(
      //           'be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-edit]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         // no change edit
      //         cy.get('[data-test=editable-list-item-vela-save]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela]').should(
      //           'contain',
      //           'vela',
      //         );
      //         // empty string edit
      //         cy.get('[data-test=editable-list-item-vela-edit]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=input-editable-list-item-vela]').clear();
      //         cy.get('[data-test=editable-list-item-vela-save]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela]').should(
      //           'contain',
      //           'vela',
      //         );
      //         cy.get('[data-test=alert]').should('not.be.visible');
      //       });
      //   });
      //   it('save button should save edits', () => {
      //     cy.get('[data-test=editable-list-queue-routes]')
      //       .should('be.visible')
      //       .within(() => {
      //         cy.get('[data-test=editable-list-item-vela-edit]').should(
      //           'be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela-edit]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=input-editable-list-item-vela]')
      //           .clear()
      //           .type('vela123');
      //         cy.get('[data-test=editable-list-item-vela-save]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test=editable-list-item-vela-save]').should(
      //           'not.be.visible',
      //         );
      //         cy.get('[data-test=editable-list-item-vela123]').should(
      //           'contain',
      //           'vela123',
      //         );
      //       });
      //   });
      //   it('remove button should remove an item', () => {
      //     cy.get('[data-test=editable-list-schedule-allowlist]')
      //       .should('be.visible')
      //       .within(() => {
      //         cy.get('[data-test="editable-list-item-*-edit"]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test="editable-list-item-*-remove"]')
      //           .should('be.visible')
      //           .click({ force: true });
      //         cy.get('[data-test="editable-list-item-*"]').should(
      //           'not.be.visible',
      //         );
      //         cy.get(
      //           '[data-test=editable-list-schedule-allowlist-no-items]',
      //         ).should('be.visible');
      //       });
      //       cy.get('[data-test=alert]').should('be.visible').contains('Success');
      //   });
      //   it('* repo wildcard should show helpful text', () => {
      //     cy.get('[data-test=editable-list-schedule-allowlist]')
      //       .should('be.visible')
      //       .within(() => {
      //         cy.get('[data-test="editable-list-item-*"]').should(
      //           'contain',
      //           'all repos',
      //         );
      //       });
      //   });
      //   it('add item input header should add items', () => {
      //     cy.get('[data-test="editable-list-item-linux-large"]').should(
      //       'not.be.visible',
      //     );

      //     cy.get('[data-test=input-editable-list-queue-routes-add]')
      //       .clear()
      //       .type('linux-large');
      //     cy.get('[data-test=button-editable-list-queue-routes-add]')
      //       .should('be.visible')
      //       .click({ force: true });
      //     cy.get('[data-test="editable-list-item-linux-large"]').should(
      //       'be.visible',
      //     );
      //   });
      // });
    });
  });
});
