{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Crumbs exposing (view)

import Html exposing (Html, a, li, ol, text)
import Html.Attributes exposing (attribute)
import Route.Path
import Tuple exposing (first, second)
import Url exposing (percentDecode)
import Utils.Helpers as Util



-- TYPES


type alias Crumb =
    ( String, Maybe Route.Path.Path )



-- VIEW


{-| crumbs : takes current page and returns Html breadcrumb that produce Msgs
-}
view : Route.Path.Path -> Html msg
view path =
    let
        crumbs =
            toCrumbs path

        items =
            List.map (\p -> item p path) crumbs
    in
    ol [ attribute "aria-label" "Breadcrumb" ] items


{-| item : uses page and current page and returns Html breadcrumb item with possible href link
-}
item : Crumb -> Route.Path.Path -> Html msg
item crumb path =
    let
        link =
            first crumb

        decodedLink =
            link
                |> percentDecode
                |> Maybe.withDefault link

        testAttribute =
            Util.testAttribute <| Util.formatTestTag <| "crumb-" ++ decodedLink
    in
    case second crumb of
        Nothing ->
            li [ testAttribute ] [ text decodedLink ]

        Just p ->
            if p == path then
                li [ testAttribute, attribute "aria-current" "page" ] [ text decodedLink ]

            else
                li [ testAttribute ] [ a [ Route.Path.href p ] [ text decodedLink ] ]



-- HELPERS


{-| toCrumbs : maps a Route to the appropriate breadcrumb trail
-}
toCrumbs : Route.Path.Path -> List Crumb
toCrumbs path =
    let
        -- crumbs used across multiple pages
        overviewCrumbLink =
            ( "Overview", Just Route.Path.Home )

        accountCrumbStatic =
            ( "Account", Nothing )

        sourceRepositoriesCrumbLink =
            ( "Source Repositories", Just Route.Path.AccountSourceRepos )

        addCrumbStatic =
            ( "Add", Nothing )

        editCrumbStatic =
            ( "Edit", Nothing )

        pages =
            case path of
                Route.Path.Home ->
                    [ overviewCrumbLink ]

                Route.Path.AccountSourceRepos ->
                    [ overviewCrumbLink, accountCrumbStatic, sourceRepositoriesCrumbLink ]

                -- Pages.OrgRepositories org _ _ ->
                --     let
                --         orgCrumbStatic =
                --             ( org, Nothing )
                --     in
                --     [ overviewCrumbLink, orgCrumbStatic ]
                -- Pages.Hooks org repo _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.RepoSettings org repo ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.OrgSecrets _ org _ _ ->
                --     let
                --         orgCrumbStatic =
                --             ( org, Nothing )
                --     in
                --     [ overviewCrumbLink, orgCrumbStatic ]
                -- Pages.RepoSecrets _ org repo _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.SharedSecrets _ org team maybePage _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         teamCrumbStatic =
                --             ( team, Nothing )
                --         sharedSecretsCrumbStatic =
                --             ( "Shared Secrets" ++ pageToString maybePage, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, teamCrumbStatic, sharedSecretsCrumbStatic ]
                -- Pages.AddOrgSecret engine org ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         orgSecretsCrumbLink =
                --             ( "Org Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, orgSecretsCrumbLink, addCrumbStatic ]
                -- Pages.AddRepoSecret engine org repo ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         repoSecretsCrumbLink =
                --             ( "Repo Secrets", Just <| Pages.RepoSecrets engine org repo Nothing Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, repoSecretsCrumbLink, addCrumbStatic ]
                -- Pages.AddDeployment org repo ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         deploymentsCrumbLink =
                --             ( "Deployments", Just <| Pages.RepositoryDeployments org repo Nothing Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, deploymentsCrumbLink, addCrumbStatic ]
                -- Pages.PromoteDeployment org repo _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         deploymentsCrumbLink =
                --             ( "Deployments", Just <| Pages.RepositoryDeployments org repo Nothing Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, deploymentsCrumbLink, addCrumbStatic ]
                -- Pages.AddSharedSecret engine org team ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         teamCrumbStatic =
                --             ( team, Nothing )
                --         sharedSecretsCrumbLink =
                --             ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, teamCrumbStatic, sharedSecretsCrumbLink, addCrumbStatic ]
                -- Pages.OrgSecret engine org name ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         orgSecretsCrumbLink =
                --             ( "Org Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )
                --         nameCrumbStatic =
                --             ( name, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, orgSecretsCrumbLink, nameCrumbStatic ]
                -- Pages.RepoSecret engine org repo name ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         repoSecretsCrumbLink =
                --             ( "Repo Secrets", Just <| Pages.RepoSecrets engine org repo Nothing Nothing )
                --         nameCrumbStatic =
                --             ( name, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, repoSecretsCrumbLink, nameCrumbStatic ]
                -- Pages.SharedSecret engine org team name ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         teamCrumbStatic =
                --             ( team, Nothing )
                --         sharedSecretsCrumbLink =
                --             ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )
                --         nameCrumbStatic =
                --             ( name, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, teamCrumbStatic, sharedSecretsCrumbLink, nameCrumbStatic ]
                -- Pages.OrgBuilds org _ _ _ ->
                --     let
                --         organizationPage =
                --             ( org, Nothing )
                --     in
                --     [ overviewCrumbLink, organizationPage ]
                -- Pages.RepositoryBuilds org repo _ _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.RepositoryBuildsPulls org repo _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.RepositoryBuildsTags org repo _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.RepositoryDeployments org repo _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.Build org repo buildNumber _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         buildNumberCrumbStatic =
                --             ( "#" ++ buildNumber, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]
                -- Pages.BuildPipeline org repo buildNumber _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         buildNumberCrumbStatic =
                --             ( "#" ++ buildNumber, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]
                -- Pages.Schedule org repo name ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         schedulesCrumbLink =
                --             ( "Schedules", Just <| Pages.Schedules org repo Nothing Nothing )
                --         nameCrumbStatic =
                --             ( name, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, schedulesCrumbLink, nameCrumbStatic ]
                -- Pages.Schedules org repo _ _ ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoCrumbStatic =
                --             ( repo, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]
                -- Pages.AddSchedule org repo ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         schedulesCrumbLink =
                --             ( "Schedules", Just <| Pages.Schedules org repo Nothing Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, schedulesCrumbLink, addCrumbStatic ]
                -- Pages.BuildGraph org repo buildNumber ->
                --     let
                --         orgReposCrumbLink =
                --             ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                --         repoBuildsCrumbLink =
                --             ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                --         buildNumberCrumbStatic =
                --             ( "#" ++ buildNumber, Nothing )
                --     in
                --     [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]
                Route.Path.AccountLogin ->
                    let
                        loginCrumbStatic =
                            ( "Login", Nothing )
                    in
                    [ accountCrumbStatic, loginCrumbStatic ]

                Route.Path.AccountLogout ->
                    let
                        logoutCrumbStatic =
                            ( "Logout", Nothing )
                    in
                    [ accountCrumbStatic, logoutCrumbStatic ]

                Route.Path.AccountAuthenticate_ ->
                    let
                        loginCrumbStatic =
                            ( "Login", Nothing )
                    in
                    [ accountCrumbStatic, loginCrumbStatic ]

                Route.Path.AccountSettings ->
                    let
                        settingsCrumbStatic =
                            ( "My Settings", Nothing )
                    in
                    [ overviewCrumbLink, settingsCrumbStatic ]

                Route.Path.Org_ params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink ]

                Route.Path.Org_Builds params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        buildsCrumbStatic =
                            ( "Builds", Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, buildsCrumbStatic ]

                Route.Path.Org_Secrets params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        secretsCrumbStatic =
                            ( "Secrets", Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, secretsCrumbStatic ]

                Route.Path.Org_SecretsAdd params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        secretsCrumbLink =
                            ( "Secrets", Just <| Route.Path.Org_Secrets { org = params.org } )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, secretsCrumbLink, addCrumbStatic ]

                Route.Path.Org_SecretsEdit_ params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        secretsCrumbLink =
                            ( "Secrets", Just <| Route.Path.Org_Secrets { org = params.org } )

                        nameCrumbStatic =
                            ( params.name, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, secretsCrumbLink, editCrumbStatic, nameCrumbStatic ]

                Route.Path.Org_Repo_ params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoCrumbStatic =
                            ( params.repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Route.Path.Org_Repo_Deployments params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoCrumbStatic =
                            ( params.repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Route.Path.Org_Repo_Audit params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoCrumbStatic =
                            ( params.repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Route.Path.Org_Repo_Secrets params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoCrumbLink =
                            ( params.repo, Just <| Route.Path.Org_Repo_ { org = params.org, repo = params.repo } )

                        secretsCrumbStatic =
                            ( "Secrets", Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbLink, secretsCrumbStatic ]

                Route.Path.Org_Repo_SecretsAdd params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoCrumbLink =
                            ( params.repo, Just <| Route.Path.Org_Repo_ { org = params.org, repo = params.repo } )

                        secretsCrumbLink =
                            ( "Secrets", Just <| Route.Path.Org_Repo_Secrets { org = params.org, repo = params.repo } )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbLink, secretsCrumbLink, addCrumbStatic ]

                Route.Path.Org_Repo_SecretsEdit_ params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoCrumbLink =
                            ( params.repo, Just <| Route.Path.Org_Repo_ { org = params.org, repo = params.repo } )

                        secretsCrumbLink =
                            ( "Secrets", Just <| Route.Path.Org_Repo_Secrets { org = params.org, repo = params.repo } )

                        nameCrumbStatic =
                            ( params.name, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbLink, secretsCrumbLink, editCrumbStatic, nameCrumbStatic ]

                Route.Path.Org_Repo_Build_ params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoBuildsCrumbLink =
                            ( params.repo, Just <| Route.Path.Org_Repo_ { org = params.org, repo = params.repo } )

                        buildNumberCrumbStatic =
                            ( "#" ++ params.buildNumber, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]

                Route.Path.Org_Repo_Build_Services params ->
                    let
                        orgReposCrumbLink =
                            ( params.org, Just <| Route.Path.Org_ { org = params.org } )

                        repoBuildsCrumbLink =
                            ( params.repo, Just <| Route.Path.Org_Repo_ { org = params.org, repo = params.repo } )

                        buildNumberCrumbStatic =
                            ( "#" ++ params.buildNumber, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]

                Route.Path.NotFound_ ->
                    let
                        notFoundCrumbStatic =
                            ( "Not Found", Nothing )
                    in
                    [ overviewCrumbLink, notFoundCrumbStatic ]
    in
    pages
