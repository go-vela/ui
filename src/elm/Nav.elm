{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Nav exposing (Msgs, view)

import Browser.Events exposing (Visibility(..))
import Crumbs
import Favorites exposing (ToggleFavorite, isFavorited, starToggle)
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , nav
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , disabled
        , href
        )
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Pages exposing (Page(..))
import Pages.Builds exposing (view)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , CurrentUser
        , Engine
        , Org
        , Repo
        , SecretType
        , SourceRepositories
        )


type alias PartialModel a =
    { a
        | page : Page
        , user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
        , build : WebData Build
    }


type alias Msgs msg =
    { fetchSourceRepos : msg
    , toggleFavorite : ToggleFavorite msg
    , refreshSettings : Org -> Repo -> msg
    , refreshHooks : Org -> Repo -> msg
    , refreshSecrets : Engine -> SecretType -> Org -> Repo -> msg
    , restartBuild : Org -> Repo -> BuildNumber -> msg
    }


{-| view : uses current state to render navigation, such as breadcrumb
-}
view : PartialModel a -> Msgs msg -> Html msg
view model msgs =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        [ Crumbs.view model.page
        , navButton model msgs
        ]


{-| navButton : uses current page to build the commonly used button on the right side of the nav
-}
navButton : PartialModel a -> Msgs msg -> Html msg
navButton model { fetchSourceRepos, toggleFavorite, refreshSettings, refreshHooks, refreshSecrets, restartBuild } =
    case model.page of
        Pages.Overview ->
            a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "source-repos"
                , Routes.href <| Routes.SourceRepositories
                ]
                [ text "Source Repositories" ]

        Pages.SourceRepositories ->
            button
                [ classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick fetchSourceRepos
                , disabled (model.sourceRepos == Loading)
                , Util.testAttribute "refresh-source-repos"
                ]
                [ case model.sourceRepos of
                    Loading ->
                        text "Loading…"

                    _ ->
                        text "Refresh List"
                ]

        Pages.RepositoryBuilds org repo _ _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.RepoSettings org repo ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.OrgSecrets engine org _ _ ->
            div [ class "buttons" ]
                [ button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshSecrets engine Vela.OrgSecret org "*"
                    , Util.testAttribute "refresh-repo-settings"
                    ]
                    [ text "Refresh"
                    ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Routes.href <|
                        Routes.AddOrgSecret engine org
                    ]
                    [ text "Add Org Secret" ]
                ]

        Pages.RepoSecrets engine org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.SharedSecrets engine org team _ _ ->
            div [ class "buttons" ]
                [ button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshSecrets engine Vela.SharedSecret org team
                    , Util.testAttribute "refresh-repo-settings"
                    ]
                    [ text "Refresh"
                    ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Routes.href <|
                        Routes.AddOrgSecret engine org
                    ]
                    [ text "Add Org Secret" ]
                ]

        Pages.Build org repo buildNumber _ ->
            button
                [ classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick <| restartBuild org repo buildNumber
                , Util.testAttribute "restart-build"
                ]
                [ text "Restart Build"
                ]

        Pages.Hooks org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        _ ->
            text ""
