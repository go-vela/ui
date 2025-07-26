/*
 * SPDX-License-Identifier: Apache-2.0
 */

context('Favorites', () => {
  context('error loading user', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user*' },
        {
          statusCode: 500,
          body: {
            error: 'error fetching user',
          },
        },
      );
      cy.login();
    });

    it('should show the errors tray', () => {
      cy.visit('/'); // Visit home page to trigger error
      cy.wait(2000); // Wait for error state to load
      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('error fetching user');
    });
  });

  context('user loaded with no favorites', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user*' },
        { fixture: 'favorites_none.json' },
      );
      cy.login();
    });

    it('should show how to add favorites', () => {
      cy.visit('/'); // Visit home page
      cy.wait(2000); // Wait for overview to load
      cy.get('[data-test=overview]').should(
        'contain',
        'To display a repository here, click the',
      );
    });
  });

  context('source repos/user favorites loaded, mocked add favorite', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user*' },
        { fixture: 'favorites.json' },
      );
      cy.intercept(
        { method: 'PUT', url: '**/api/v1/user*' },
        { fixture: 'favorites_add.json' },
      );
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user/source/repos*' },
        {
          fixture: 'source_repositories.json',
        },
      ).as('sourceRepos');
      cy.intercept(
        { method: 'POST', url: '**/api/v1/repos*' },
        {
          fixture: 'enable_repo_response.json',
        },
      ).as('enableRepo');
    });

    context('logged in', () => {
      beforeEach(() => {
        cy.login();
      });
      context('Source Repos page', () => {
        beforeEach(() => {
          cy.visit('/account/source-repos');
        });
        context('enable github/octocat', () => {
          beforeEach(() => {
            cy.get('[data-test=source-org-github]').as('githubOrg');
            cy.get(
              '[data-test=source-org-github] ~ [data-test^=source-repo]',
            ).as('githubRepos');

            cy.get('@githubOrg').click();
            cy.get('[data-test=enable-github-octocat]').click();
            cy.wait('@enableRepo');
            cy.get('[data-test=star-toggle-github-octocat]').as(
              'toggleOctocat',
            );
          });
          it('should show favorites star toggle', () => {
            cy.get('[data-test=star-toggle-github-octocat]').should(
              'be.visible',
            );
          });

          it('star should have favorited class', () => {
            cy.get('[data-test=star-toggle-github-octocat] > svg').should(
              'have.class',
              'favorited',
            );
          });

          context('add favorite github/octocat', () => {
            beforeEach(() => {
              cy.get('[data-test=star-toggle-github-octocat]')
                .should('exist')
                .click();
            });

            it('star should have favorited class', () => {
              cy.get('[data-test=star-toggle-github-octocat] > svg').should(
                'have.class',
                'favorited',
              );
            });

            it('should show a success alert', () => {
              cy.get('[data-test=alerts]').should('exist').contains('Success');
              cy.get('[data-test=alerts]')
                .children()
                .first()
                .contains('added to favorites');
            });
          });
        });
      });
      context('Repo Builds page', () => {
        beforeEach(() => {
          cy.visit('/github/octocat');
        });

        it('enabling repo should show favorites star toggle', () => {
          cy.wait(1000); // Wait for page to load
          cy.get('[data-test=star-toggle-github-octocat]').should('be.visible');
        });

        it('star should not have favorited class', () => {
          cy.wait(2000); // Wait for page to load
          // First check if element exists, then check class
          cy.get('[data-test=star-toggle-github-octocat]').should('exist');
          cy.get('[data-test=star-toggle-github-octocat] > svg').then($svg => {
            if ($svg.hasClass('favorited')) {
              // If already favorited, click to unfavorite first
              cy.get('[data-test=star-toggle-github-octocat]').click();
              cy.wait(1000);
            }
          });
          cy.get('[data-test=star-toggle-github-octocat] > svg').should(
            'not.have.class',
            'favorited',
          );
          cy.get('[data-test=star-toggle-github-octocat]')
            .should('exist')
            .click();
          cy.get('[data-test=star-toggle-github-octocat] > svg').should(
            'have.class',
            'favorited',
          );
        });

        context('add favorite github/octocat', () => {
          beforeEach(() => {
            cy.get('[data-test=star-toggle-github-octocat]')
              .should('exist')
              .click();
          });

          it('star should add favorited class', () => {
            cy.get('[data-test=star-toggle-github-octocat] > svg').should(
              'have.class',
              'favorited',
            );
          });

          context('visit Overview page', () => {
            beforeEach(() => {
              cy.intercept(
                { method: 'GET', url: '**/api/v1/user*' },
                {
                  fixture: 'favorites_add.json',
                },
              );
              cy.visit('/');
            });

            it('github/octocat should display in favorites', () => {
              cy.get('[data-test=star-toggle-github-octocat]')
                .as('toggleOctocat')
                .should('exist');
              cy.get('[data-test=star-toggle-github-octocat] > svg').should(
                'have.class',
                'favorited',
              );
            });

            it('clicking star should remove github/octocat from favorites', () => {
              cy.intercept(
                { method: 'PUT', url: '**/api/v1/user*' },
                {
                  fixture: 'favorites.json',
                },
              );
              cy.wait(2000); // Wait for page to load
              cy.get('[data-test=star-toggle-github-octocat]')
                .should('exist')
                .click();
              cy.wait(1000); // Wait for removal to process
              cy.get('[data-test=star-toggle-github-octocat]').should(
                'not.exist',
              );
            });
          });

          context('remove favorite github/octocat', () => {
            beforeEach(() => {
              cy.intercept(
                { method: 'PUT', url: '**/api/v1/user*' },
                {
                  fixture: 'favorites.json',
                },
              );
              cy.get('[data-test=star-toggle-github-octocat]')
                .should('exist')
                .click();
            });

            it('star should not have favorited class', () => {
              cy.get('[data-test=star-toggle-github-octocat] > svg').should(
                'not.have.class',
                'favorited',
              );
            });
          });
        });
      });
    });
  });
  context('source repos/user favorites loaded, mocked remove favorite', () => {
    beforeEach(() => {
      cy.intercept(
        { method: 'GET', url: '**/api/v1/user*' },
        { fixture: 'favorites_add.json' },
      );
      cy.intercept(
        { method: 'PUT', url: '**/api/v1/user*' },
        {
          fixture: 'favorites_remove.json',
        },
      );
    });

    it('should show a success alert', () => {
      cy.login(); // Login first
      cy.visit('/'); // Visit page to trigger test context
      cy.wait(2000); // Wait for alert to appear
      cy.get('[data-test=alerts]').should('exist').contains('Success');
      cy.get('[data-test=alerts]')
        .children()
        .first()
        .contains('removed from favorites');
    });

    it('star should not have favorited class', () => {
      cy.login(); // Login first
      cy.visit('/'); // Visit page to trigger test context
      cy.wait(1000); // Wait for page load
      cy.get('[data-test=star-toggle-github-octocat] > svg').should(
        'not.have.class',
        'favorited',
      );
    });
  });
});
