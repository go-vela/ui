/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('My Settings', () => {
  beforeEach(() => {
    cy.login();
  });

  it('should show settings option in identity dropdown', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').should('exist').should('be.visible');
  });

  it('settings option should bring you to settings page', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();
    cy.location('pathname').should('eq', '/account/settings');
  });

  it('show auth token on page', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();
    cy.fixture('auth').then(auth => {
      cy.get('#token')
        .should('exist')
        .should('be.visible')
        .should('contain', auth.token);
    });
  });

  it('theme radio controls are present on settings page', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();

    cy.get('[data-test=radio-theme-light]')
      .should('exist')
      .should('be.visible');
    cy.get('[data-test=radio-theme-dark]').should('exist').should('be.visible');
    cy.get('[data-test=radio-theme-system]')
      .should('exist')
      .should('be.visible');
  });

  it('selecting Light updates localStorage and body class', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();

    cy.get('input[data-test=radio-theme-light]').click({ force: true });

    cy.window().then(win => {
      expect(win.localStorage.getItem('vela-theme')).to.equal('theme-light');
    });

    cy.get('body')
      .invoke('attr', 'class')
      .then(classes => {
        expect(classes).to.contain('theme-light');
      });
  });

  it('selecting Dark updates localStorage and body class', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();

    cy.get('input[data-test=radio-theme-dark]').click({ force: true });

    cy.window().then(win => {
      expect(win.localStorage.getItem('vela-theme')).to.equal('theme-dark');
    });

    cy.get('body')
      .invoke('attr', 'class')
      .then(classes => {
        expect(classes).to.contain('theme-dark');
      });
  });

  it('selecting System preference stores system choice and applies a concrete theme', () => {
    cy.get('[data-test=identity-summary]').click();
    cy.get('[data-test=settings-link]').click();

    cy.get('input[data-test=radio-theme-system]').click({ force: true });

    // user selection should be persisted as 'theme-system'
    cy.window().then(win => {
      expect(win.localStorage.getItem('vela-theme')).to.equal('theme-system');
    });

    // body should have either theme-light or theme-dark applied (resolved system preference)
    cy.get('body')
      .invoke('attr', 'class')
      .then(classes => {
        const hasLight = classes && classes.indexOf('theme-light') !== -1;
        const hasDark = classes && classes.indexOf('theme-dark') !== -1;
        expect(hasLight || hasDark).to.be.true;
      });
  });
});
