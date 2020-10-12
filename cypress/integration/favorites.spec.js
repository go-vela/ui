/*
 * Copyright (c) 2020 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

context('Favorites', () => {
  context('error loading user', () => {
    beforeEach(() => {
      cy.server();
      cy.route({
        method: 'GET',
        url: 'api/v1/user*',
        status: 500,
        response: {
          error: 'error fetching user',
        },
      });
      cy.login();
    });

    it('should show the errors tray', () => {
      cy.get('[data-test=alerts]')
        .should('exist')
        .contains('error fetching user');
    });
  });

  context('user loaded with no favorites', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/user*', 'fixture:favorites_none.json');
      cy.visit('/');
    });

    it('should show how to add favorites', () => {
      cy.get('[data-test=overview]').should(
        'contain',
        'To display a repository here, click the',
      );
    });
  });

  context('source repos/user favorites loaded', () => {
    beforeEach(() => {
      cy.server();
      cy.route('GET', '*api/v1/user*', 'fixture:favorites.json');
      cy.route('PUT', '*api/v1/user*', 'fixture:favorites_add.json');
      cy.route(
        'GET',
        '*api/v1/user/source/repos*',
        'fixture:source_repositories.json',
      ).as('sourceRepos');
      cy.route(
        'POST',
        '*api/v1/repos*',
        'fixture:enable_repo_response.json',
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
        context('enable cat/purr', () => {
          beforeEach(() => {
            cy.get('[data-test=source-org-cat]').as('catOrg');
            cy.get('[data-test=source-org-cat] ~ [data-test^=source-repo]').as(
              'catRepos',
            );

            cy.get('@catOrg').click();
            cy.get('[data-test=enable-cat-purr]').click();
            cy.wait('@enableRepo');
            cy.get('[data-test=star-toggle-cat-purr]').as('togglePurr');
          });
          it('should show favorites star toggle', () => {
            cy.get('[data-test=star-toggle-cat-purr]').should('be.visible');
          });

          it('star should have favorited class', () => {
            cy.get('[data-test=star-toggle-cat-purr] > svg').should(
              'have.class',
              'favorited',
            );
          });

          context('add favorite cat/purr', () => {
            beforeEach(() => {
              cy.get('@togglePurr').should('exist').click();
            });

            it('star should have favorited class', () => {
              cy.get('[data-test=star-toggle-cat-purr] > svg').should(
                'have.class',
                'favorited',
              );
            });

            it('should show a success alert', () => {
              cy.get('[data-test=alerts]').should('exist').contains('Success');
              cy.get('[data-test=alerts]')
                .children()
                .last()
                .contains('added to favorites');
            });

            context('remove favorite cat/purr', () => {
              beforeEach(() => {
                cy.route('PUT', '*api/v1/user*', 'fixture:favorites.json');
                cy.get('@togglePurr').should('exist').click();
              });

              it('should show a success alert', () => {
                cy.get('[data-test=alerts]')
                  .should('exist')
                  .contains('Success');
                cy.get('[data-test=alerts]')
                  .children()
                  .last()
                  .contains('removed from favorites');
              });

              it('star should not have favorited class', () => {
                cy.get('[data-test=star-toggle-cat-purr] > svg').should(
                  'not.have.class',
                  'favorited',
                );
              });
            });
          });
        });
      });
      context('Repo Builds page', () => {
        beforeEach(() => {
          cy.visit('/cat/purr');
          cy.get('[data-test=star-toggle-cat-purr]').as('togglePurr');
        });

        it('enabling repo should show favorites star toggle', () => {
          cy.get('[data-test=star-toggle-cat-purr]').should('be.visible');
        });

        it('star should not have favorited class', () => {
          cy.get('[data-test=star-toggle-cat-purr] > svg').should(
            'not.have.class',
            'favorited',
          );
          cy.get('@togglePurr').should('exist').click();
          cy.get('[data-test=star-toggle-cat-purr] > svg').should(
            'have.class',
            'favorited',
          );
        });

        context('add favorite cat/purr', () => {
          beforeEach(() => {
            cy.get('@togglePurr').should('exist').click();
          });

          it('star should add favorited class', () => {
            cy.get('[data-test=star-toggle-cat-purr] > svg').should(
              'have.class',
              'favorited',
            );
          });

          context('visit Overview page', () => {
            beforeEach(() => {
              cy.route('GET', '*api/v1/user*', 'fixture:favorites_add.json');
              cy.visit('/');
            });

            it('cat/purr should display in favorites', () => {
              cy.get('[data-test=star-toggle-cat-purr]')
                .as('togglePurr')
                .should('exist');
              cy.get('[data-test=star-toggle-cat-purr] > svg').should(
                'have.class',
                'favorited',
              );
            });

            it('clicking star should remove cat/purr from favorites', () => {
              cy.route('PUT', '*api/v1/user*', 'fixture:favorites.json');
              cy.get('[data-test=star-toggle-cat-purr]').as('togglePurr');
              cy.get('@togglePurr').click();
              cy.get('[data-test=star-toggle-cat-purr]').should(
                'not.be.visible',
              );
            });
          });

          context('remove favorite cat/purr', () => {
            beforeEach(() => {
              cy.route('PUT', '*api/v1/user*', 'fixture:favorites.json');
              cy.get('@togglePurr').should('exist').click();
            });

            it('star should not have favorited class', () => {
              cy.get('[data-test=star-toggle-cat-purr] > svg').should(
                'not.have.class',
                'favorited',
              );
            });
          });
        });
      });
    });
  });
});
