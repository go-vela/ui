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
        ( BuildNumber
        , CurrentUser
        , Engine
        , Org
        , Repo
        , SourceRepositories
        , Type
        )


type alias PartialModel a =
    { a
        | page : Page
        , user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
    }


type alias Msgs msg =
    { fetchSourceRepos : msg
    , toggleFavorite : ToggleFavorite msg
    , refreshSettings : Org -> Repo -> msg
    , refreshHooks : Org -> Repo -> msg
    , refreshSecrets : Engine -> Type -> Org -> Repo -> msg
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
            div [ class "buttons" ]
                [ starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-secrets-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.RepoSecrets "native" org repo Nothing Nothing
                    ]
                    [ text "Secrets" ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-hooks-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.Hooks org repo Nothing Nothing
                    ]
                    [ text "Hooks" ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-settings-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.RepoSettings org repo
                    ]
                    [ text "Settings" ]
                ]

        Pages.RepoSettings org repo ->
            div [ class "buttons" ]
                [ starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-secrets-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.RepoSecrets "native" org repo Nothing Nothing
                    ]
                    [ text "Secrets" ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-hooks-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.Hooks org repo Nothing Nothing
                    ]
                    [ text "Hooks" ]
                , button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshSettings org repo
                    , Util.testAttribute "refresh-repo-settings"
                    ]
                    [ text "Refresh"
                    ]
                ]

        Pages.OrgSecrets engine org _ _ ->
            div [ class "buttons" ]
                [ button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshSecrets engine "org" org "*"
                    , Util.testAttribute "refresh-repo-settings"
                    ]
                    [ text "Refresh"
                    ]
                ]

        Pages.RepoSecrets engine org repo _ _ ->
            div [ class "buttons" ]
                [ starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-hooks-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.Hooks org repo Nothing Nothing
                    ]
                    [ text "Hooks" ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-settings-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.RepoSettings org repo
                    ]
                    [ text "Settings" ]
                , button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshSecrets engine "repo" org repo
                    , Util.testAttribute "refresh-repo-settings"
                    ]
                    [ text "Refresh"
                    ]
                ]

        Pages.SharedSecrets engine org team _ _ ->
            div [ class "buttons" ]
                [ button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshSecrets engine "shared" org team
                    , Util.testAttribute "refresh-repo-settings"
                    ]
                    [ text "Refresh"
                    ]
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
            div [ class "buttons" ]
                [ starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-secrets-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.RepoSecrets "native" org repo Nothing Nothing
                    ]
                    [ text "Secrets" ]
                , a
                    [ class "button"
                    , class "-outline"
                    , Util.testAttribute <| "goto-repo-settings-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.RepoSettings org repo
                    ]
                    [ text "Settings" ]
                , button
                    [ classList
                        [ ( "button", True )
                        , ( "-outline", True )
                        ]
                    , onClick <| refreshHooks org repo
                    , Util.testAttribute "refresh-repo-hooks"
                    ]
                    [ text "Refresh"
                    ]
                ]

        _ ->
            text ""
