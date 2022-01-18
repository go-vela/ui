{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
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
        overviewPage =
            ( "Overview", Just Pages.Overview )

        accountPage =
            ( "Account", Nothing )

        sourceRepositoriesPage =
            ( "Source Repositories", Just Pages.SourceRepositories )

        notFoundPage =
            ( "Not Found", Nothing )

        pages =
            case page of
                Pages.Overview ->
                    [ overviewPage ]

                Pages.SourceRepositories ->
                    [ overviewPage, accountPage, sourceRepositoriesPage ]

                Pages.OrgRepositories org _ _ ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewPage, organizationPage ]

                Pages.Hooks org repo _ _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Nothing )
                    in
                    [ overviewPage
                    , organizationPage
                    , currentRepo
                    ]

                Pages.RepoSettings org repo ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Nothing )
                    in
                    [ overviewPage
                    , organizationPage
                    , currentRepo
                    ]

                Pages.OrgSecrets _ org _ _ ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewPage, organizationPage ]

                Pages.RepoSecrets _ org repo _ _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Nothing )
                    in
                    [ overviewPage, organizationPage, currentRepo ]

                Pages.SharedSecrets _ org team maybePage _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        teamPage =
                            ( team, Nothing )

                        sharedSecrets =
                            ( "Shared Secrets" ++ pageToString maybePage, Nothing )
                    in
                    [ overviewPage, organizationPage, teamPage, sharedSecrets ]

                Pages.AddOrgSecret engine org ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        orgSecrets =
                            ( "Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )
                    in
                    [ overviewPage, organizationPage, orgSecrets, ( "Add", Nothing ) ]

                Pages.AddRepoSecret engine org repo ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Just <| Pages.RepoSecrets engine org repo Nothing Nothing )
                    in
                    [ overviewPage, organizationPage, currentRepo, ( "Add", Nothing ) ]

                Pages.AddDeployment org repo ->
                    let
                        orgPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Just <| Pages.RepositoryDeployments org repo Nothing Nothing )
                    in
                    [ overviewPage, orgPage, currentRepo, ( "Add Deployment", Nothing ) ]

                Pages.PromoteDeployment org repo _ ->
                    let
                        orgPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Just <| Pages.RepositoryDeployments org repo Nothing Nothing )
                    in
                    [ overviewPage, orgPage, currentRepo, ( "Add Deployment", Nothing ) ]

                Pages.AddSharedSecret engine org team ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        teamPage =
                            ( team, Nothing )

                        sharedSecrets =
                            ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )
                    in
                    [ overviewPage, organizationPage, teamPage, sharedSecrets, ( "Add", Nothing ) ]

                Pages.OrgSecret engine org name ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        orgSecrets =
                            ( "Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )

                        nameCrumb =
                            ( name, Nothing )
                    in
                    [ overviewPage, organizationPage, orgSecrets, nameCrumb ]

                Pages.RepoSecret engine org repo name ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        currentRepo =
                            ( repo, Just <| Pages.RepoSecrets engine org repo Nothing Nothing )

                        nameCrumb =
                            ( name, Nothing )
                    in
                    [ overviewPage, organizationPage, currentRepo, nameCrumb ]

                Pages.SharedSecret engine org team name ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        teamPage =
                            ( team, Nothing )

                        sharedSecrets =
                            ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )

                        nameCrumb =
                            ( name, Nothing )
                    in
                    [ overviewPage, organizationPage, teamPage, sharedSecrets, nameCrumb ]

                Pages.OrgBuilds org _ _ _ ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewPage, organizationPage ]

                Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                    in
                    [ overviewPage, organizationPage, ( repo, Just <| Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ) ]

                Pages.RepositoryDeployments org repo maybePage maybePerPage ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                    in
                    [ overviewPage, organizationPage, ( repo, Just <| Pages.RepositoryDeployments org repo maybePage maybePerPage ) ]

                Pages.Build org repo buildNumber _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                    in
                    [ overviewPage
                    , organizationPage
                    , ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                    , ( "#" ++ buildNumber, Nothing )
                    ]

                Pages.BuildServices org repo buildNumber _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )
                    in
                    [ overviewPage
                    , organizationPage
                    , ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                    , ( "#" ++ buildNumber, Nothing )
                    ]

                Pages.BuildPipeline org repo buildNumber _ _ _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsPage =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                    in
                    [ overviewPage
                    , organizationPage
                    , repoBuildsPage
                    , ( "#" ++ buildNumber, Nothing )
                    ]

                Pages.Pipeline org repo _ _ _ ->
                    let
                        organizationPage =
                            ( org, Just <| Pages.OrgRepositories org Nothing Nothing )

                        repoBuildsPage =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                    in
                    [ overviewPage
                    , organizationPage
                    , repoBuildsPage
                    , ( "Pipeline", Nothing )
                    ]

                Pages.Login ->
                    []

                Pages.Settings ->
                    [ ( "Overview", Just Pages.Overview ), ( "My Settings", Nothing ) ]

                Pages.NotFound ->
                    [ overviewPage, notFoundPage ]
    in
    pages
