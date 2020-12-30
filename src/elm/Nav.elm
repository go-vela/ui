{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Nav exposing (Msgs, viewBuildHistory, viewNav, viewUtil)

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
        , em
        , li
        , nav
        , p
        , span
        , text
        , ul
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
import Svg.Attributes
import SvgBuilder exposing (recentBuildStatusToIcon)
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


{-| Tab : record to represent information used by page navigation tab
-}
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
                viewBuildHistory model.time model.zone model.page 10 rm

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
viewTabs : List Tab -> String -> Html msg
viewTabs tabs testLabel =
    tabs
        |> List.map viewTab
        |> List.intersperse viewSpacer
        |> (\t -> t ++ [ viewFiller ])
        |> div [ class "jump-bar", Util.testAttribute testLabel ]


{-| viewTab : takes single tab record and renders jump link, uses current page to display conditional style
-}
viewTab : Tab -> Html msg
viewTab { name, currentPage, toPage } =
    a
        [ class "jump"
        , viewingTab currentPage toPage
        , Routes.href <| Pages.toRoute toPage
        , Util.testAttribute <| "jump-" ++ name
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
    viewTabs tabs "jump-bar-repo"



-- BUILD TODO


viewBuildTabs : RepoModel -> Page -> Html msg
viewBuildTabs rm currentPage =
    let
        tabs =
            []
    in
    viewTabs tabs "build"



-- RECENT BUILDS


{-| viewBuildHistory : takes the 10 most recent builds and renders icons/links back to them as a widget at the top of the Build page
-}
viewBuildHistory : Posix -> Zone -> Page -> Int -> RepoModel -> Html msg
viewBuildHistory now timezone page limit rm =
    let
        org =
            rm.org

        repo =
            rm.name

        builds =
            rm.builds.builds

        buildNumber =
            case page of
                Pages.Build _ _ b _ ->
                    Maybe.withDefault -1 <| String.toInt b

                _ ->
                    -1
    in
    case builds of
        RemoteData.Success blds ->
            if List.length blds > 0 then
                div [ class "build-history" ]
                    [ p [ class "build-history-title" ] [ text "Recent Builds" ]
                    , ul [ Util.testAttribute "build-history", class "previews" ] <|
                        List.indexedMap (viewRecentBuild now timezone page org repo buildNumber) <|
                            List.take limit blds
                    ]

            else
                text ""

        RemoteData.Loading ->
            div [ class "build-history" ] [ Util.smallLoader ]

        RemoteData.NotAsked ->
            div [ class "build-history" ] [ Util.smallLoader ]

        _ ->
            text ""


{-| viewRecentBuild : takes recent build and renders status and link to build as a small icon widget

    focusing or hovering the recent build icon will display a build info tooltip

-}
viewRecentBuild : Posix -> Zone -> Page -> Org -> Repo -> Int -> Int -> Build -> Html msg
viewRecentBuild now timezone page org repo buildNumber idx build =
    li [ class "recent-build" ]
        [ recentBuildLink page org repo buildNumber build idx
        , recentBuildTooltip now timezone build
        ]


{-| recentBuildLink : takes time info and build and renders line for redirecting to recent build

    focusing and hovering this element will display the tooltip

-}
recentBuildLink : Page -> Org -> Repo -> Int -> Build -> Int -> Html msg
recentBuildLink page org repo buildNumber build idx =
    let
        icon =
            recentBuildStatusToIcon build.status idx

        currentBuildClass =
            if buildNumber == build.number then
                class "-current"

            else if buildNumber > build.number then
                class "-older"

            else
                class ""
    in
    a
        [ class "recent-build-link"
        , Util.testAttribute <| "recent-build-link-" ++ String.fromInt buildNumber
        , currentBuildClass
        , case page of
            Pages.Build _ _ _ _ ->
                Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing

            _ ->
                Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing
        , attribute "aria-label" <| "go to previous build number " ++ String.fromInt build.number
        ]
        [ icon
        ]


{-| recentBuildTooltip : takes time info and build and renders tooltip for viewing recent build info

    tooltip is visible when the recent build link is focused or hovered

-}
recentBuildTooltip : Posix -> Zone -> Build -> Html msg
recentBuildTooltip now timezone build =
    div [ class "recent-build-tooltip", Util.testAttribute "build-history-tooltip" ]
        [ ul [ class "info" ]
            [ li [ class "line" ]
                [ span [ class "number" ] [ text <| String.fromInt build.number ]
                , em [] [ text build.event ]
                ]
            , viewTooltipField "started:" <| Util.dateToHumanReadable timezone build.started
            , viewTooltipField "finished:" <| Util.dateToHumanReadable timezone build.finished
            , viewTooltipField "duration:" <| Util.formatRunTime now build.started build.finished
            , viewTooltipField "worker:" build.host
            , viewTooltipField "commit:" <| Util.trimCommitHash build.commit
            , viewTooltipField "branch:" build.branch
            ]
        ]


{-| viewTooltipField : takes build field key and value, renders field in the tooltip
-}
viewTooltipField : String -> String -> Html msg
viewTooltipField key value =
    li [ class "line" ] [ span [] [ text key ], text value ]
