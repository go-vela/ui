{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Crumbs exposing (view)

import Html exposing (Html, a, li, ol, text)
import Html.Attributes exposing (attribute)
import Pages exposing (Page, toRoute)
import Routes
import Tuple exposing (first, second)
import Url exposing (percentDecode)
import Util exposing (pageToString)



-- TYPES


type alias Crumb =
    ( String, Maybe Page )



-- VIEW


{-| crumbs : takes current page and returns Html breadcrumb that produce Msgs
-}
view : Page -> Html msg
view currentPage =
    let
        path =
            toPath currentPage

        items =
            List.map (\page -> item page currentPage) path
    in
    ol [ attribute "aria-label" "Breadcrumb" ] items


{-| item : uses page and current page and returns Html breadcrumb item with possible href link
-}
item : Crumb -> Page -> Html msg
item crumb currentPage =
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

        Just page ->
            if page == currentPage then
                li [ testAttribute, attribute "aria-current" "page" ] [ text decodedLink ]

            else
                li [ testAttribute ] [ a [ Routes.href <| toRoute page ] [ text decodedLink ] ]



-- HELPERS


{-| toPath : maps a Page to the appropriate breadcrumb trail
-}
toPath : Page -> List Crumb
toPath page =
    let
        -- crumbs used across multiple pages
        overviewCrumbLink =
            ( "Overview", Just Pages.Overview )

        accountCrumbStatic =
            ( "Account", Nothing )

        sourceRepositoriesCrumbLink =
            ( "Source Repositories", Just Pages.SourceRepositories )

        addCrumbStatic =
            ( "Add", Nothing )

        pages =
            case page of
                Pages.Overview ->
                    [ overviewCrumbLink ]

                Pages.SourceRepositories ->
                    [ overviewCrumbLink, accountCrumbStatic, sourceRepositoriesCrumbLink ]

                Pages.OrgRepositories org _ _ ->
                    let
                        orgCrumbStatic =
                            ( org, Nothing )
                    in
                    [ overviewCrumbLink, orgCrumbStatic ]

                Pages.Hooks org repo _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.RepoSettings org repo ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.OrgSecrets _ org _ _ ->
                    let
                        orgCrumbStatic =
                            ( org, Nothing )
                    in
                    [ overviewCrumbLink, orgCrumbStatic ]

                Pages.RepoSecrets _ org repo _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.SharedSecrets _ org team maybePage _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        teamCrumbStatic =
                            ( team, Nothing )

                        sharedSecretsCrumbStatic =
                            ( "Shared Secrets" ++ pageToString maybePage, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, teamCrumbStatic, sharedSecretsCrumbStatic ]

                Pages.AddOrgSecret engine org ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        orgSecretsCrumbLink =
                            ( "Org Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, orgSecretsCrumbLink, addCrumbStatic ]

                Pages.AddRepoSecret engine org repo ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        repoSecretsCrumbLink =
                            ( "Repo Secrets", Just <| Pages.RepoSecrets engine org repo Nothing Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, repoSecretsCrumbLink, addCrumbStatic ]

                Pages.AddDeployment org repo ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        deploymentsCrumbLink =
                            ( "Deployments", Just <| Pages.RepositoryDeployments org repo Nothing Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, deploymentsCrumbLink, addCrumbStatic ]

                Pages.PromoteDeployment org repo _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        deploymentsCrumbLink =
                            ( "Deployments", Just <| Pages.RepositoryDeployments org repo Nothing Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, deploymentsCrumbLink, addCrumbStatic ]

                Pages.AddSharedSecret engine org team ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        teamCrumbStatic =
                            ( team, Nothing )

                        sharedSecretsCrumbLink =
                            ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, teamCrumbStatic, sharedSecretsCrumbLink, addCrumbStatic ]

                Pages.OrgSecret engine org name ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        orgSecretsCrumbLink =
                            ( "Org Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )

                        nameCrumbStatic =
                            ( name, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, orgSecretsCrumbLink, nameCrumbStatic ]

                Pages.RepoSecret engine org repo name ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        repoSecretsCrumbLink =
                            ( "Repo Secrets", Just <| Pages.RepoSecrets engine org repo Nothing Nothing )

                        nameCrumbStatic =
                            ( name, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, repoSecretsCrumbLink, nameCrumbStatic ]

                Pages.SharedSecret engine org team name ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        teamCrumbStatic =
                            ( team, Nothing )

                        sharedSecretsCrumbLink =
                            ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )

                        nameCrumbStatic =
                            ( name, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, teamCrumbStatic, sharedSecretsCrumbLink, nameCrumbStatic ]

                Pages.OrgBuilds org _ _ _ ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewCrumbLink, organizationPage ]

                Pages.RepositoryBuilds org repo _ _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.RepositoryBuildsPulls org repo _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.RepositoryBuildsTags org repo _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.RepositoryDeployments org repo _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.Build org repo buildNumber _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        buildNumberCrumbStatic =
                            ( "#" ++ buildNumber, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]

                Pages.BuildServices org repo buildNumber _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        buildNumberCrumbStatic =
                            ( "#" ++ buildNumber, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]

                Pages.BuildPipeline org repo buildNumber _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        buildNumberCrumbStatic =
                            ( "#" ++ buildNumber, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]

                Pages.Schedule org repo name ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        schedulesCrumbLink =
                            ( "Schedules", Just <| Pages.Schedules org repo Nothing Nothing )

                        nameCrumbStatic =
                            ( name, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, schedulesCrumbLink, nameCrumbStatic ]

                Pages.Schedules org repo _ _ ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoCrumbStatic =
                            ( repo, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoCrumbStatic ]

                Pages.AddSchedule org repo ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        schedulesCrumbLink =
                            ( "Schedules", Just <| Pages.Schedules org repo Nothing Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, schedulesCrumbLink, addCrumbStatic ]

                Pages.BuildGraph org repo buildNumber ->
                    let
                        orgReposCrumbLink =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsCrumbLink =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        buildNumberCrumbStatic =
                            ( "#" ++ buildNumber, Nothing )
                    in
                    [ overviewCrumbLink, orgReposCrumbLink, repoBuildsCrumbLink, buildNumberCrumbStatic ]

                Pages.Login ->
                    []

                Pages.Settings ->
                    let
                        settingsCrumbStatic =
                            ( "My Settings", Nothing )
                    in
                    [ overviewCrumbLink, settingsCrumbStatic ]

                Pages.NotFound ->
                    let
                        notFoundCrumbStatic =
                            ( "Not Found", Nothing )
                    in
                    [ overviewCrumbLink, notFoundCrumbStatic ]
    in
    pages
