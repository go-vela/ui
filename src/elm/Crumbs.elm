{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Crumbs exposing (view)

import Html exposing (Html, a, li, ol, text)
import Html.Attributes exposing (attribute)
import Pages exposing (Page(..), toRoute)
import Routes exposing (Route(..))
import Tuple exposing (first, second)
import Url exposing (percentDecode)
import Util



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

        repoSettings =
            ( "Settings", Nothing )

        pages =
            case page of
                Pages.Overview ->
                    [ overviewPage ]

                Pages.SourceRepositories ->
                    [ overviewPage, accountPage, sourceRepositoriesPage ]

                Pages.Hooks org repo maybePage _ ->
                    let
                        organizationPage =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        pageNumber =
                            pageToString maybePage
                    in
                    [ overviewPage, organizationPage, repoBuilds, ( "Hooks" ++ pageNumber, Nothing ) ]

                Pages.RepoSettings org repo ->
                    let
                        organizationPage =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )
                    in
                    [ overviewPage, organizationPage, repoBuilds, repoSettings ]

                Pages.OrgSecrets _ org maybePage _ ->
                    let
                        orgPage =
                            ( org, Nothing )

                        orgSecrets =
                            ( "Org Secrets" ++ pageToString maybePage, Nothing )
                    in
                    [ overviewPage, orgPage, orgSecrets ]

                Pages.RepoSecrets _ org repo maybePage _ ->
                    let
                        orgPage =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        repoSecrets =
                            ( "Repo Secrets" ++ pageToString maybePage, Nothing )
                    in
                    [ overviewPage, orgPage, repoBuilds, repoSecrets ]

                Pages.SharedSecrets _ org team maybePage _ ->
                    let
                        orgPage =
                            ( org, Nothing )

                        teamPage =
                            ( team, Nothing )

                        sharedSecrets =
                            ( "Shared Secrets" ++ pageToString maybePage, Nothing )
                    in
                    [ overviewPage, orgPage, teamPage, sharedSecrets ]

                Pages.AddOrgSecret engine org ->
                    let
                        orgPage =
                            ( org, Nothing )

                        orgSecrets =
                            ( "Org Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )

                        add =
                            ( "Add", Nothing )
                    in
                    [ overviewPage, orgPage, orgSecrets, add ]

                Pages.AddRepoSecret engine org repo ->
                    let
                        orgPage =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        repoSecrets =
                            ( "Repo Secrets", Just <| Pages.RepoSecrets engine org repo Nothing Nothing )

                        add =
                            ( "Add", Nothing )
                    in
                    [ overviewPage, orgPage, repoBuilds, repoSecrets, add ]

                Pages.AddSharedSecret engine org team ->
                    let
                        orgPage =
                            ( org, Nothing )

                        teamPage =
                            ( team, Nothing )

                        sharedSecrets =
                            ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )

                        add =
                            ( "Add", Nothing )
                    in
                    [ overviewPage, orgPage, teamPage, sharedSecrets, add ]

                Pages.OrgSecret engine org name ->
                    let
                        orgPage =
                            ( org, Nothing )

                        orgSecrets =
                            ( "Org Secrets", Just <| Pages.OrgSecrets engine org Nothing Nothing )

                        nameCrumb =
                            ( name, Nothing )
                    in
                    [ overviewPage, orgPage, orgSecrets, nameCrumb ]

                Pages.RepoSecret engine org repo name ->
                    let
                        orgPage =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                        repoSecrets =
                            ( "Repo Secrets", Just <| Pages.RepoSecrets engine org repo Nothing Nothing )

                        nameCrumb =
                            ( name, Nothing )
                    in
                    [ overviewPage, orgPage, repoBuilds, repoSecrets, nameCrumb ]

                Pages.SharedSecret engine org team name ->
                    let
                        orgPage =
                            ( org, Nothing )

                        teamPage =
                            ( team, Nothing )

                        sharedSecrets =
                            ( "Shared Secrets", Just <| Pages.SharedSecrets engine org team Nothing Nothing )

                        nameCrumb =
                            ( name, Nothing )
                    in
                    [ overviewPage, orgPage, teamPage, sharedSecrets, nameCrumb ]

                Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
                    let
                        organizationPage =
                            ( org, Nothing )

                        pageNumber =
                            pageToString maybePage
                    in
                    [ overviewPage, organizationPage, ( repo ++ pageNumber, Just <| Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ) ]

                Pages.Build org repo buildNumber logFocus ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewPage, organizationPage, ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing ), ( "#" ++ buildNumber, Just <| Pages.Build org repo buildNumber logFocus ) ]

                Pages.Login ->
                    []

                Pages.Logout ->
                    []

                Pages.Settings ->
                    [ ( "Overview", Just Pages.Overview ), ( "My Settings", Nothing ) ]

                Pages.NotFound ->
                    [ overviewPage, notFoundPage ]

                Pages.Authenticate _ ->
                    []
    in
    pages


{-| renderPageNumber : small helper to turn page number to a string to display in crumbs
-}
pageToString : Maybe Int -> String
pageToString maybePage =
    case maybePage of
        Nothing ->
            ""

        Just num ->
            if num > 1 then
                " (page " ++ String.fromInt num ++ ")"

            else
                ""
