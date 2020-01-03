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
        , disabled
        )
import Html.Events exposing (onClick)
import List
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import Util
import Vela exposing (Repositories, Repository)


{-| recordsGroupBy takes a list of records and groups them by the provided key

    recordsGroupBy .lastname listOfFullNames

-}
recordsGroupBy : (a -> comparable) -> List a -> Dict comparable (List a)
recordsGroupBy key recordList =
    List.foldr (\x acc -> Dict.update (key x) (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just) acc) Dict.empty recordList


view : WebData Repositories -> Html msg
view currentRepos =
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
                        |> viewCurrentRepoListByOrg

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


viewSingleRepo : Repository -> Html msg
viewSingleRepo repo =
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


viewOrg : String -> Repositories -> Html msg
viewOrg org repos =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map viewSingleRepo repos
            )
        ]


viewCurrentRepoListByOrg : Dict String Repositories -> Html msg
viewCurrentRepoListByOrg repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg org repos)
        |> div [ class "repo-list" ]
