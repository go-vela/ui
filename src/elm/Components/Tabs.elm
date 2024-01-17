module Components.Tabs exposing (Tab, view, viewBuildTabs, viewOrgTabs, viewRepoTabs)

import Api.Pagination as Pagination
import Html exposing (Html, a, div, span, text)
import Html.Attributes exposing (class, classList)
import Pages exposing (Page)
import RemoteData
import Routes
import Shared
import Utils.Helpers as Util
import Vela


{-| Tab : record to represent information used by page navigation tab
-}
type alias Tab =
    { name : String
    , currentPage : Page
    , toPage : Page
    , isAlerting : Bool
    , show : Bool
    }


{-| view : takes list of tab records and renders them with spacers and horizontal filler
-}
view : List Tab -> String -> Html msg
view tabs testLabel =
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


viewOrgTabs :
    { org : String
    , currentPage : Page
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    , maybeEvent : Maybe String
    }
    -> Html msg
viewOrgTabs props =
    let
        tabs =
            [ Tab "Repositories" props.currentPage (Pages.OrgRepositories props.org Nothing Nothing) False True
            , Tab "Builds" props.currentPage (Pages.OrgBuilds props.org props.maybePage props.maybePerPage props.maybeEvent) False True
            , Tab "Secrets" props.currentPage (Pages.OrgSecrets "native" props.org Nothing Nothing) False True
            ]
    in
    view tabs "jump-bar-repo"



-- REPO


{-| viewRepoTabs : takes RepoModel and current page and renders navigation tabs
-}
viewRepoTabs :
    Shared.Model
    ->
        { org : String
        , repo : String
        , currentPage : Page
        , scheduleAllowlist : List ( Vela.Org, Vela.Repo )
        }
    -> Html msg
viewRepoTabs shared props =
    let
        rm =
            shared.repo

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
            Util.checkScheduleAllowlist props.org props.repo props.scheduleAllowlist

        tabs =
            [ Tab "Builds" props.currentPage (Pages.RepositoryBuilds props.org props.repo rm.builds.maybePage rm.builds.maybePerPage rm.builds.maybeEvent) False True
            , Tab "Deployments" props.currentPage (Pages.RepositoryDeployments props.org props.repo rm.builds.maybePage rm.builds.maybePerPage) False True
            , Tab "Secrets" props.currentPage (Pages.RepoSecrets "native" props.org props.repo Nothing Nothing) False True
            , Tab "Schedules" props.currentPage (Pages.Schedules props.org props.repo Nothing Nothing) False showSchedules
            , Tab "Audit" props.currentPage (Pages.Hooks props.org props.repo rm.hooks.maybePage rm.hooks.maybePerPage) isAlerting True
            , Tab "Settings" props.currentPage (Pages.RepoSettings props.org props.repo) False True
            ]
    in
    view tabs "jump-bar-repo"



-- BUILD


{-| viewBuildTabs : takes model information and current page and renders build navigation tabs
-}
viewBuildTabs :
    Shared.Model
    ->
        { org : String
        , repo : String
        , buildNumber : String
        , currentPage : Page
        }
    -> Html msg
viewBuildTabs shared props =
    let
        bm =
            shared.repo.build

        pipeline =
            shared.pipeline

        tabs =
            [ Tab "Build" props.currentPage (Pages.Build props.org props.repo props.buildNumber bm.steps.focusFragment) False True
            , Tab "Services" props.currentPage (Pages.BuildServices props.org props.repo props.buildNumber bm.services.focusFragment) False True
            , Tab "Pipeline" props.currentPage (Pages.BuildPipeline props.org props.repo props.buildNumber pipeline.expand pipeline.focusFragment) False True
            , Tab "Visualize" props.currentPage (Pages.BuildGraph props.org props.repo props.buildNumber) False True
            ]
    in
    view tabs "jump-bar-build"
