{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Home exposing (view)

import Dict exposing (Dict)
import Favorites exposing (ToggleFavorite, isFavorited, starToggle)
import Html
    exposing
        ( Html
        , a
        , br
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
import SvgBuilder
import Util
import Vela
    exposing
        ( CurrentUser
        )


view : WebData CurrentUser -> ToggleFavorite msg -> Html msg
view user toggleFavorite =
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
    div [ Util.testAttribute "overview" ]
        [ case user of
            Success u ->
                if List.length u.favorites > 0 then
                    u.favorites
                        |> recordsGroupByOrg
                        |> viewCurrentRepoListByOrg user toggleFavorite

                else
                    blankMessage

            Loading ->
                div []
                    [ h1 [] [ text "Loading your Repositories", span [ class "loading-ellipsis" ] [] ]
                    ]

            NotAsked ->
                blankMessage

            Failure _ ->
                text ""
        ]


viewCurrentRepoListByOrg : WebData CurrentUser -> ToggleFavorite msg -> Dict String (List String) -> Html msg
viewCurrentRepoListByOrg user toggleFavorite repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, favorites ) -> viewOrg user org toggleFavorite favorites)
        |> div [ class "repo-list" ]


viewOrg : WebData CurrentUser -> String -> ToggleFavorite msg -> List String -> Html msg
viewOrg user org toggleFavorite favorites =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepo user toggleFavorite) favorites
            )
        ]


viewSingleRepo : WebData CurrentUser -> ToggleFavorite msg -> String -> Html msg
viewSingleRepo user toggleFavorite favorite =
    let
        ( org, repo ) =
            ( Maybe.withDefault "" <| List.Extra.getAt 0 <| String.split "/" favorite
            , Maybe.withDefault "" <| List.Extra.getAt 1 <| String.split "/" favorite
            )
    in
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo ]
        , div [ class "buttons" ]
            [ starToggle org repo toggleFavorite <| isFavorited user <| org ++ "/" ++ repo
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


recordsGroupByOrg : List String -> Dict String (List String)
recordsGroupByOrg recordList =
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
        List.sort recordList
