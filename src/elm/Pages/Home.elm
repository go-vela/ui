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
        , code
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
import Html.Events exposing (onClick)
import List
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import Svg.Attributes
import SvgBuilder exposing (favoritesStar)
import Util
import Vela
    exposing
        ( AddRepo
        , DeactivateRepo
        , Favorite
        , FavoritesModel
        , Org
        , Repo
        , Repositories
        , Repository
        )


view : WebData Repositories -> FavoritesModel -> AddRepo msg -> DeactivateRepo msg -> Html msg
view repos favoritesModel addRepo deactivateRepo =
    div [] [ viewFavorites favoritesModel repos addRepo, viewOverview favoritesModel repos addRepo deactivateRepo ]


numFavorites : FavoritesModel -> Int
numFavorites favoritesModel =
    List.length <| RemoteData.withDefault [] favoritesModel.favorites


viewFavorites : FavoritesModel -> WebData Repositories -> (Org -> Repo -> msg) -> Html msg
viewFavorites favoritesModel repos addRepo =
    let
        noFavorites : Html msg
        noFavorites =
            div [ class "-item" ]
                [ div []
                    [ p []
                        [ p
                            []
                            [ text "You have no favorites! Star a repository by clicking the"
                            , SvgBuilder.favoritesStar [] False
                            , text "next to the repository below, or on the repository's builds page."
                            ]
                        ]
                    ]
                ]

        numFavs =
            numFavorites favoritesModel
    in
    if (List.length <| RemoteData.withDefault [] repos) > 0 then
        div
            [ class "favorites", class "repo-org", Util.testAttribute "repo-org" ]
            [ details [ class "details", class "repo-item", attribute "open" "open" ]
                [ summary [ class "summary" ]
                    [ span [ class "header" ]
                        [ text "Favorites"
                        , if numFavs > 0 then
                            code [ class "repo-count" ] [ text <| Util.pluralize numFavs <| (String.fromInt <| numFavs) ++ " repo" ]

                          else
                            text ""
                        ]
                    ]
                , case favoritesModel.favorites of
                    Success favorites ->
                        if List.length favorites > 0 then
                            div [] <| List.map (viewSearchedFavRepo addRepo) favorites

                        else
                            noFavorites

                    Loading ->
                        div []
                            [ h1 [] [ text "Loading your favorited Repositories", span [ class "loading-ellipsis" ] [] ]
                            ]

                    NotAsked ->
                        noFavorites

                    Failure _ ->
                        text ""
                ]
            ]

    else
        text ""


repoFavorited : Org -> Repo -> FavoritesModel -> Bool
repoFavorited org repo favorites =
    case favorites.favorites of
        Success repos ->
            (\id -> id /= -1) <| .repo_id <| Maybe.withDefault (Favorite -1 -1 "" "") <| List.head <| List.filter (\r -> r.org == org && r.repo_name == repo) repos

        _ ->
            False


{-| viewSearchedFavRepo : renders single repo when searching across favorited repos
-}
viewSearchedFavRepo : AddRepo msg -> Favorite -> Html msg
viewSearchedFavRepo addRepo repo =
    div [ class "-item", class "favorited-repo", Util.testAttribute <| "source-repo-" ++ repo.repo_name ]
        [ div [] [ text <| repo.org ++ "/" ++ repo.repo_name ]
        , div [ class "-actions" ]
            [ SvgBuilder.favoritesStar
                [ Svg.Attributes.class "-cursor"
                , onClick <| addRepo repo.org repo.repo_name
                ]
                True
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.repo_name
                ]
                [ text "Settings" ]

            -- , button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| deactivateRepo repo ] [ text "Remove" ]
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


viewOverview : FavoritesModel -> WebData Repositories -> AddRepo msg -> (Repository -> msg) -> Html msg
viewOverview favoritesModel currentRepos addRepo deactivateRepo =
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
                , a [ class "-btn", class "-solid", class "-overview", Routes.href Routes.AddRepos ] [ text "Add Repositories" ]
                ]

        numFavs =
            numFavorites favoritesModel
    in
    div []
        [ case currentRepos of
            Success repos ->
                let
                    activeRepos : Repositories
                    activeRepos =
                        List.filter (\repo -> not <| repoFavorited repo.org repo.name favoritesModel) <| List.filter .active repos
                in
                if List.length activeRepos > 0 then
                    activeRepos
                        |> recordsGroupBy .org
                        |> viewCurrentRepoListByOrg addRepo deactivateRepo favoritesModel

                else if numFavs == 0 then
                    blankMessage

                else
                    text ""

            Loading ->
                div []
                    [ h1 [] [ text "Loading your Repositories", span [ class "loading-ellipsis" ] [] ]
                    ]

            NotAsked ->
                blankMessage

            Failure _ ->
                text ""
        ]


viewSingleRepo : AddRepo msg -> (Repository -> msg) -> FavoritesModel -> Repository -> Html msg
viewSingleRepo addRepo deactivateRepo favoritesModel repo =
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "-actions" ]
            [ SvgBuilder.favoritesStar
                [ Svg.Attributes.class "-cursor"
                , onClick <| addRepo repo.org repo.name
                ]
              <|
                repoFavorited repo.org repo.name favoritesModel
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.name
                ]
                [ text "Settings" ]
            , button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| deactivateRepo repo ] [ text "Remove" ]
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


viewOrg : AddRepo msg -> (Repository -> msg) -> String -> Repositories -> FavoritesModel -> Html msg
viewOrg addRepo deactivateRepo org repos favoritesModel =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepo addRepo deactivateRepo favoritesModel) repos
            )
        ]


viewCurrentRepoListByOrg : AddRepo msg -> (Repository -> msg) -> FavoritesModel -> Dict String Repositories -> Html msg
viewCurrentRepoListByOrg addRepo deactivateRepo favoritesModel repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg addRepo deactivateRepo org repos favoritesModel)
        |> div [ class "repo-list" ]
