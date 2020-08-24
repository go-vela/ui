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

        testAttribute =
            Util.testAttribute <| Util.formatTestTag <| "crumb-" ++ link
    in
    case second crumb of
        Nothing ->
            li [ testAttribute ] [ text link ]

        Just page ->
            if page == currentPage then
                li [ testAttribute, attribute "aria-current" "page" ] [ text link ]

            else
                li [ testAttribute ] [ a [ Routes.href <| toRoute page ] [ text link ] ]



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

        addRepositoriesPage =
            ( "Add Repositories", Just Pages.AddRepositories )

        notFoundPage =
            ( "Not Found", Nothing )

        repoSettings =
            ( "Settings", Nothing )

        secrets =
            ( "Secrets", Nothing )

        pages =
            case page of
                Pages.Overview ->
                    [ overviewPage ]

                Pages.AddRepositories ->
                    [ overviewPage, accountPage, addRepositoriesPage ]

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

                        pageNumber =
                            pageToString maybePage

                        orgSecrets =
                            ( org ++ pageNumber, Nothing )
                    in
                    [ overviewPage, orgSecrets, ("Org Secrets", Nothing) ]

                Pages.RepoSecrets _ org repo maybePage _ ->
                    let

                        orgSecrets =
                            ( org, Nothing)

                        pageNumber =
                            pageToString maybePage

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )

                    in
                    [ overviewPage, orgSecrets, repoBuilds, ("Repo Secrets", Nothing) ]

                Pages.SharedSecrets _ org team maybePage _ ->
                    let
                        orgSecrets =
                            ( org,  Nothing )

                        pageNumber =
                            pageToString maybePage

                        teamSecrets =
                            ( team ++ pageNumber, Nothing )
                    in
                    [ overviewPage, orgSecrets, teamSecrets, ( "Shared Secrets", Nothing) ]

                Pages.AddOrgSecret _ org ->
                    let

                        orgSecrets =
                            ( org, Nothing )

                        add =
                            ( "Add Org Secret", Nothing )
                    in
                    [ overviewPage, orgSecrets, add ]

                Pages.AddRepoSecret _ org repo ->
                    let

                        orgSecrets =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )


                        add =
                            ( "Add Repo Secret", Nothing )
                    in
                    [ overviewPage, orgSecrets, repoBuilds, add ]

                Pages.AddSharedSecret _ org team ->
                    let
                        orgSecrets =
                            ( org, Nothing )

                        sharedSecrets =
                            ( team, Nothing )

                        add =
                            ( "Add Shared Secret", Nothing )
                    in
                    [ overviewPage, orgSecrets, sharedSecrets, add ]

                Pages.OrgSecret _ org name ->
                    let
                        orgSecrets =
                            ( org, Nothing )

                        nameCrumb =
                            ( Maybe.withDefault name <| percentDecode name, Nothing )
                    in
                    [ overviewPage, orgSecrets, ("View Org Secret", Nothing), nameCrumb ]

                Pages.RepoSecret _ org repo name ->
                    let

                        orgSecrets =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo Nothing Nothing Nothing )



                        nameCrumb =
                            ( Maybe.withDefault name <| percentDecode name, Nothing )
                    in
                    [ overviewPage, orgSecrets, repoBuilds, ("View Repo Secret", Nothing), nameCrumb ]

                Pages.SharedSecret _ org team name ->
                    let
                        orgSecrets =
                            ( org, Nothing )

                        sharedSecrets =
                            ( Maybe.withDefault team <| percentDecode team, Nothing )

                        nameCrumb =
                            ( Maybe.withDefault name <| percentDecode name, Nothing )
                    in
                    [ overviewPage, orgSecrets, sharedSecrets, nameCrumb ]

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
