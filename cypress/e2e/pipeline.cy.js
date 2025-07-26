/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Pipeline', () => {
  context(
    'logged in and server returning pipeline configuration error and templates errors',
    () => {
      beforeEach(() => {
        cy.stubBuild();
        cy.stubPipelineErrors();
        cy.stubPipelineTemplatesErrors();
        cy.login('/github/octocat/1/pipeline');
      });
      it('pipeline configuration error should show', () => {
        cy.wait(2000); // Wait for pipeline data to load
        cy.get('[data-test=pipeline-configuration-error]').should('be.visible');
        cy.get('[data-test=pipeline-configuration-data]').should('not.exist');
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
      cy.stubBuild();
      cy.stubPipeline();
      cy.stubPipelineTemplatesEmpty();
      cy.login('/github/octocat/1/pipeline');
    });
    it('templates should not show', () => {
      cy.wait(1000); // Wait for templates to load
      cy.get('[data-test=pipeline-templates]').should('not.exist');
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

      it('warnings should not be visible', () => {
        cy.wait(1000); // Wait for warnings check
        cy.get('[data-test=pipeline-warnings]').should('not.exist');
      });

      context('click expand templates', () => {
        beforeEach(() => {
          cy.get('[data-test=pipeline-expand-toggle]').click({
            force: true,
          });
          cy.wait('@expand');
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

        context('click line number', () => {
          beforeEach(() => {
            cy.get('[data-test=config-line-num-2]').click({ force: true });
          });

          it('should update path with line num', () => {
            cy.hash().should('eq', '#2');
          });

          it('other lines should not have focus style', () => {
            cy.get('[data-test=config-line-3]').should(
              'not.have.class',
              '-focus',
            );
          });

          it('should set focus style on single line', () => {
            cy.get('[data-test=config-line-2]').should('have.class', '-focus');
          });
        });

        context('click line number, then shift click other line number', () => {
          beforeEach(() => {
            cy.get('[data-test=config-line-num-2]').click({ force: true });
            cy.get('[data-test=config-line-num-5]').click({
              force: true,
              shiftKey: true,
            });
            cy.wait(500); // Wait for range selection to process
          });

          it('should update path with range', () => {
            cy.hash().should('eq', '#2:5');
          });

          it('lines outside the range should not have focus style', () => {
            cy.get('[data-test=config-line-6]').should(
              'not.have.class',
              '-focus',
            );
          });

          it('lines within the range should have focus style', () => {
            cy.wait(500); // Wait for focus styles to apply
            cy.get('[data-test=config-line-2]').should('have.class', '-focus');
            cy.get('[data-test=config-line-3]').should('have.class', '-focus');
            cy.get('[data-test=config-line-4]').should('have.class', '-focus');
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
        cy.get('[data-test=config-line-1]').should('contain', 'version:');
        cy.get('[data-test=config-line-2]').should('contain', 'steps:');
      });

      context('click line number', () => {
        beforeEach(() => {
          cy.get('[data-test=config-line-num-2]').click({ force: true });
        });

        it('should update path with line num', () => {
          cy.hash().should('eq', '#2');
        });

        it('other lines should not have focus style', () => {
          cy.get('[data-test=config-line-3]').should(
            'not.have.class',
            '-focus',
          );
        });

        it('should set focus style on single line', () => {
          cy.get('[data-test=config-line-2]').should('have.class', '-focus');
        });
      });

      context('click line number, then shift click other line number', () => {
        beforeEach(() => {
          cy.get('[data-test=config-line-num-2]').click({ force: true });
          cy.get('[data-test=config-line-num-5]').click({
            force: true,
            shiftKey: true,
          });
          cy.wait(500); // Wait for range selection to process
        });

        it('should update path with range', () => {
          cy.hash().should('eq', '#2:5');
        });

        it('lines outside the range should not have focus style', () => {
          cy.get('[data-test=config-line-6]').should(
            'not.have.class',
            '-focus',
          );
        });

        it('lines within the range should have focus style', () => {
          cy.wait(500); // Wait for focus styles to apply
          cy.get('[data-test=config-line-2]').should('have.class', '-focus');
          cy.get('[data-test=config-line-3]').should('have.class', '-focus');
          cy.get('[data-test=config-line-4]').should('have.class', '-focus');
        });
      });
    },
  );
  context(
    'logged in and server returning valid pipeline configuration and templates with expansion errors',
    () => {
      beforeEach(() => {
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

        context('click expand pipeline again', () => {
          beforeEach(() => {
            cy.get('[data-test=pipeline-expand-toggle]').click({
              force: true,
            });
          });
          it('should revert to valid pipeline configuration', () => {
            cy.wait(2000); // Wait for reversion to complete
            cy.get('[data-test=pipeline-configuration-error]').should(
              'not.exist',
            );
            cy.get('[data-test=pipeline-configuration-data]').should(
              'be.visible',
            );
          });
        });
      });
    },
  );
  context(
    'logged in and server returning valid pipeline configuration (with warnings) and templates',
    () => {
      beforeEach(() => {
        cy.stubBuild();
        cy.stubPipelineWithWarnings();
        cy.stubPipelineExpand();
        cy.stubPipelineTemplates();
        cy.login('/github/octocat/1/pipeline');
      });

      it('warnings should be visible', () => {
        cy.get('[data-test=pipeline-warnings]').should('be.visible');
      });

      it('should show 2 warnings', () => {
        cy.get('[data-test=pipeline-warnings]')
          .children()
          .should('have.length', 2);
      });

      it('warning with line number should show line number button', () => {
        cy.get('[data-test=warning-line-num-4]')
          .should('be.visible')
          .should('not.have.class', '-disabled');
      });

      it('warning with line number should show content without line number', () => {
        cy.get('[data-test=warning-0] .line-content')
          .should('be.visible')
          .should('not.contain', '4')
          .should('contain', 'template');
      });

      it('warning without line number should replace button with dash', () => {
        cy.get('[data-test=warning-1]')
          .should('be.visible')
          .should('contain', '-');
      });

      it('warning without line number should content', () => {
        cy.get('[data-test=warning-1] .line-content')
          .should('be.visible')
          .should('contain', 'secrets');
      });

      it('log line with warning should show annotation', () => {
        cy.get('[data-test=warning-annotation-line-4]').should('be.visible');
      });

      it('other lines should not show annotations', () => {
        cy.get('[data-test=warning-annotation-line-5]').should(
          'not.be.visible',
        );
      });

      context('click warning line number', () => {
        beforeEach(() => {
          cy.get('[data-test=warning-line-num-4]').click({ force: true });
        });

        it('should update path with line num', () => {
          cy.hash().should('eq', '#4');
        });

        it('should set focus style on single line', () => {
          cy.get('[data-test=config-line-4]').should('have.class', '-focus');
        });

        it('other lines should not have focus style', () => {
          cy.get('[data-test=config-line-3]').should(
            'not.have.class',
            '-focus',
          );
        });
      });

      context('click expand templates', () => {
        beforeEach(() => {
          cy.get('[data-test=pipeline-expand-toggle]').click({
            force: true,
          });
          cy.wait('@expand');
        });

        it('should update path with expand query', () => {
          cy.location().should(loc => {
            expect(loc.search).to.eq('?expand=true');
          });
        });

        it('should show pipeline expansion note', () => {
          cy.get('[data-test=pipeline-warnings-expand-note]').contains('note');
        });

        it('warning with line number should show disabled line number button', () => {
          cy.get('[data-test=warning-line-num-4]')
            .should('be.visible')
            .should('have.class', '-disabled');
        });

        context('click warning line number', () => {
          beforeEach(() => {
            cy.get('[data-test=warning-line-num-4]').click({ force: true });
          });

          it('should not update path with line num', () => {
            cy.hash().should('not.eq', '#4');
          });

          it('other lines should not have focus style', () => {
            cy.get('[data-test=config-line-3]').should(
              'not.have.class',
              '-focus',
            );
          });
        });
      });
    },
  );
});
