{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Home exposing (view)

import Dict exposing (Dict)
import Favorites exposing (ToggleFavorite, starToggle)
import Html
    exposing
        ( Html
        , a
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import List
import List.Extra
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import Search
    exposing
        ( SimpleSearch
        , homeSearchBar
        , toLowerContains
        )
import SvgBuilder
import Util
import Vela
    exposing
        ( CurrentUser
        , Favorites
        )


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : WebData CurrentUser -> String -> ToggleFavorite msg -> SimpleSearch msg -> Html msg
view user filter toggleFavorite search =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p [] [ text "To have Vela start building your projects we need to get them enabled." ]
                , p []
                    [ text "To display a repository here, click the "
                    , SvgBuilder.star False
                    ]
                , p [] [ text "Add repositories from your GitHub account to Vela now!" ]
                , a [ class "button", Routes.href Routes.AddRepositories ] [ text "Add Repositories" ]
                ]
    in
    div [ Util.testAttribute "overview" ] <|
        case user of
            Success u ->
                if List.length u.favorites > 0 then
                    [ homeSearchBar filter search
                    , viewFavorites u.favorites filter toggleFavorite
                    ]

                else
                    [ blankMessage ]

            Loading ->
                [ h1 [] [ text "Loading your Repositories", span [ class "loading-ellipsis" ] [] ] ]

            NotAsked ->
                [ text "" ]

            Failure _ ->
                [ text "" ]


{-| viewFavorites : takes favorites, user search input and favorite action and renders favorites
-}
viewFavorites : Favorites -> String -> ToggleFavorite msg -> Html msg
viewFavorites favorites filter toggleFavorite =
    -- no search input
    if String.isEmpty filter then
        favorites
            |> toOrgFavorites
            |> viewFavoritesByOrg toggleFavorite

    else
        viewFilteredFavorites favorites filter toggleFavorite


{-| viewFilteredFavorites : takes favorites, user search input and favorite action and renders favorites
-}
viewFilteredFavorites : Favorites -> String -> ToggleFavorite msg -> Html msg
viewFilteredFavorites favorites filter toggleFavorite =
    let
        filteredRepos =
            favorites
                |> List.filter (\repo -> toLowerContains filter repo)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos
                |> List.map (viewFavorite favorites toggleFavorite)

        else
            -- No repos matched the search
            [ div [ class "no-results" ] [ text "No results" ] ]


{-| viewFavoritesByOrg : takes favorites dictionary and favorite action and renders favorites by org
-}
viewFavoritesByOrg : ToggleFavorite msg -> Dict String Favorites -> Html msg
viewFavoritesByOrg toggleFavorite orgFavorites =
    orgFavorites
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, favs ) -> viewOrg org toggleFavorite favs)
        |> div [ class "repo-list" ]


{-| toOrgFavorites : takes favorites and organizes them by org in a dict
-}
toOrgFavorites : Favorites -> Dict String Favorites
toOrgFavorites favorites =
    List.foldr
        (\x acc ->
            Dict.update
                (Maybe.withDefault "" <|
                    List.head <|
                        String.split "/" x
                )
                (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just)
                acc
        )
        Dict.empty
    <|
        List.sort favorites


{-| viewOrg : takes org, favorites and favorite action and renders favorites by org
-}
viewOrg : String -> ToggleFavorite msg -> Favorites -> Html msg
viewOrg org toggleFavorite favorites =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewFavorite favorites toggleFavorite) favorites
            )
        ]


{-| viewFavorite : takes favorites and favorite action and renders single favorite
-}
viewFavorite : Favorites -> ToggleFavorite msg -> String -> Html msg
viewFavorite favorites toggleFavorite favorite =
    let
        ( org, repo ) =
            ( Maybe.withDefault "" <| List.Extra.getAt 0 <| String.split "/" favorite
            , Maybe.withDefault "" <| List.Extra.getAt 1 <| String.split "/" favorite
            )
    in
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo ]
        , div [ class "buttons" ]
            [ starToggle org repo toggleFavorite <| List.member favorite favorites
            , a
                [ class "button"
                , class "-outline"
                , Routes.href <| Routes.Settings org repo
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks org repo Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds org repo Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]
