{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Favorites exposing (view)

import Dict exposing (Dict)
import Html
    exposing
        ( Html
        , a
        , br
        , button
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
import Html.Events exposing (onClick, onInput)
import List
import RemoteData exposing (RemoteData(..))
import Routes
import Svg.Attributes
import SvgBuilder exposing (favoritesStar)
import Util
import Vela exposing (FavoritesModel, Repositories, Repository)


view : FavoritesModel -> (Repository -> msg) -> Html msg
view model action =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p []
                    [ text "To display your projects here we need to get them favorited."
                    , br [] []
                    , text "Favorite a repository by clicking the star in the top right of the page!"
                    ]
                ]
    in
    div []
        [ case model.favorites of
            Success repos ->
                let
                    activeRepos : Repositories
                    activeRepos =
                        repos
                in
                if List.length activeRepos > 0 then
                    activeRepos
                        |> recordsGroupBy .org
                        |> viewCurrentRepoListByOrg action

                else
                    blankMessage

            Loading ->
                div []
                    [ h1 [] [ text "Loading your favorited Repositories", span [ class "loading-ellipsis" ] [] ]
                    ]

            NotAsked ->
                blankMessage

            Failure _ ->
                text ""
        ]


{-| recordsGroupBy takes a list of records and groups them by the provided key

    recordsGroupBy .lastname listOfFullNames

-}
recordsGroupBy : (a -> comparable) -> List a -> Dict comparable (List a)
recordsGroupBy key recordList =
    List.foldr (\x acc -> Dict.update (key x) (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just) acc) Dict.empty recordList


viewSingleRepo : (Repository -> msg) -> Repository -> Html msg
viewSingleRepo action repo =
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "-actions" ]
            [ favoritesStar [ onClick <| action repo ] False
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.name
                ]
                [ text "Settings" ]
            , button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| action repo ] [ text "Remove" ]
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks repo.org repo.name Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "-btn"
                , class "-solid"
                , class "-view"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]


viewOrg : String -> Repositories -> (Repository -> msg) -> Html msg
viewOrg org repos action =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepo action) repos
            )
        ]


viewCurrentRepoListByOrg : (Repository -> msg) -> Dict String Repositories -> Html msg
viewCurrentRepoListByOrg action repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg org repos action)
        |> div [ class "repo-list" ]
