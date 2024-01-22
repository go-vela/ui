module Components.Tabs exposing (Tab, view, viewBuildTabs, viewOrgTabs, viewRepoTabs)

import Api.Pagination as Pagination
import Effect
import Html exposing (Html, a, div, span, text)
import Html.Attributes exposing (class, classList)
import Html.Events
import RemoteData
import Route.Path
import Shared
import Utils.Helpers as Util
import Vela


{-| Tab : record to represent information used by page navigation tab
-}
type alias Tab =
    { currentPath : Route.Path.Path
    , toPath : Route.Path.Path
    , name : String
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
viewTab { name, currentPath, toPath, isAlerting, show } =
    if show then
        Just <|
            a
                [ classList
                    [ ( "jump", True )
                    , ( "alerting", isAlerting )
                    ]
                , currentPathClass currentPath toPath
                , Route.Path.href toPath
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


{-| currentPathClass : returns css class if current path matches tab path
-}
currentPathClass : Route.Path.Path -> Route.Path.Path -> Html.Attribute msg
currentPathClass p1 p2 =
    if p1 == p2 then
        class "current"

    else
        class ""



-- ORG


viewOrgTabs :
    { currentPath : Route.Path.Path
    , org : String
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    , maybeEvent : Maybe String
    }
    -> Html msg
viewOrgTabs props =
    let
        tabs =
            [ { name = "Repositories"
              , currentPath = props.currentPath
              , toPath = Route.Path.Org_ { org = props.org }
              , isAlerting = False
              , show = True
              }
            , { name = "Builds"
              , currentPath = props.currentPath
              , toPath = Route.Path.Org_Builds { org = props.org }
              , isAlerting = False
              , show = True
              }
            , { name = "Secrets"
              , currentPath = props.currentPath
              , toPath = Route.Path.Org_Secrets { org = props.org }
              , isAlerting = False
              , show = True
              }
            ]
    in
    view tabs "jump-bar-repo"



-- REPO


viewRepoTabs :
    Shared.Model
    ->
        { currentPath : Route.Path.Path
        , org : String
        , repo : String
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

        auditAlerting =
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
            [ { name = "Builds"
              , currentPath = props.currentPath
              , toPath =
                    Route.Path.Org_Repo_
                        { org = props.org
                        , repo = props.repo
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Deployments"
              , currentPath = props.currentPath
              , toPath =
                    Route.Path.Org_Repo_Deployments
                        { org = props.org
                        , repo = props.repo
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Secrets"
              , currentPath = props.currentPath
              , toPath = Route.Path.NotFound_
              , isAlerting = False
              , show = True
              }
            , { name = "Schedules"
              , currentPath = props.currentPath
              , toPath = Route.Path.NotFound_
              , isAlerting = False
              , show = showSchedules
              }
            , { name = "Audit"
              , currentPath = props.currentPath
              , toPath = Route.Path.NotFound_
              , isAlerting = auditAlerting
              , show = True
              }
            , { name = "Settings"
              , currentPath = props.currentPath
              , toPath = Route.Path.NotFound_
              , isAlerting = False
              , show = True
              }
            ]
    in
    view tabs "jump-bar-repo"



-- BUILD


viewBuildTabs :
    Shared.Model
    ->
        { org : String
        , repo : String
        , buildNumber : String
        , currentPath : Route.Path.Path
        }
    -> Html msg
viewBuildTabs shared props =
    let
        tabs =
            [ { name = "Build"
              , currentPath = props.currentPath
              , toPath =
                    Route.Path.Org_Repo_Build_
                        { org = props.org
                        , repo = props.repo
                        , buildNumber = props.buildNumber
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Services"
              , currentPath = props.currentPath
              , toPath =
                    Route.Path.Org_Repo_Build_Services
                        { org = props.org
                        , repo = props.repo
                        , buildNumber = props.buildNumber
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Pipeline"
              , currentPath = props.currentPath
              , toPath = Route.Path.NotFound_
              , isAlerting = False
              , show = True
              }
            , { name = "Visualize"
              , currentPath = props.currentPath
              , toPath = Route.Path.NotFound_
              , isAlerting = False
              , show = True
              }
            ]
    in
    view tabs "jump-bar-build"
