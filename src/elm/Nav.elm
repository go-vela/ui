{--
SPDX-License-Identifier: Apache-2.0
--}


module Nav exposing (Msgs, viewBuildTabs, viewNav, viewUtil)

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
import Pages.Build.History
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import Time exposing (Posix, Zone)
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , CurrentUser
        , Engine
        , Org
        , PipelineModel
        , Repo
        , RepoModel
        , SecretType
        , SourceRepositories
        )


type alias PartialModel a =
    { a
        | velaScheduleAllowlist : List ( Org, Repo )
        , page : Page
        , user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
        , repo : RepoModel
        , time : Posix
        , zone : Zone
        , pipeline : PipelineModel
    }


type alias Msgs msg =
    { fetchSourceRepos : msg
    , toggleFavorite : ToggleFavorite msg
    , refreshSettings : Org -> Repo -> msg
    , refreshHooks : Org -> Repo -> msg
    , refreshSecrets : Engine -> SecretType -> Org -> Repo -> msg
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
navButtons model { fetchSourceRepos, toggleFavorite, restartBuild, cancelBuild } =
    case model.page of
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

        Pages.RepositoryDeployments org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.Schedules org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.RepoSettings org repo ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.RepoSecrets _ org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

        Pages.Build org repo _ _ ->
            div [ class "buttons" ]
                [ cancelBuildButton org repo model.repo.build.build cancelBuild
                , restartBuildButton org repo model.repo.build.build restartBuild
                ]

        Pages.BuildServices org repo _ _ ->
            div [ class "buttons" ]
                [ cancelBuildButton org repo model.repo.build.build cancelBuild
                , restartBuildButton org repo model.repo.build.build restartBuild
                ]

        Pages.BuildPipeline org repo _ _ _ ->
            div [ class "buttons" ]
                [ cancelBuildButton org repo model.repo.build.build cancelBuild
                , restartBuildButton org repo model.repo.build.build restartBuild
                ]

        Pages.Hooks org repo _ _ ->
            starToggle org repo toggleFavorite <| isFavorited model.user <| org ++ "/" ++ repo

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
            Pages.OrgBuilds org _ _ _ ->
                viewOrgTabs rm org model.page

            Pages.OrgSecrets _ org _ _ ->
                viewOrgTabs rm org model.page

            Pages.OrgRepositories org _ _ ->
                viewOrgTabs rm org model.page

            Pages.RepositoryBuilds org repo _ _ _ ->
                viewRepoTabs rm org repo model.page model.velaScheduleAllowlist

            Pages.RepositoryDeployments org repo _ _ ->
                viewRepoTabs rm org repo model.page model.velaScheduleAllowlist

            Pages.RepoSecrets _ org repo _ _ ->
                viewRepoTabs rm org repo model.page model.velaScheduleAllowlist

            Pages.Schedules org repo _ _ ->
                viewRepoTabs rm org repo model.page model.velaScheduleAllowlist

            Pages.Hooks org repo _ _ ->
                viewRepoTabs rm org repo model.page model.velaScheduleAllowlist

            Pages.RepoSettings org repo ->
                viewRepoTabs rm org repo model.page model.velaScheduleAllowlist

            Pages.Build _ _ _ _ ->
                Pages.Build.History.view model.time model.zone model.page 10 model.repo

            Pages.BuildServices _ _ _ _ ->
                Pages.Build.History.view model.time model.zone model.page 10 model.repo

            Pages.BuildPipeline _ _ _ _ _ ->
                Pages.Build.History.view model.time model.zone model.page 10 model.repo

            Pages.AddDeployment _ _ ->
                text ""

            Pages.PromoteDeployment _ _ _ ->
                text ""

            Pages.Overview ->
                text ""

            Pages.SourceRepositories ->
                text ""

            Pages.SharedSecrets _ _ _ _ _ ->
                text ""

            Pages.AddOrgSecret _ _ ->
                text ""

            Pages.AddRepoSecret _ _ _ ->
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
        ]


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


{-| viewBuildTabs : takes model information and current page and renders build navigation tabs
-}
viewBuildTabs : PartialModel a -> Org -> Repo -> BuildNumber -> Page -> Html msg
viewBuildTabs model org repo buildNumber currentPage =
    let
        bm =
            model.repo.build

        pipeline =
            model.pipeline

        tabs =
            [ Tab "Build" currentPage (Pages.Build org repo buildNumber bm.steps.focusFragment) False True
            , Tab "Services" currentPage (Pages.BuildServices org repo buildNumber bm.services.focusFragment) False True
            , Tab "Pipeline" currentPage (Pages.BuildPipeline org repo buildNumber pipeline.expand pipeline.focusFragment) False True
            ]
    in
    viewTabs tabs "jump-bar-build"


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

        _ ->
            text ""
