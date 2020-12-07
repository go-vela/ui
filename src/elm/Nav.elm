{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Nav exposing (Msgs, viewNav, viewUtil)

import Browser.Events exposing (Visibility(..))
import Crumbs
import Favorites exposing (ToggleFavorite, isFavorited, starToggle)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , nav
        , span
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
import Pages.Build.View exposing (viewBuildHistory)
import Pages.Builds exposing (view)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import Svg.Attributes
import Time exposing (Posix, Zone)
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , CurrentUser
        , Engine
        , Org
        , Repo
        , RepoModel
        , SecretType
        , SourceRepositories
        )


type alias PartialModel a =
    { a
        | page : Page
        , user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
        , repo : RepoModel
        , time : Posix
        , zone : Zone
    }


type alias Msgs msg =
    { fetchSourceRepos : msg
    , toggleFavorite : ToggleFavorite msg
    , refreshSettings : Org -> Repo -> msg
    , refreshHooks : Org -> Repo -> msg
    , refreshSecrets : Engine -> SecretType -> Org -> Repo -> msg
    , restartBuild : Org -> Repo -> BuildNumber -> msg
    }


type alias Tab =
    { name : String
    , currentPage : Page
    , toPage : Page
    }


{-| viewNav : uses current state to render navigation, such as breadcrumb
-}
viewNav : PartialModel a -> Msgs msg -> Html msg
viewNav model msgs =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        [ Crumbs.view model.page
        , navButtons model msgs
        ]


{-| navButtons : uses current page to build the commonly used button on the right side of the nav
-}
navButtons : PartialModel a -> Msgs msg -> Html msg
navButtons model { fetchSourceRepos, toggleFavorite, refreshSettings, refreshHooks, refreshSecrets, restartBuild } =
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

        Pages.RepoSecrets engine org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.SharedSecrets engine org team _ _ ->
            div [ class "buttons" ]
                [ a
                    [ class "button"
                    , class "-outline"
                    , Routes.href <|
                        Routes.AddSharedSecret engine org team
                    ]
                    [ text "Add Shared Secret" ]
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


{-| viewUtil : uses current state to render navigation in util area below nav
-}
viewUtil : PartialModel a -> Html msg
viewUtil model =
    let
        rm =
            model.repo
    in
    div [ class "util" ]
        [ case model.page of
            Pages.Build _ _ _ _ ->
                viewBuildHistory model.time model.zone model.page model.repo.org model.repo.name model.repo.builds.builds 10

            Pages.RepositoryBuilds org repo _ _ _ ->
                viewRepoTabs rm model.page

            Pages.RepoSecrets engine org repo _ _ ->
                viewRepoTabs rm model.page

            Pages.Hooks org repo _ _ ->
                viewRepoTabs rm model.page

            Pages.RepoSettings org repo ->
                viewRepoTabs rm model.page

            _ ->
                text ""
        ]


{-| viewTabs : takes list of tab records and renders them with spacers and horizontal filler
-}
viewTabs : List Tab -> Html msg
viewTabs tabs =
    tabs
        |> List.map viewTab
        |> List.intersperse viewSpacer
        |> (\t -> t ++ [ viewFiller ])
        |> div [ class "jump-bar" ]


{-| viewTab : takes single tab record and renders jump link, uses current page to display conditional style
-}
viewTab : Tab -> Html msg
viewTab { name, currentPage, toPage } =
    a
        [ class "jump"
        , viewingTab currentPage toPage
        , Routes.href <| Pages.toRoute toPage
        ]
        [ text name ]


{-| viewSpacer : renders horizontal spacer between tabs
-}
viewSpacer : Html msg
viewSpacer =
    span [ class "jump", class "spacer" ] []


{-| viewSpacer : renders horizontal filler to the right of tabs
-}
viewFiller : Html msg
viewFiller =
    span [ class "jump", class "fill" ] []


{-| viewingTab : returns true if user is viewing this tab
-}
viewingTab : Page -> Page -> Html.Attribute msg
viewingTab p1 p2 =
    if Pages.strip p1 == Pages.strip p2 then
        class "current"

    else
        class ""



-- REPO


{-| viewRepoTabs : takes RepoModel and current page and renders navigation tabs
-}
viewRepoTabs : RepoModel -> Page -> Html msg
viewRepoTabs rm currentPage =
    let
        org =
            rm.org

        repo =
            rm.name

        tabs =
            [ Tab "Builds" currentPage <| Pages.RepositoryBuilds org repo rm.builds.maybePage rm.builds.maybePerPage rm.builds.maybeEvent
            , Tab "Secrets" currentPage <| Pages.RepoSecrets "native" org repo Nothing Nothing
            , Tab "Audit" currentPage <| Pages.Hooks org repo rm.hooks.maybePage rm.hooks.maybePerPage
            , Tab "Settings" currentPage <| Pages.RepoSettings org repo
            ]
    in
    viewTabs tabs



-- BUILD TODO
