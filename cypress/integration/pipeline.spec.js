/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Pipeline', () => {
  context(
    'logged in and server returning pipeline configuration and templates errors',
    () => {
      beforeEach(() => {
        cy.server();
        cy.stubBuild();
        cy.stubPipelineErrors();
        cy.stubPipelineTemplatesErrors();
        cy.login('/github/octocat/1/pipeline');
      });
      it('pipeline configuration error should show', () => {
        cy.get('[data-test=pipeline-configuration-error]').should('be.visible');
        cy.get('[data-test=pipeline-configuration-data]').should(
          'not.be.visible',
        );
      });

      it('pipeline templates error should show', () => {
        cy.get('[data-test=pipeline-templates-error]').should('be.visible');
        cy.get('[data-test=pipeline-templates-error]').should('contain', '500');
      });
      it('error alert should show', () => {
        cy.get('[data-test=alerts]').should('exist').contains('Error');
      });
    },
  );
  context('logged in and server returning empty pipeline templates', () => {
    beforeEach(() => {
      cy.server();
      cy.stubBuild();
      cy.stubPipeline();
      cy.stubPipelineTemplatesEmpty();
      cy.login('/github/octocat/1/pipeline');
    });
    it('templates should not show', () => {
      cy.get('[data-test=pipeline-templates]').should('not.be.visible');
    });

    it('expand pipeline should be visible', () => {
      cy.get('[data-test=pipeline-expand]').should('be.visible');
    });

    it('pipeline configuration data should show', () => {
      cy.get('[data-test=pipeline-configuration-data]').should('be.visible');
      cy.get('[data-test=pipeline-configuration-data]').should(
        'contain',
        'version',
      );
    });
  });
  context(
    'logged in and server returning valid pipeline configuration and templates',
    () => {
      beforeEach(() => {
        cy.server();
        cy.stubBuild();
        cy.stubPipeline();
        cy.stubPipelineExpand();
        cy.stubPipelineTemplates();
        cy.login('/github/octocat/1/pipeline');
      });

      it('should show 3 templates', () => {
        cy.get('[data-test=pipeline-templates] > div')
          .children()
          .should('have.length', 3);
      });

      it('template1 should show name, source and link', () => {
        cy.get('[data-test=pipeline-template-template1_name]').should(
          'contain',
          'template1_name',
        );
        cy.get('[data-test=pipeline-template-template1_name]').should(
          'contain',
          'github.com/github/octocat/template1.yml',
        );
        cy.get('[data-test=pipeline-template-template1_name]').should(
          'contain',
          'https://github.com/github/octocat/blob/main/template1.yml',
        );
      });

      it('expand templates should be visible', () => {
        cy.get('[data-test=pipeline-expand]').should('exist');
      });

      context('click expand templates', () => {
        beforeEach(() => {
          cy.get('[data-test=pipeline-expand-toggle]').click({
            force: true,
          });
        });

        it('should update path with expand query', () => {
          cy.location().should(loc => {
            expect(loc.search).to.eq('?expand=true');
          });
        });

        it('should show revert expansion button', () => {
          cy.get('[data-test=pipeline-expand-toggle]').contains('revert');
        });

        it('pipeline configuration data should show', () => {
          cy.get('[data-test=pipeline-configuration-data]').should(
            'be.visible',
          );
          cy.get('[data-test=pipeline-configuration-data]').should(
            'contain',
            'version',
          );
        });

        it('pipeline configuration data should contain expanded steps', () => {
          cy.get('[data-test=pipeline-configuration-data]').should(
            'contain',
            'commands:',
          );
        });

        context('click line number', () => {
          beforeEach(() => {
            cy.get('[data-test=config-line-num-0-2]').click({ force: true });
          });

          it('should update path with line num', () => {
            cy.hash().should('eq', '#config:0:2');
          });

          it('other lines should not have focus style', () => {
            cy.get('[data-test=config-line-0-3]').should(
              'not.have.class',
              '-focus',
            );
          });

          it('should set focus style on single line', () => {
            cy.get('[data-test=config-line-0-2]').should(
              'have.class',
              '-focus',
            );
          });
        });

        context('click line number, then shift click other line number', () => {
          beforeEach(() => {
            cy.get('[data-test=config-line-num-0-2]')
              .type('{shift}', { release: false })
              .get('[data-test=config-line-num-0-5]')
              .click({ force: true });
          });

          it('should update path with range', () => {
            cy.hash().should('eq', '#config:0:2:5');
          });

          it('lines outside the range should not have focus style', () => {
            cy.get('[data-test=config-line-0-6]').should(
              'not.have.class',
              '-focus',
            );
          });

          it('lines within the range should have focus style', () => {
            cy.get('[data-test=config-line-0-2]').should(
              'have.class',
              '-focus',
            );
            cy.get('[data-test=config-line-0-3]').should(
              'have.class',
              '-focus',
            );
            cy.get('[data-test=config-line-0-4]').should(
              'have.class',
              '-focus',
            );
          });
        });
      });

      it('pipeline configuration data should show', () => {
        cy.get('[data-test=pipeline-configuration-data]').should('be.visible');
        cy.get('[data-test=pipeline-configuration-data]').should(
          'contain',
          'version',
        );
      });

      it('pipeline configuration data should respect yaml spacing', () => {
        cy.get('[data-test=config-line-0-1]').should('contain', 'version:');
        cy.get('[data-test=config-line-0-2]').should('contain', 'steps:');
      });

      context('click line number', () => {
        beforeEach(() => {
          cy.get('[data-test=config-line-num-0-2]').click({ force: true });
        });

        it('should update path with line num', () => {
          cy.hash().should('eq', '#config:0:2');
        });

        it('other lines should not have focus style', () => {
          cy.get('[data-test=config-line-0-3]').should(
            'not.have.class',
            '-focus',
          );
        });

        it('should set focus style on single line', () => {
          cy.get('[data-test=config-line-0-2]').should('have.class', '-focus');
        });
      });

      context('click line number, then shift click other line number', () => {
        beforeEach(() => {
          cy.get('[data-test=config-line-num-0-2]')
            .type('{shift}', { release: false })
            .get('[data-test=config-line-num-0-5]')
            .click({ force: true });
        });

        it('should update path with range', () => {
          cy.hash().should('eq', '#config:0:2:5');
        });

        it('lines outside the range should not have focus style', () => {
          cy.get('[data-test=config-line-0-6]').should(
            'not.have.class',
            '-focus',
          );
        });

        it('lines within the range should have focus style', () => {
          cy.get('[data-test=config-line-0-2]').should('have.class', '-focus');
          cy.get('[data-test=config-line-0-3]').should('have.class', '-focus');
          cy.get('[data-test=config-line-0-4]').should('have.class', '-focus');
        });
      });
    },
  );
  context(
    'logged in and server returning valid pipeline configuration and templates with expansion errors',
    () => {
      beforeEach(() => {
        cy.server();
        cy.stubBuild();
        cy.stubPipeline();
        cy.stubPipelineExpandErrors();
        cy.stubPipelineTemplates();
        cy.login('/github/octocat/1/pipeline');
      });

      it('should show 3 templates', () => {
        cy.get('[data-test=pipeline-templates] > div')
          .children()
          .should('have.length', 3);
      });

      it('should show pipeline configuration data', () => {
        cy.get('[data-test=pipeline-configuration-data]')
          .children()
          .should('be.visible');
      });
      context('click expand pipeline', () => {
        beforeEach(() => {
          cy.get('[data-test=pipeline-expand-toggle]').click({
            force: true,
          });
        });

        it('should update path with expand query', () => {
          cy.location().should(loc => {
            expect(loc.search).to.eq('?expand=true');
          });
        });

        it('error alert should show', () => {
          cy.get('[data-test=alerts]').should('exist').contains('Error');
        });

        it('should show pipeline configuration error', () => {
          cy.get('[data-test=pipeline-configuration-error]').should(
            'be.visible',
          );
          cy.get('[data-test=pipeline-configuration-data]').should(
            'not.be.visible',
          );
        });

        context('click expand pipeline again', () => {
          beforeEach(() => {
            cy.get('[data-test=pipeline-expand-toggle]').click({
              force: true,
            });
          });
          it('should revert to valid pipeline configuration', () => {
            cy.get('[data-test=pipeline-configuration-error]').should(
              'not.be.visible',
            );
            cy.get('[data-test=pipeline-configuration-data]').should(
              'be.visible',
            );
          });
        });
      });
    },
  );
});
