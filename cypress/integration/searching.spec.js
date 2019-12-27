context("Searching", () => {
  context("logged in and server returning source repos", () => {
    beforeEach(() => {
      cy.server();
      cy.fixture("source_repos")
        .then(repos => {
          cy.route({
            method: "GET",
            url: "api/v1/user/source/repos*",
            status: 200,
            response: repos
          });
        })
        .as("sourceRepos");
      cy.login("/account/add-repos");
    });

    it("global search bar should show", () => {
      cy.get("[data-test=global-search-bar]").should("be.visible");
    });
    context("click on github org", () => {
      beforeEach(() => {
        cy.get("[data-test=source-org-github]").click();
      });
      it("local search bar should show", () => {
        cy.get("[data-test=local-search-bar]").should("be.visible");
      });
      context("type 'serv' into the global search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]")
            .should("be.visible")
            .clear()
            .type("serv");
        });
        it("server should show", () => {
          cy.get("[data-test=source-repo-server]").should("be.visible");
        });
        it("octocat should not show", () => {
          cy.get("[data-test=source-repo-octocat]").should("not.be.visible");
        });
        it("org repo count should not exist", () => {
          cy.get("[data-test=source-repo-count]").should("not.be.visible");
        });
        it("cat org should not exist", () => {
          cy.get("[data-test=source-org-cat]").should("not.be.visible");
        });
      });

      context("type 'octo' into the github org local search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]").clear();
          cy.get("[data-test=local-search-input-github]")
            .should("be.visible")
            .clear()
            .type("octo");
        });
        it("octocat should show", () => {
          cy.get("[data-test=source-repo-octocat]").should("be.visible");
        });
        it("server should not show", () => {
          cy.get("[data-test=source-repo-server]").should("not.be.visible");
        });
        it("github repo count should display 3", () => {
          cy.get("[data-test=source-repo-count]")
            .should("be.visible")
            .should("contain", "3");
        });
        context("clear github local search bar", () => {
          beforeEach(() => {
            cy.get("[data-test=global-search-input]").clear();
            cy.get("[data-test=local-search-input-github]")
              .should("be.visible")
              .clear();
          });
          it("octocat and server should show", () => {
            cy.get("[data-test=source-repo-octocat]").should("be.visible");
            cy.get("[data-test=source-repo-server]").should("be.visible");
          });
        });
      });

      context("type 'octo' into the github org local search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]").clear();
          cy.get("[data-test=local-search-input-github]")
            .should("be.visible")
            .clear()
            .type("octo");
        });
        it("octocat should show", () => {
          cy.get("[data-test=source-repo-octocat]").should("be.visible");
        });
        it("add all button should contain Add Results", () => {
          cy.get("[data-test=activate-org-github]").contains("Add Results");
        });
        context(
          "click Add All button, then clear github local search input",
          () => {
            beforeEach(() => {
              cy.route(
                "POST",
                "*api/v1/repos*",
                "fixture:add_repo_response.json"
              );
              cy.get("[data-test=activate-org-github]").click({ force: true });
              cy.get("[data-test=local-search-input-github]")
                .should("be.visible")
                .clear();
            });
            it("filtered repos should show and display activating", () => {
              cy.get("[data-test=source-repo-octocat]")
                .should("be.visible")
                .and("contain", "Activating");

              cy.get("[data-test=source-repo-octocat-1]")
                .should("be.visible")
                .and("contain", "Activating");

              cy.get("[data-test=source-repo-octocat-2]")
                .should("be.visible")
                .and("contain", "Activating");

              cy.get("[data-test=source-repo-server]")
                .should("be.visible")
                .and("not.contain", "Activating");
            });
            it("non-filtered repos should show but not display activating", () => {
              cy.get("[data-test=source-repo-server]")
                .should("be.visible")
                .and("not.contain", "Activating");
              cy.get("[data-test=source-repo-octocat]")
                .should("be.visible")
                .and("contain", "Activating");
            });
            it("without search input, add all button should contain Add All", () => {
              cy.get("[data-test=activate-org-github]").contains("Add All");
            });
          }
        );
      });

      context("with searches entered, refresh source repos list", () => {
        beforeEach(() => {
          cy.get("[data-test=local-search-input-github]")
            .should("be.visible")
            .clear()
            .type("serv");
          cy.get("[data-test=global-search-input]")
            .should("be.visible")
            .clear()
            .type("github");
          cy.get("[data-test=refresh-source-repos]")
            .should("be.visible")
            .click();
        });
        it("global search should be cleared", () => {
          cy.get("[data-test=global-search-input]").should(
            "not.contain",
            "octo"
          );
        });
        it("local search should be cleared", () => {
          cy.get("[data-test=local-search-input-github]").should(
            "not.contain",
            "octo"
          );
        });
      });

      context("type 'nonsense' into the global search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]")
            .should("be.visible")
            .clear()
            .type("nonsense");
        });
        it("should show message for 'No results'", () => {
          cy.get("[data-test=source-repos]").should("contain", "No results");
        });
      });

      context("type 'nonsense' into the local search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=local-search-input-github]")
            .should("be.visible")
            .clear()
            .type("nonsense");
        });
        it("should show message for 'No results'", () => {
          cy.get("[data-test=source-repos]").should("contain", "No results");
        });
      });
    });
  });
});
