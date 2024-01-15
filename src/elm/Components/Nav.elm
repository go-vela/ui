{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Nav exposing (Msgs, Tab, view, viewTabs)

import Crumbs
import Favorites exposing (ToggleFavorite, isFavorited, starToggle)
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
        )
import Html.Events exposing (onClick)
import Pages exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Routes
import Shared
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , Engine
        , Org
        , Repo
        , RepoModel
        , SecretType
        )


type alias Msgs msg =
    { fetchSourceRepos : msg
    , toggleFavorite : ToggleFavorite msg
    , refreshSettings : Org -> Repo -> msg
    , refreshHooks : Org -> Repo -> msg
    , refreshSecrets : Engine -> SecretType -> Org -> Repo -> msg
    , approveBuild : Org -> Repo -> BuildNumber -> msg
    , restartBuild : Org -> Repo -> BuildNumber -> msg
    , cancelBuild : Org -> Repo -> BuildNumber -> msg
    }


{-| Tab : record to represent information used by page navigation tab
-}
type alias Tab =
    { name : String
    , currentPage : Page
    , toPage : Page
    , isAlerting : Bool
    , show : Bool
    }


view : Shared.Model -> Route () -> List (Html msg) -> Html msg
view shared route buttons =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        (Crumbs.view route.path
            :: buttons
        )


navButtonsLegacy : Shared.Model -> Msgs msg -> Page -> Html msg
navButtonsLegacy shared { fetchSourceRepos, toggleFavorite, approveBuild, restartBuild, cancelBuild } legacyPage =
    case legacyPage of
        Pages.Overview ->
            a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "source-repos"
                , Routes.href <| Routes.SourceRepositories
                ]
                [ text "Source Repositories" ]

        Pages.OrgRepositories _ _ _ ->
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

                -- , disabled (shared.sourceRepos == Loading)
                , Util.testAttribute "refresh-source-repos"
                ]
                [-- case shared.sourceRepos of
                 -- Loading ->
                 --     text "Loading…"
                 -- _ ->
                 --     text "Refresh List"
                ]

        Pages.RepositoryBuilds org repo _ _ _ ->
            starToggle org repo toggleFavorite <| isFavorited shared.user <| org ++ "/" ++ repo

        Pages.RepositoryDeployments org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited shared.user <| org ++ "/" ++ repo

        Pages.Schedules org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited shared.user <| org ++ "/" ++ repo

        Pages.RepoSettings org repo ->
            starToggle org repo toggleFavorite <| isFavorited shared.user <| org ++ "/" ++ repo

        Pages.RepoSecrets _ org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited shared.user <| org ++ "/" ++ repo

        Pages.Build org repo _ _ ->
            div [ class "buttons" ]
                [ approveBuildButton org repo shared.repo.build.build approveBuild
                , cancelBuildButton org repo shared.repo.build.build cancelBuild
                , restartBuildButton org repo shared.repo.build.build restartBuild
                ]

        Pages.BuildServices org repo _ _ ->
            div [ class "buttons" ]
                [ approveBuildButton org repo shared.repo.build.build approveBuild
                , cancelBuildButton org repo shared.repo.build.build cancelBuild
                , restartBuildButton org repo shared.repo.build.build restartBuild
                ]

        Pages.BuildPipeline org repo _ _ _ ->
            div [ class "buttons" ]
                [ approveBuildButton org repo shared.repo.build.build approveBuild
                , cancelBuildButton org repo shared.repo.build.build cancelBuild
                , restartBuildButton org repo shared.repo.build.build restartBuild
                ]

        Pages.BuildGraph org repo _ ->
            div [ class "buttons" ]
                [ cancelBuildButton org repo shared.repo.build.build cancelBuild
                , restartBuildButton org repo shared.repo.build.build restartBuild
                ]

        Pages.Hooks org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited shared.user <| org ++ "/" ++ repo

        Pages.OrgSecrets _ _ _ _ ->
            text ""

        Pages.SharedSecrets _ _ _ _ _ ->
            text ""

        Pages.AddOrgSecret _ _ ->
            text ""

        Pages.AddRepoSecret _ _ _ ->
            text ""

        Pages.AddDeployment _ _ ->
            text ""

        Pages.PromoteDeployment _ _ _ ->
            text ""

        Pages.AddSharedSecret _ _ _ ->
            text ""

        Pages.OrgSecret _ _ _ ->
            text ""

        Pages.RepoSecret _ _ _ _ ->
            text ""

        Pages.SharedSecret _ _ _ _ ->
            text ""

        Pages.RepositoryBuildsPulls _ _ _ _ ->
            text ""

        Pages.RepositoryBuildsTags _ _ _ _ ->
            text ""

        Pages.OrgBuilds _ _ _ _ ->
            text ""

        Pages.AddSchedule _ _ ->
            text ""

        Pages.Schedule _ _ _ ->
            text ""

        Pages.Settings ->
            text ""

        Pages.Login ->
            text ""

        Pages.NotFound ->
            text ""


{-| viewTabs : takes list of tab records and renders them with spacers and horizontal filler
-}
viewTabs : List Tab -> String -> Html msg
viewTabs tabs testLabel =
    tabs
        |> List.filterMap viewTab
        |> List.intersperse viewSpacer
        |> (\t -> t ++ [ viewFiller ])
        |> div [ class "jump-bar", Util.testAttribute testLabel ]


{-| viewTab : takes single tab record and renders jump link, uses current page to display conditional style
-}
viewTab : Tab -> Maybe (Html msg)
viewTab { name, currentPage, toPage, isAlerting, show } =
    if show then
        Just <|
            a
                [ classList
                    [ ( "jump", True )
                    , ( "alerting", isAlerting )
                    ]
                , viewingTab currentPage toPage
                , Routes.href <| Pages.toRoute toPage
                , Util.testAttribute <| "jump-" ++ name
                ]
                [ text name ]

    else
        Nothing


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



-- ORG


viewOrgTabs : RepoModel -> Org -> Page -> Html msg
viewOrgTabs rm org currentPage =
    let
        tabs =
            [ Tab "Repositories" currentPage (Pages.OrgRepositories org Nothing Nothing) False True
            , Tab "Builds" currentPage (Pages.OrgBuilds org rm.builds.maybePage rm.builds.maybePerPage rm.builds.maybeEvent) False True
            , Tab "Secrets" currentPage (Pages.OrgSecrets "native" org Nothing Nothing) False True
            ]
    in
    viewTabs tabs "jump-bar-repo"



-- REPO


{-| viewRepoTabs : takes RepoModel and current page and renders navigation tabs
-}
viewRepoTabs : RepoModel -> Org -> Repo -> Page -> List ( Org, Repo ) -> Html msg
viewRepoTabs rm org repo currentPage scheduleAllowlist =
    let
        lastHook =
            case rm.hooks.hooks of
                RemoteData.Success hooks ->
                    List.head hooks

                _ ->
                    Nothing

        lastBuild =
            case rm.builds.builds of
                RemoteData.Success builds ->
                    List.head builds

                _ ->
                    Nothing

        isAlerting =
            case ( lastHook, lastBuild ) of
                ( Just hook, Just build ) ->
                    case hook.status of
                        "success" ->
                            False

                        _ ->
                            hook.created > build.created

                _ ->
                    False

        showSchedules =
            Util.checkScheduleAllowlist org repo scheduleAllowlist

        tabs =
            [ Tab "Builds" currentPage (Pages.RepositoryBuilds org repo rm.builds.maybePage rm.builds.maybePerPage rm.builds.maybeEvent) False True
            , Tab "Deployments" currentPage (Pages.RepositoryDeployments org repo rm.builds.maybePage rm.builds.maybePerPage) False True
            , Tab "Secrets" currentPage (Pages.RepoSecrets "native" org repo Nothing Nothing) False True
            , Tab "Schedules" currentPage (Pages.Schedules org repo Nothing Nothing) False showSchedules
            , Tab "Audit" currentPage (Pages.Hooks org repo rm.hooks.maybePage rm.hooks.maybePerPage) isAlerting True
            , Tab "Settings" currentPage (Pages.RepoSettings org repo) False True
            ]
    in
    viewTabs tabs "jump-bar-repo"



-- BUILD


{-| cancelBuildButton : takes org repo and build number and renders button to cancel a build
-}
cancelBuildButton : Org -> Repo -> WebData Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
cancelBuildButton org repo build cancelBuild =
    case build of
        RemoteData.Success b ->
            let
                cancelButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| cancelBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "cancel-build"
                        ]
                        [ text "Cancel Build"
                        ]
            in
            case b.status of
                Vela.Running ->
                    cancelButton

                Vela.Pending ->
                    cancelButton

                Vela.PendingApproval ->
                    cancelButton

                _ ->
                    text ""

        _ ->
            text ""


{-| restartBuildButton : takes org repo and build number and renders button to restart a build
-}
restartBuildButton : Org -> Repo -> WebData Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
restartBuildButton org repo build restartBuild =
    case build of
        RemoteData.Success b ->
            let
                restartButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| restartBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "restart-build"
                        ]
                        [ text "Restart Build"
                        ]
            in
            case b.status of
                Vela.PendingApproval ->
                    text ""

                _ ->
                    restartButton

        _ ->
            text ""


{-| approveBuildButton: takes org repo and build number and renders button to approve a build run
-}
approveBuildButton : Org -> Repo -> WebData Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
approveBuildButton org repo build approveBuild =
    case build of
        RemoteData.Success b ->
            let
                approveButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| approveBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "approve-build"
                        ]
                        [ text "Approve Build"
                        ]
            in
            case b.status of
                Vela.PendingApproval ->
                    approveButton

                _ ->
                    text ""

        _ ->
            text ""
