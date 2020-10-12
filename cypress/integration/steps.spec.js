/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Steps', () => {
  context('logged in and server returning builds, steps, and logs', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithLogsAndSkipped();
      cy.login('/someorg/somerepo/1');
      cy.get('[data-test=steps]').as('steps');
      cy.get('[data-test=step]').as('step');
      cy.clickSteps();
      cy.get('[data-test=logs-1]').as('logs');
      cy.clickSteps();
    });

    it('steps should show', () => {
      cy.get('@steps').should('be.visible');
    });

    it('5 steps should show', () => {
      cy.get('@steps').children().should('have.length', 5);
    });

    it('steps should be in order by number', () => {
      cy.get('@steps').children().first().should('contain', 'clone');

      cy.get('@steps').children().last().should('contain', 'echo');
    });

    it('First 4 steps should have logs', () => {
      cy.get('[data-test=logs-1]').should('exist').contains('$');
      cy.get('[data-test=logs-2]').should('exist').contains('$');
      cy.get('[data-test=logs-3]').should('exist').contains('$');
      cy.get('[data-test=logs-4]').should('exist').contains('$');
      cy.get('[data-test=logs-5]').should('not.exist');
      cy.get('[data-test=logs-6]').should('not.exist');
    });

    it('logs should be base64 decoded', () => {
      // all test logs have a '$' encoded in the source
      cy.get('@logs').children().should('contain', '$');
    });

    it('logs should be hidden', () => {
      cy.get('@logs').children().should('be.not.visible');
    });
    context('click steps', () => {
      beforeEach(() => {
        cy.clickSteps();
      });

      it('should show logs', () => {
        cy.get('@logs').children().should('be.visible');
      });

      context('click steps again', () => {
        beforeEach(() => {
          cy.clickSteps();
        });

        it('should hide logs', () => {
          cy.get('@logs').children().should('be.not.visible');
        });
      });
    });
    context('click first step', () => {
      beforeEach(() => {
        cy.get('[data-test=step-header-1]').click({ force: true });
      });
      it('browser path should contain first step fragment', () => {
        cy.hash().should('eq', '#step:1');
      });
      context('click last step', () => {
        beforeEach(() => {
          cy.get('[data-test=step-header-5]').click({ force: true });
        });
        it('browser path should contain last step fragment', () => {
          cy.hash().should('eq', '#step:5');
        });
      });
    });
    context('click log line in last step', () => {
      beforeEach(() => {
        cy.get('[data-test=step-header-5]').click({ force: true });
        cy.get('[data-test=step-skipped]').as('lineNumber');
        cy.get('@lineNumber').click({ force: true });
      });
      context('click first step', () => {
        beforeEach(() => {
          cy.get('[data-test=step-header-1]').click({ force: true });
        });
        it('browser path should contain first step fragment', () => {
          cy.hash().should('eq', '#step:1');
        });
      });
    });
    context('click log line number', () => {
      beforeEach(() => {
        cy.clickSteps();
        cy.wait('@getLogs-1');
        cy.get('[data-test=log-line-1-3]').as('line');
        cy.get('[data-test=log-line-num-1-3]').as('lineNumber');
        cy.get('@lineNumber').click({ force: true });
      });

      it('line should be highlighted', () => {
        cy.clickSteps();
        cy.get('@lineNumber').click({ force: true });
        cy.get('@line').should('have.class', '-focus');
      });

      it('browser path should contain step and line fragment', () => {
        cy.hash().should('eq', '#step:1:3');
      });

      context('click other log line number', () => {
        beforeEach(() => {
          cy.get('[data-test=log-line-3-2]').as('otherLine');
          cy.get('[data-test=log-line-num-3-2]').as('otherLineNumber');
          cy.get('@otherLineNumber').click({ force: true });
        });
        it('original line should not be highlighted', () => {
          cy.get('@line').should('not.have.class', '-focus');
        });

        it('other line should be highlighted', () => {
          cy.get('@otherLineNumber').click({ force: true });
          cy.get('@otherLine').should('have.class', '-focus');
        });

        it('browser path should contain other step and line fragment', () => {
          cy.clickSteps();
          cy.hash().should('eq', '#step:3:2');
        });

        it('browser path should contain other step and line fragment', () => {
          cy.get('@otherLineNumber').click({ force: true });
          cy.hash().should('eq', '#step:3:2');
        });
      });
    });
    context('visit Build, then visit log line with fragment', () => {
      beforeEach(() => {
        cy.visit('/someorg/somerepo/1');
        cy.visit('/someorg/somerepo/1#step:2:2');
        cy.reload();
      });
      it('line should be highlighted', () => {
        cy.wait('@getLogs-2');
        cy.get('[data-test=log-line-2-2]').as('line2:2');
        cy.get('[data-test=log-line-num-2-2]').as('lineNumber2:2');
        cy.get('@line2:2').should('have.class', '-focus');
      });
    });
    context('visit Build, with only step fragment', () => {
      beforeEach(() => {
        cy.visit('/someorg/somerepo/1');
        cy.visit('/someorg/somerepo/1#step:2');
        cy.reload();
      });
      it('range start line should not be highlighted', () => {
        cy.wait('@getLogs-2');
        cy.get('[data-test=log-line-2-2]').as('line2:2');
        cy.get('@line2:2').should('not.have.class', '-focus');
      });
      context('click line 2, shift click line 5', () => {
        beforeEach(() => {
          cy.wait('@getLogs-2');
          cy.get('[data-test=log-line-2-2]').as('line2:2');
          cy.get('[data-test=log-line-2-5]').as('line2:5');
          cy.get('[data-test=log-line-num-2-2]').as('lineNumber2:2');
          cy.get('[data-test=log-line-num-2-5]').as('lineNumber2:5');
          cy.get('@lineNumber2:2')
            .type('{shift}', { release: false })
            .get('@lineNumber2:2')
            .click({ force: true });
          cy.get('@lineNumber2:5').type('{shift}', { release: true });
        });
        it('range start line should be highlighted', () => {
          cy.wait('@getLogs-2');
          cy.get('[data-test=log-line-2-2]').should('have.class', '-focus');
        });
        it('lines between range start and end should be highlighted', () => {
          cy.wait('@getLogs-2');
          cy.get('[data-test=log-line-2-3]').should('have.class', '-focus');
          cy.get('[data-test=log-line-2-4]').should('have.class', '-focus');
        });
      });
      context('click first step', () => {
        beforeEach(() => {
          cy.get('[data-test=step-header-1]').click({ force: true });
        });
        it('browser path should contain first step fragment', () => {
          cy.hash().should('eq', '#step:1');
        });
      });
    });
    context('visit Build, then visit log line range with fragment', () => {
      beforeEach(() => {
        cy.visit('/someorg/somerepo/1');
        cy.visit('/someorg/somerepo/1#step:2:2:5');
        cy.reload();
        cy.wait('@getLogs-2');
      });
      it('range start line should be highlighted', () => {
        cy.get('[data-test=log-line-2-2]').should('have.class', '-focus');
      });
      it('range end line should be highlighted', () => {
        cy.get('[data-test=log-line-2-5]').should('have.class', '-focus');
      });
      it('lines between range start and end should be highlighted', () => {
        cy.get('[data-test=log-line-2-3]').should('have.class', '-focus');
        cy.get('[data-test=log-line-2-4]').should('have.class', '-focus');
      });
      context('click first step', () => {
        beforeEach(() => {
          cy.get('[data-test=step-header-1]').click({ force: true });
        });
        it('browser path should contain first step fragment', () => {
          cy.hash().should('eq', '#step:1');
        });
      });
    });
    context(
      'visit Build, click log line, then visit log line with fragment',
      () => {
        beforeEach(() => {
          cy.visit('/someorg/somerepo/1');
          cy.clickSteps();
          cy.get('[data-test=log-line-2-2]').as('line2:2');
          cy.get('[data-test=log-line-num-2-2]').as('lineNumber2:2');
          cy.get('[data-test=log-line-3-3]').as('line3:3');
          cy.get('[data-test=log-line-num-3-3]').as('lineNumber3:3');
          cy.get('@lineNumber3:3').click({ force: true });
          cy.visit('/someorg/somerepo/1#step:2:2');
          cy.reload();
        });
        it('original line should not be highlighted', () => {
          cy.get('@line3:3').should('not.have.class', '-focus');
        });
        it('other line should be highlighted', () => {
          cy.get('@line2:2').should('have.class', '-focus');
        });
        context('click first step', () => {
          beforeEach(() => {
            cy.get('[data-test=step-header-1]').click({ force: true });
          });
          it('browser path should contain first step fragment', () => {
            cy.hash().should('eq', '#step:1');
          });

          it('last step should contain killed/skip', () => {
            cy.get('[data-test=step]').last().as('killStep');
            cy.get('@killStep').should('be.visible').click();
            cy.get('@killStep').contains('step was skipped');
          });
        });
      },
    );
  });

  context('visit build/steps with server error', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubStepsWithErrorLogs();
      cy.login('/someorg/somerepo/5');

      // load logs
      cy.clickSteps();
      cy.clickSteps();
      cy.get('[data-test=full-build]').as('build');
      cy.get('@build').get('[data-test=build-status]').as('buildStatus');
    });

    it('build should have error style', () => {
      cy.get('@buildStatus').should('have.class', '-error');
    });

    it('build error should show', () => {
      cy.get('[data-test=build-error]').should('be.visible');
    });

    it('build error should contain error', () => {
      cy.get('[data-test=build-error]').contains('error:');
      cy.get('[data-test=build-error]').contains('failure authenticating');
    });

    it('first step should contain error', () => {
      cy.get('[data-test=step]').first().as('cloneStep');
      cy.get('@cloneStep').should('be.visible').click();
      cy.get('@cloneStep').contains('error:');
      cy.get('@cloneStep').contains('problem starting container');
    });

    it('last step should not contain killed/skipped', () => {
      cy.get('[data-test=step]').last().as('echoStep');
      cy.get('@echoStep').should('be.visible').click({ force: true });
      cy.get('@echoStep').should('not.contain', 'error:');
      cy.get('@echoStep').should('not.contain', 'step was killed');
      cy.get('@echoStep').contains('$');
    });
  });

  context('visit build/steps with stages', () => {
    beforeEach(() => {
      cy.server();
      cy.fixture('steps_stages.json').as('steps');
      cy.route({
        method: 'GET',
        url: 'api/v1/repos/*/*/builds/*/steps*',
        status: 200,
        response: '@steps',
      });
      cy.login('/someorg/somerepo/5');
    });

    it('build should contain stages', () => {
      cy.get('[data-test=stage]').should('have.length', 4);
    });

    it('stages should contain stage names go and deploy', () => {
      cy.get('[data-test=stage]').should('contain', 'go');
      cy.get('[data-test=stage-divider-go]').should('contain', 'go');

      cy.get('[data-test=stage]').should('contain', 'deploy');
      cy.get('[data-test=stage-divider-deploy]').should('contain', 'deploy');
    });

    it('init/clone stages should not contain stage dividers', () => {
      cy.get('[data-test=stage-divider-init]').should('not.contain', 'init');
      cy.get('[data-test=stage-divider-clone]').should('not.contain', 'clone');
    });

    it('stages should contain grouped steps', () => {
      cy.get('[data-test=stage-go] .step').should('have.length', 2);
      cy.get('[data-test=stage-go] .step').should('contain', 'build');
      cy.get('[data-test=stage-go] .step').should('contain', 'test');

      cy.get('[data-test=stage-deploy] .step').should('have.length', 3);
      cy.get('[data-test=stage-deploy] .step').should(
        'contain',
        'docker-build',
      );
      cy.get('[data-test=stage-deploy] .step').should(
        'contain',
        'docker-publish',
      );
      cy.get('[data-test=stage-deploy] .step').should('contain', 'docker-tag');
    });
  });
});
