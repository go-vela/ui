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
    context("click on vela org", () => {
      beforeEach(() => {
        cy.get("[data-test=source-org-vela]").click();
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
        it("ideas should not show", () => {
          cy.get("[data-test=source-repo-ideas]").should("not.be.visible");
        });
        it("org repo count should not exist", () => {
          cy.get("[data-test=source-repo-count]").should("not.be.visible");
        });
      });

      context("type 'vela' into the global search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]")
            .should("be.visible")
            .clear()
            .type("vela");
        });
        it("server should show", () => {
          cy.get("[data-test=source-repo-server]").should("be.visible");
        });
        it("ideas should show", () => {
          cy.get("[data-test=source-repo-ideas]").should("be.visible");
        });
        it("applications should not show", () => {
          cy.get("[data-test=source-repo-applications]").should(
            "not.be.visible"
          );
        });
        it("org repo count should not exist", () => {
          cy.get("[data-test=source-repo-count]").should("not.be.visible");
        });
      });

      context("type 'ide' into the vela org local search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]").clear();
          cy.get("[data-test=local-search-input-vela]")
            .should("be.visible")
            .clear()
            .type("ide");
        });
        it("ideas should show", () => {
          cy.get("[data-test=source-repo-ideas]").should("be.visible");
        });
        it("server should not show", () => {
          cy.get("[data-test=source-repo-server]").should("not.be.visible");
        });
        it("vela repo count should display 1", () => {
          cy.get("[data-test=source-repo-count]")
            .should("be.visible")
            .should("contain", "1");
        });
        context("clear vela local search bar", () => {
          beforeEach(() => {
            cy.get("[data-test=global-search-input]").clear();
            cy.get("[data-test=local-search-input-vela]")
              .should("be.visible")
              .clear();
          });
          it("ideas should show", () => {
            cy.get("[data-test=source-repo-ideas]").should("be.visible");
          });
          it("server should show", () => {
            cy.get("[data-test=source-repo-server]").should("be.visible");
          });
        });
      });

      context("type 'api' into the vela org local search bar", () => {
        beforeEach(() => {
          cy.get("[data-test=global-search-input]").clear();
          cy.get("[data-test=local-search-input-vela]")
            .should("be.visible")
            .clear()
            .type("api");
        });
        it("api should show", () => {
          cy.get("[data-test=source-repo-api]").should("be.visible");
        });
        it("add all button should contain Add Results", () => {
          cy.get("[data-test=add-org-vela]").contains("Add Results");
        });
        context(
          "click Add All button, then clear vela local search input",
          () => {
            beforeEach(() => {
              cy.route(
                "POST",
                "*api/v1/repos*",
                "fixture:add_repo_response.json"
              );
              cy.get("[data-test=add-org-vela]").click({ force: true });
              cy.get("[data-test=local-search-input-vela]")
                .should("be.visible")
                .clear();
            });
            it("filtered repos should show and display adding", () => {
              cy.get("[data-test=source-repo-api]")
                .should("be.visible")
                .and("contain", "Adding");

              cy.get("[data-test=source-repo-api-1]")
                .should("be.visible")
                .and("contain", "Adding");

              cy.get("[data-test=source-repo-api-2]")
                .should("be.visible")
                .and("contain", "Adding");

              cy.get("[data-test=source-repo-api-docs]")
                .should("be.visible")
                .and("contain", "Adding");
            });
            it("non-filtered repos should show but not display adding", () => {
              cy.get("[data-test=source-repo-server]")
                .should("be.visible")
                .and("not.contain", "Adding");
              cy.get("[data-test=source-repo-ideas]")
                .should("be.visible")
                .and("not.contain", "Adding");
            });
            it("add all button should contain Add All", () => {
              cy.get("[data-test=add-org-vela]").contains("Add All");
            });
          }
        );
      });

      context("with searches entered, refresh source repos list", () => {
        beforeEach(() => {
          cy.get("[data-test=local-search-input-vela]")
            .should("be.visible")
            .clear()
            .type("serv");
          cy.get("[data-test=global-search-input]")
            .should("be.visible")
            .clear()
            .type("vela");
          cy.get("[data-test=refresh-source-repos]")
            .should("be.visible")
            .click();
        });
        it("global search should be cleared", () => {
          cy.get("[data-test=global-search-input]").should(
            "not.contain",
            "vela"
          );
        });
        it("local search should be cleared", () => {
          cy.get("[data-test=local-search-input-vela]").should(
            "not.contain",
            "serv"
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
          cy.get("[data-test=local-search-input-vela]")
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
