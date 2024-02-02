{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Tabs exposing (Tab, view, viewBuildTabs, viewOrgTabs, viewRepoTabs)

import Api.Pagination as Pagination
import Dict exposing (Dict)
import Html exposing (Html, a, div, span, text)
import Html.Attributes exposing (class, classList)
import RemoteData
import Route
import Route.Path
import Shared
import Url exposing (Url)
import Utils.Helpers as Util


{-| Tab : record to represent information used by page navigation tab
-}
type alias Tab =
    { toPath : Route.Path.Path
    , name : String
    , isAlerting : Bool
    , show : Bool
    }


{-| view : takes list of tab records and renders them with spacers and horizontal filler
-}
view : Dict String Url -> Route.Path.Path -> List Tab -> String -> Html msg
view tabHistory currentPath tabs testLabel =
    tabs
        |> List.filterMap (viewTab tabHistory currentPath)
        |> List.intersperse viewSpacer
        |> (\t -> t ++ [ viewFiller ])
        |> div [ class "jump-bar", Util.testAttribute testLabel ]


{-| viewTab : takes single tab record and renders jump link, uses current page to display conditional style
-}
viewTab : Dict String Url -> Route.Path.Path -> Tab -> Maybe (Html msg)
viewTab tabHistory currentPath { name, toPath, isAlerting, show } =
    let
        toRoute =
            Dict.get (Route.Path.toString toPath) tabHistory
                |> Maybe.map (Route.fromUrl ())
                |> Maybe.map
                    (\r ->
                        { path = r.path
                        , query = r.query |> Dict.insert "tab_switch" "true"
                        , hash = r.hash
                        }
                    )
                |> Maybe.withDefault
                    { path = toPath
                    , query = Dict.empty
                    , hash = Nothing
                    }
    in
    if show then
        Just <|
            a
                [ classList
                    [ ( "jump", True )
                    , ( "alerting", isAlerting )
                    ]
                , currentPathClass currentPath toPath
                , Route.href toRoute
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
    Shared.Model
    ->
        { currentPath : Route.Path.Path
        , org : String
        , tabHistory : Dict String Url
        }
    -> Html msg
viewOrgTabs shared props =
    let
        tabs =
            [ { name = "Repositories"
              , toPath = Route.Path.Org_ { org = props.org }
              , isAlerting = False
              , show = True
              }
            , { name = "Builds"
              , toPath = Route.Path.Org_Builds { org = props.org }
              , isAlerting = False
              , show = True
              }
            , { name = "Secrets"
              , toPath = Route.Path.SecretsEngine_OrgOrg_ { org = props.org, engine = "native" }
              , isAlerting = False
              , show = True
              }
            ]
    in
    view props.tabHistory props.currentPath tabs "jump-bar-repo"



-- REPO


viewRepoTabs :
    Shared.Model
    ->
        { currentPath : Route.Path.Path
        , org : String
        , repo : String
        , tabHistory : Dict String Url
        }
    -> Html msg
viewRepoTabs shared props =
    let
        lastHook =
            case shared.hooks of
                RemoteData.Success hooks ->
                    List.head hooks

                _ ->
                    Nothing

        lastBuild =
            case shared.builds of
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
            Util.checkScheduleAllowlist props.org props.repo shared.velaScheduleAllowlist

        tabs =
            [ { name = "Builds"
              , toPath =
                    Route.Path.Org_Repo_
                        { org = props.org
                        , repo = props.repo
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Deployments"
              , toPath =
                    Route.Path.Org_Repo_Deployments
                        { org = props.org
                        , repo = props.repo
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Secrets"
              , toPath =
                    Route.Path.SecretsEngine_RepoOrg_Repo_
                        { org = props.org
                        , repo = props.repo
                        , engine = "native"
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Schedules"
              , toPath = Route.Path.Org_Repo_Schedules { org = props.org, repo = props.repo }
              , isAlerting = False
              , show = showSchedules
              }
            , { name = "Audit"
              , toPath = Route.Path.Org_Repo_Audit { org = props.org, repo = props.repo }
              , isAlerting = auditAlerting
              , show = True
              }
            , { name = "Settings"
              , toPath = Route.Path.Org_Repo_Settings { org = props.org, repo = props.repo }
              , isAlerting = False
              , show = True
              }
            ]
    in
    view props.tabHistory props.currentPath tabs "jump-bar-repo"



-- BUILD
-- fromHistory : Dict String Url -> String -> Route.Path.Path


viewBuildTabs :
    Shared.Model
    ->
        { org : String
        , repo : String
        , buildNumber : String
        , currentPath : Route.Path.Path
        , tabHistory : Dict String Url
        }
    -> Html msg
viewBuildTabs shared props =
    let
        tabs =
            [ { name = "Build"
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
              , toPath =
                    Route.Path.Org_Repo_Build_Pipeline
                        { org = props.org
                        , repo = props.repo
                        , buildNumber = props.buildNumber
                        }
              , isAlerting = False
              , show = True
              }
            , { name = "Visualize"
              , toPath =
                    Route.Path.Org_Repo_Build_Graph
                        { org = props.org
                        , repo = props.repo
                        , buildNumber = props.buildNumber
                        }
              , isAlerting = False
              , show = True
              }
            ]
    in
    view props.tabHistory props.currentPath tabs "jump-bar-build"
