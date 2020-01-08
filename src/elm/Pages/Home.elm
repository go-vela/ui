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
import SvgBuilder
import Util
import Vela
    exposing
        ( Repositories
        , Repository
        , ToggleFavorite
        )


view : ToggleFavorite msg -> WebData Repositories -> Html msg
view toggleFavorite currentRepos =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p []
                    [ text "To have Vela start building your projects we need to get them enabled."
                    , br [] []
                    , text "Add repositories from your GitHub account to Vela now!     "
                    , a [ class "-btn", class "-solid", class "-overview", Routes.href Routes.AddRepositories ] [ text "Add Repositories" ]
                    ]
                , p []
                    [ text "Favorite a repository by clicking the"
                    , SvgBuilder.star [] False
                    , text "on the repository's builds page."
                    , br [] []
                    , text "Your favorites will display here!"
                    ]
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
                        |> viewCurrentRepoListByOrg toggleFavorite

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


viewSingleRepo : ToggleFavorite msg -> Repository -> Html msg
viewSingleRepo toggleFavorite repo =
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "-actions" ]
            [ SvgBuilder.star [ onClick <| toggleFavorite repo, Svg.Attributes.class "-cursor" ] repo.active
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.name
                ]
                [ text "Settings" ]
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


viewOrg : String -> ToggleFavorite msg -> Repositories -> Html msg
viewOrg org toggleFavorite repos =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map (viewSingleRepo toggleFavorite) repos
            )
        ]


viewCurrentRepoListByOrg : ToggleFavorite msg -> Dict String Repositories -> Html msg
viewCurrentRepoListByOrg toggleFavorite repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg org toggleFavorite repos)
        |> div [ class "repo-list" ]


{-| recordsGroupBy takes a list of records and groups them by the provided key

    recordsGroupBy .lastname listOfFullNames

-}
recordsGroupBy : (a -> comparable) -> List a -> Dict comparable (List a)
recordsGroupBy key recordList =
    List.foldr (\x acc -> Dict.update (key x) (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just) acc) Dict.empty recordList
