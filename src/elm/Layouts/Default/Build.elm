{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Build exposing (Model, Msg, Props, layout, map)

import Components.Alerts
import Components.Build
import Components.Crumbs
import Components.Help
import Components.Nav
import Components.RecentBuilds
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, main_, p, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layout exposing (Layout)
import Layouts.Default
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Url exposing (Url)
import Utils.Errors
import Utils.Favicons as Favicons
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| Props : alias for an object containing properties with a contentMsg.
-}
type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    , helpCommands : List Components.Help.Command
    , crumbs : List Components.Crumbs.Crumb
    , org : String
    , repo : String
    , buildNumber : String
    , toBuildPath : String -> Route.Path.Path
    }


{-| map : takes a function and a properties object and returns a new properties object;
map connects the page (msg1) to the layout (msg2).
-}
map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    , helpCommands = props.helpCommands
    , crumbs = props.crumbs
    , org = props.org
    , repo = props.repo
    , buildNumber = props.buildNumber
    , toBuildPath = props.toBuildPath
    }


{-| layout : takes in properties, shared model, route, and a content object and returns a default build layout.
-}
layout : Props contentMsg -> Shared.Model -> Route () -> Layout Layouts.Default.Props Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared route
        , update = update props shared route
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withOnUrlChanged OnUrlChanged
        |> Layout.withParentProps
            { helpCommands = props.helpCommands
            }



-- MODEL


{-| Model : alias for a model object.
-}
type alias Model =
    { build : WebData Vela.Build
    , tabHistory : Dict String Url
    }


{-| init : takes in properties, shared model, route, and a content object and returns a model and effect.
-}
init : Props contentMsg -> Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init props shared route _ =
    ( { build = RemoteData.Loading
      , tabHistory = Dict.empty
      }
    , Effect.batch
        [ Effect.getCurrentUser {}
        , Effect.getRepoBuildsShared
            { pageNumber = Nothing
            , perPage = Nothing
            , maybeEvent = Nothing
            , org = props.org
            , repo = props.repo
            }
        , Effect.getBuild
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetBuildResponse
            , org = props.org
            , repo = props.repo
            , buildNumber = props.buildNumber
            }
        ]
    )



-- UPDATE


{-| Msg : possible messages for the default build layout.
-}
type Msg
    = --BROWSER
      OnUrlChanged { from : Route (), to : Route () }
      -- BUILD
    | GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | RestartBuild { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber }
    | RestartBuildResponse { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | CancelBuild { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber }
    | CancelBuildResponse { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | ApproveBuild { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber }
    | ApproveBuildResponse { org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes in properties, models, route, message, and returns a new model and a message.
-}
update : Props contentMsg -> Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update props shared route msg model =
    case msg of
        -- BROWSER
        OnUrlChanged options ->
            ( { model
                | tabHistory =
                    model.tabHistory |> Dict.insert (Route.Path.toString options.to.path) options.to.url
              }
            , Effect.batch
                [ Effect.getRepoBuildsShared
                    { pageNumber = Nothing
                    , perPage = Nothing
                    , maybeEvent = Nothing
                    , org = props.org
                    , repo = props.repo
                    }
                , Effect.getBuild
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetBuildResponse
                    , org = props.org
                    , repo = props.repo
                    , buildNumber = props.buildNumber
                    }
                , Effect.replaceRouteRemoveTabHistorySkipDomFocus route
                ]
            )

        -- BUILD
        GetBuildResponse response ->
            case response of
                Ok ( _, build ) ->
                    ( { model
                        | build = RemoteData.Success build
                      }
                    , Effect.updateFavicon { favicon = Favicons.statusToFavicon build.status }
                    )

                Err error ->
                    ( { model | build = Utils.Errors.toFailure error }
                    , Effect.batch
                        [ Effect.handleHttpError
                            { error = error
                            , shouldShowAlertFn = Utils.Errors.showAlertAlways
                            }
                        , Effect.updateFavicon { favicon = Favicons.statusToFavicon Vela.Error }
                        ]
                    )

        RestartBuild options ->
            ( model
            , Effect.restartBuild
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = RestartBuildResponse options
                , org = options.org
                , repo = options.repo
                , buildNumber = options.buildNumber
                }
            )

        RestartBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    let
                        newBuildLink =
                            Just
                                ( "View Build #" ++ String.fromInt build.number
                                , Route.Path.Org_Repo_Build_
                                    { org = options.org
                                    , repo = options.repo
                                    , buildNumber = String.fromInt build.number
                                    }
                                )
                    in
                    ( model
                    , Effect.batch
                        [ Effect.getRepoBuildsShared
                            { pageNumber = Nothing
                            , perPage = Nothing
                            , maybeEvent = Nothing
                            , org = props.org
                            , repo = props.repo
                            }
                        , Effect.addAlertSuccess
                            { content = "Restarted build " ++ String.join "/" [ options.org, options.repo, options.buildNumber ] ++ "."
                            , addToastIfUnique = True
                            , link = newBuildLink
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Utils.Errors.showAlertAlways
                        }
                    )

        CancelBuild options ->
            ( model
            , Effect.cancelBuild
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = CancelBuildResponse options
                , org = options.org
                , repo = options.repo
                , buildNumber = options.buildNumber
                }
            )

        CancelBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    ( model
                    , Effect.batch
                        [ Effect.getBuild
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetBuildResponse
                            , org = props.org
                            , repo = props.repo
                            , buildNumber = props.buildNumber
                            }
                        , Effect.addAlertSuccess
                            { content = "Canceled build " ++ String.join "/" [ options.org, options.repo, options.buildNumber ] ++ "."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Utils.Errors.showAlertAlways
                        }
                    )

        ApproveBuild options ->
            ( model
            , Effect.approveBuild
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = ApproveBuildResponse options
                , org = options.org
                , repo = options.repo
                , buildNumber = options.buildNumber
                }
            )

        ApproveBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    ( model
                    , Effect.batch
                        [ Effect.getBuild
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetBuildResponse
                            , org = props.org
                            , repo = props.repo
                            , buildNumber = props.buildNumber
                            }
                        , Effect.addAlertSuccess
                            { content = "Approved build " ++ String.join "/" [ options.org, options.repo, options.buildNumber ] ++ "."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Utils.Errors.showAlertAlways
                        }
                    )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.batch
                [ Effect.getRepoBuildsShared
                    { pageNumber = Nothing
                    , perPage = Nothing
                    , maybeEvent = Nothing
                    , org = props.org
                    , repo = props.repo
                    }
                , Effect.getBuild
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetBuildResponse
                    , org = props.org
                    , repo = props.repo
                    , buildNumber = props.buildNumber
                    }
                ]
            )


{-| subscriptions : takes in a model and returns the subscriptions for autorefreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes in properties, models, route, and messages, and returns a default build view.
-}
view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    let
        viewRestartButton =
            case model.build of
                RemoteData.Success build ->
                    case build.status of
                        Vela.PendingApproval ->
                            text ""

                        _ ->
                            Components.Build.viewRestartButton props.org props.repo props.buildNumber RestartBuild
                                |> Html.map toContentMsg

                _ ->
                    text ""

        viewCancelButton =
            case model.build of
                RemoteData.Success build ->
                    case build.status of
                        Vela.Pending ->
                            Components.Build.viewCancelButton props.org props.repo props.buildNumber CancelBuild
                                |> Html.map toContentMsg

                        Vela.PendingApproval ->
                            Components.Build.viewCancelButton props.org props.repo props.buildNumber CancelBuild
                                |> Html.map toContentMsg

                        Vela.Running ->
                            Components.Build.viewCancelButton props.org props.repo props.buildNumber CancelBuild
                                |> Html.map toContentMsg

                        _ ->
                            text ""

                _ ->
                    text ""

        viewApproveButton =
            case model.build of
                RemoteData.Success build ->
                    case build.status of
                        Vela.PendingApproval ->
                            Components.Build.viewApproveButton props.org props.repo props.buildNumber ApproveBuild
                                |> Html.map toContentMsg

                        _ ->
                            text ""

                _ ->
                    text ""

        viewBanner =
            case model.build of
                RemoteData.Success build ->
                    case build.status of
                        Vela.PendingApproval ->
                            p [ class "notice", Util.testAttribute "approve-build-notice" ] [ text "An admin of this repository must approve the build to run" ]

                        _ ->
                            text ""

                _ ->
                    text ""
    in
    { title = props.org ++ "/" ++ props.repo ++ " #" ++ props.buildNumber ++ " " ++ content.title
    , body =
        [ Components.Nav.view shared
            route
            { buttons =
                [ viewRestartButton
                , viewCancelButton
                , viewApproveButton
                ]
                    ++ props.navButtons
            , crumbs = Components.Crumbs.view route.path props.crumbs
            }
        , main_ [ class "content-wrap" ]
            ([ Components.Util.view shared route props.utilButtons
             , Components.RecentBuilds.view shared
                { builds = shared.builds
                , build = model.build
                , num = 10
                , toPath = props.toBuildPath
                }
             , Components.Build.view shared
                { build = model.build
                , showFullTimestamps = False
                , actionsMenu = Html.div [] []
                , showRepoLink = False
                , linkBuildNumber = False
                }
             , viewBanner
             , Components.Tabs.viewBuildTabs shared
                { org = props.org
                , repo = props.repo
                , buildNumber = props.buildNumber
                , currentPath = route.path
                , tabHistory = model.tabHistory
                }
             ]
                ++ content.body
            )
        ]
    }
