/*
 * Copyright (c) 2022 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Repo Settings', () => {
  context('server returning bad repo', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'PUT',
        '*api/v1/repos/*/octocat',
        'fixture:repository_updated.json',
      );
      cy.route(
        'GET',
        '*api/v1/repos/*/octocatbad',
        'fixture:repository_bad.json',
      );
      cy.login('/github/octocatbad/settings');
    });

    it('should show an error', () => {
      cy.get('[data-test=alert]').should('be.visible').contains('Error');
    });
  });
  context('server returning repo', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'PUT',
        '*api/v1/repos/*/octocat',
        'fixture:repository_updated.json',
      );
      cy.route('GET', '*api/v1/repos/*/octocat', 'fixture:repository.json');
      cy.login('/github/octocat/settings');
    });

    it('build limit input should show', () => {
      cy.get('[data-test=repo-limit]').should('be.visible');
    });

    it('build timeout input should show', () => {
      cy.get('[data-test=repo-timeout]').should('be.visible');
    });

    it('build counter input should show', () => {
      cy.get('[data-test=repo-counter]').should('be.visible');
    });

    it('webhook event category should show', () => {
      cy.get('[data-test=repo-settings-events]').should('be.visible');
    });

    it('allow_push checkbox should show', () => {
      cy.get('[data-test=repo-checkbox-allow_push]').should('be.visible');
    });

    it('clicking allow_push checkbox should toggle the value', () => {
      cy.get('[data-test=repo-checkbox-allow_push] input').as(
        'allowPushCheckbox',
      );
      cy.get('@allowPushCheckbox').should('have.checked');
      cy.get('@allowPushCheckbox').click({ force: true });
      cy.get('@allowPushCheckbox').should('not.have.checked');
    });

    it('clicking access radio should toggle both values', () => {
      cy.get('[data-test=repo-radio-private] input').as('accessRadio');
      cy.get('@accessRadio').should('not.have.checked');
      cy.get('@accessRadio').click({ force: true });
      cy.get('@accessRadio').should('have.checked');
    });

    it('clicking pipeline type radio should toggle all values', () => {
      cy.get('[data-test=repo-radio-private] input').as('pipelineTypeRadio');
      cy.get('@pipelineTypeRadio').should('not.have.checked');
      cy.get('@pipelineTypeRadio').click({ force: true });
      cy.get('@pipelineTypeRadio').should('have.checked');
    });

    it('build limit input should allow number input', () => {
      cy.get('[data-test=repo-limit]').as('repoLimit');
      cy.get('[data-test=repo-limit] input').as('repoLimitInput');
      cy.get('@repoLimitInput').should('be.visible').type('{selectall}123');
      cy.get('@repoLimitInput').should('have.value', '123');
    });

    it('build limit input should not allow letter/character input', () => {
      cy.get('[data-test=repo-limit]').as('repoLimit');
      cy.get('[data-test=repo-limit] input').as('repoLimitInput');
      cy.get('@repoLimitInput').should('be.visible').type('{selectall}cat');
      cy.get('@repoLimitInput').should('not.have.value', 'cat');
      cy.get('@repoLimitInput').type('{selectall}12cat34');
      cy.get('@repoLimitInput').should('have.value', '1234');
    });

    it('clicking update on build limit should update limit and hide button', () => {
      cy.get('[data-test=repo-limit]').as('repoLimit');
      cy.get('[data-test=repo-limit] input').as('repoLimitInput');
      cy.get('@repoLimitInput').should('be.visible').clear();
      cy.get('@repoLimitInput').type('{selectall}80');
      cy.get('[data-test=repo-limit] + button')
        .should('be.visible')
        .click({ force: true });
      cy.get('[data-test=repo-limit] + button').should('be.disabled');
    });

    it('build timeout input should allow number input', () => {
      cy.get('[data-test=repo-timeout]').as('repoTimeout');
      cy.get('[data-test=repo-timeout] input').as('repoTimeoutInput');
      cy.get('@repoTimeoutInput').should('be.visible').type('{selectall}123');
      cy.get('@repoTimeoutInput').should('have.value', '123');
    });

    it('build timeout input should not allow letter/character input', () => {
      cy.get('[data-test=repo-timeout]').as('repoTimeout');
      cy.get('[data-test=repo-timeout] input').as('repoTimeoutInput');
      cy.get('@repoTimeoutInput').should('be.visible').type('{selectall}cat');
      cy.get('@repoTimeoutInput').should('not.have.value', 'cat');
      cy.get('@repoTimeoutInput').type('{selectall}12cat34');
      cy.get('@repoTimeoutInput').should('have.value', '1234');
    });

    it('clicking update on build timeout should update timeout and hide button', () => {
      cy.get('[data-test=repo-timeout]').as('repoTimeout');
      cy.get('[data-test=repo-timeout] input').as('repoTimeoutInput');
      cy.get('@repoTimeoutInput').should('be.visible').clear();
      cy.get('@repoTimeoutInput').type('{selectall}91');
      cy.get('[data-test=repo-timeout] + button')
        .should('be.visible')
        .click({ force: true });
      cy.get('[data-test=repo-timeout] + button').should('be.disabled');
    });

    it('build counter input should allow number input', () => {
      cy.get('[data-test=repo-counter]').as('repoCounter');
      cy.get('[data-test=repo-counter] input').as('repoCounterInput');
      cy.get('@repoCounterInput').should('be.visible').type('{selectall}123');
      cy.get('@repoCounterInput').should('have.value', '123');
    });

    it('build counter input should not allow letter/character input', () => {
      cy.get('[data-test=repo-counter]').as('repoCounter');
      cy.get('[data-test=repo-counter] input').as('repoCounterInput');
      cy.get('@repoCounterInput').should('be.visible').type('{selectall}cat');
      cy.get('@repoCounterInput').should('not.have.value', 'cat');
      cy.get('@repoCounterInput').type('{selectall}12cat34');
      cy.get('@repoCounterInput').should('have.value', '1234');
    });

    it('clicking update on build counter should update counter and hide button', () => {
      cy.get('[data-test=repo-counter]').as('repoCounter');
      cy.get('[data-test=repo-counter] input').as('repoCounterInput');
      cy.get('@repoCounterInput').should('be.visible').clear();
      cy.get('@repoCounterInput').type('{selectall}80');
      cy.get('[data-test=repo-counter] + button')
        .should('be.visible')
        .click({ force: true });
      cy.get('[data-test=repo-counter] + button').should('be.disabled');
    });

    it('Disable button should exist', () => {
      cy.get('[data-test=repo-disable]').should('exist').should('be.visible');
    });

    it('clicking button should prompt disable confirmation', () => {
      cy.route({
        method: 'DELETE',
        url: '*api/v1/repos/CookieCat/**',
        response: `"Repo CookieCat/applications deleted"`,
      });
      cy.get('[data-test=repo-disable]').first().click({ force: true });
      cy.get('[data-test=repo-disable]').should('contain', 'Really Disable?');
    });

    it('clicking button twice should disable the repo', () => {
      cy.route({
        method: 'DELETE',
        url: '*api/v1/repos/CookieCat/**',
        response: `"Repo CookieCat/applications deleted"`,
      });
      cy.get('[data-test=repo-disable]')
        .first()
        .click({ force: true })
        .click({ force: true });
      cy.get('[data-test=repo-disabling]').should('contain', 'Disabling');
    });

    it('clicking button three times should re-enable the repo', () => {
      cy.route({
        method: 'DELETE',
        url: '*api/v1/repos/github/**',
        response: `"Repo github/octocat deleted"`,
      }).as('disable');
      cy.route(
        'POST',
        '*api/v1/repos*',
        'fixture:enable_repo_response.json',
      ).as('enable');
      cy.get('[data-test=repo-disable]')
        .first()
        .click({ force: true })
        .click({ force: true });
      cy.wait('@disable');
      cy.get('[data-test=repo-enable]').first().click({ force: true });
      cy.wait('@enable');
      cy.get('[data-test=repo-disable]').should('contain', 'Disable');
    });

    it('should show an success alert on successful removal of a repo', () => {
      cy.route({
        method: 'DELETE',
        url: '*api/v1/repos/github/**',
        response: `"Repo github/octocat deleted"`,
      });
      cy.get('[data-test=repo-disable]')
        .first()
        .click({ force: true })
        .click({ force: true });
      cy.get('[data-test=alerts]').as('alert');
      cy.get('@alert').should('exist');
      cy.get('@alert').contains('Success');
    });

    it('should copy markdown to clipboard and alert', () => {
      let clipboardContent;
      cy.get('[data-test=copy-md]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Copied');
    });

    it('Chown button should exist', () => {
      cy.get('[data-test=repo-chown]').should('exist').should('be.visible');
    });

    it('should show an success alert on successful chown of a repo', () => {
      cy.route({
        method: 'PATCH',
        url: '*api/v1/repos/github/**',
        response: '"Repo github/octocat changed owner"',
      });
      cy.get('[data-test=repo-chown]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Success');
    });

    it('should show an error alert on failed chown of a repo', () => {
      cy.route({
        method: 'PATCH',
        url: '*api/v1/repos/github/**',
        status: 500,
        response: '"Unable to..."',
      });
      cy.get('[data-test=repo-chown]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Error');
    });

    it('Repair button should exist', () => {
      cy.get('[data-test=repo-repair]').should('exist').should('be.visible');
    });

    it('should show an success alert on successful repair of a repo', () => {
      cy.route({
        method: 'PATCH',
        url: '*api/v1/repos/github/**',
        response: '"Repo github/octocat repaired."',
      });
      cy.get('[data-test=repo-repair]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Success');
      cy.get('[data-test=repo-disable]').should('exist').contains('Disable');
    });

    it('should show an error alert on a failed repair of a repo', () => {
      cy.route({
        method: 'PATCH',
        url: '*api/v1/repos/github/**',
        status: 500,
        response: '"Unable to..."',
      });
      cy.get('[data-test=repo-repair]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Error');
      cy.get('[data-test=repo-disable]').should('exist').contains('Disable');
    });
  });

  context('server returning inactive repo', () => {
    beforeEach(() => {
      cy.server();
      cy.route(
        'GET',
        '*api/v1/repos/*/octocat',
        'fixture:repository_inactive.json',
      );
      cy.login('/github/octocat/settings');
    });

    it('should show enable button', () => {
      cy.get('[data-test=repo-enable]').should('exist').contains('Enable');
    });

    it('successful repair enables disable button', () => {
      cy.route({
        method: 'PATCH',
        url: '*api/v1/repos/github/**',
        response: '"Repo github/octocat repaired."',
      });
      cy.get('[data-test=repo-repair]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Success');
      cy.get('[data-test=repo-disable').should('exist').contains('Disable');
    });

    it('failed repair keeps enable button enabled', () => {
      cy.route({
        method: 'PATCH',
        url: '*api/v1/repos/github/**',
        status: 500,
        response: '"Unable to..."',
      });
      cy.get('[data-test=repo-repair]').click();
      cy.get('[data-test=alerts]').should('exist').contains('Error');
      cy.get('[data-test=repo-enable').should('exist').contains('Enable');
    });
  });
});
