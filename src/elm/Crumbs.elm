{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Crumbs exposing (view)

import Html exposing (Html, a, li, ol, text)
import Html.Attributes exposing (attribute)
import Pages exposing (Page(..), toRoute)
import Routes exposing (Route(..))
import Tuple exposing (first, second)
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

        pages =
            case page of
                Pages.Overview ->
                    [ overviewPage ]

                Pages.AddRepositories ->
                    [ overviewPage, accountPage, addRepositoriesPage ]

                Pages.RepoSettings org repo ->
                    let
                        organizationPage =
                            ( org, Nothing )

                        repoBuilds =
                            ( repo, Just <| Pages.RepositoryBuilds org repo )
                    in
                    [ overviewPage, organizationPage, repoBuilds, repoSettings ]

                Pages.RepositoryBuilds org repo ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewPage, organizationPage, ( repo, Just <| Pages.RepositoryBuilds org repo ) ]

                Pages.Build org repo buildNumber ->
                    let
                        organizationPage =
                            ( org, Nothing )
                    in
                    [ overviewPage, organizationPage, ( repo, Just <| Pages.RepositoryBuilds org repo ), ( "#" ++ buildNumber, Just <| Pages.Build org repo buildNumber ) ]

                Pages.NotFound ->
                    [ overviewPage, notFoundPage ]

                _ ->
                    []
    in
    pages
