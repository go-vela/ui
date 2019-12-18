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
import Vela exposing (Favorite, Favorites, FavoritesModel, Org, Repo, Repositories, Repository)


view : FavoritesModel -> (Org -> Repo -> msg) -> Html msg
view model action =
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
        [ case model.favorites of
            Success favorites ->
                if List.length favorites > 0 then
                    favorites
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


viewSingleRepo : (Org -> Repo -> msg) -> Favorite -> Html msg
viewSingleRepo action repo =
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


viewOrg : String -> Favorites -> (Org -> Repo -> msg) -> Html msg
viewOrg org repos action =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepo action) repos
            )
        ]


viewCurrentRepoListByOrg : (Org -> Repo -> msg) -> Dict String Favorites -> Html msg
viewCurrentRepoListByOrg action repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg org repos action)
        |> div [ class "repo-list" ]
