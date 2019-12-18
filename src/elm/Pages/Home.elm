{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Home exposing (view)

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
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import SvgBuilder exposing (favoritesStar)
import Util
import Vela exposing (Favorite, Favorites, FavoritesModel, Org, Repo, Repositories, Repository)


view : WebData Repositories -> FavoritesModel -> (Repository -> msg) -> (Org -> Repo -> msg) -> Html msg
view repos favoritesModel removeRepo favoriteRepo =
    div [] [ viewOverview repos removeRepo, viewFavorites favoritesModel favoriteRepo ]


viewFavorites : FavoritesModel -> (Org -> Repo -> msg) -> Html msg
viewFavorites favoritesModel favoriteRepo =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "favorites" ]
                [ h1 [] [ text "You have no favorites!" ]
                , p []
                    [ text "To display your projects here we need to get them favorited."
                    , br [] []
                    , text "Favorite a repository by clicking the star"
                    , SvgBuilder.favoritesStar [] False
                    , text "in the top right of the repository builds page!"
                    ]
                ]
    in
    div []
        [ case favoritesModel.favorites of
            Success favorites ->
                if List.length favorites > 0 then
                    favorites
                        |> recordsGroupByFav .org
                        |> viewCurrentRepoListByOrgFav favoriteRepo

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
recordsGroupByFav : (a -> comparable) -> List a -> Dict comparable (List a)
recordsGroupByFav key recordList =
    List.foldr (\x acc -> Dict.update (key x) (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just) acc) Dict.empty recordList


viewSingleRepoFav : (Org -> Repo -> msg) -> Favorite -> Html msg
viewSingleRepoFav action repo =
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.repo_name ]
        , div [ class "-actions" ]
            [ a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.repo_name
                ]
                [ text "Settings" ]
            , button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| action repo.org repo.repo_name ] [ text "Remove" ]
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks repo.org repo.repo_name Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "-btn"
                , class "-solid"
                , class "-view"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds repo.org repo.repo_name Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]


{-| recordsGroupBy takes a list of records and groups them by the provided key

    recordsGroupBy .lastname listOfFullNames

-}
recordsGroupBy : (a -> comparable) -> List a -> Dict comparable (List a)
recordsGroupBy key recordList =
    List.foldr (\x acc -> Dict.update (key x) (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just) acc) Dict.empty recordList


viewOrgFav : String -> Favorites -> (Org -> Repo -> msg) -> Html msg
viewOrgFav org repos action =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepoFav action) repos
            )
        ]


viewCurrentRepoListByOrgFav : (Org -> Repo -> msg) -> Dict String Favorites -> Html msg
viewCurrentRepoListByOrgFav action repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrgFav org repos action)
        |> div [ class "repo-list" ]


viewOverview : WebData Repositories -> (Repository -> msg) -> Html msg
viewOverview currentRepos removeRepo =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p []
                    [ text "To have Vela start building your projects we need to get them added."
                    , br [] []
                    , text "Add repositories from your GitHub account to Vela now!"
                    ]
                , a [ class "-btn", class "-solid", class "-overview", Routes.href Routes.AddRepositories ] [ text "Add Repositories" ]
                ]
    in
    div []
        [ case currentRepos of
            Success repos ->
                let
                    activeRepos : Repositories
                    activeRepos =
                        List.filter .active repos
                in
                if List.length activeRepos > 0 then
                    activeRepos
                        |> recordsGroupBy .org
                        |> viewCurrentRepoListByOrg removeRepo

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


viewSingleRepo : (Repository -> msg) -> Repository -> Html msg
viewSingleRepo removeRepo repo =
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "-actions" ]
            [ a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.name
                ]
                [ text "Settings" ]
            , button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| removeRepo repo ] [ text "Remove" ]
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


viewOrg : (Repository -> msg) -> String -> Repositories -> Html msg
viewOrg removeRepo org repos =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepo removeRepo) repos
            )
        ]


viewCurrentRepoListByOrg : (Repository -> msg) -> Dict String Repositories -> Html msg
viewCurrentRepoListByOrg removeRepo repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg removeRepo org repos)
        |> div [ class "repo-list" ]
