{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Build exposing (Model, Msg, Props, layout, map)

import Components.Build
import Components.RecentBuilds
import Components.Tabs
import Effect exposing (Effect)
import Html exposing (Html)
import Http
import Http.Detailed
import Layout exposing (Layout)
import Layouts.Default
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors
import Utils.Interval as Interval
import Vela
import View exposing (View)


type alias Props contentMsg =
    { org : String
    , repo : String
    , buildNumber : String
    , toBuildPath : String -> Route.Path.Path
    , navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { org = props.org
    , repo = props.repo
    , buildNumber = props.buildNumber
    , toBuildPath = props.toBuildPath
    , navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout (Layouts.Default.Props contentMsg) Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared
        , update = update props shared
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withOnUrlChanged OnUrlChanged
        |> Layout.withParentProps
            { navButtons = []
            , utilButtons = []
            }



-- MODEL


type alias Model =
    { build : WebData Vela.Build
    }


init : Props contentMsg -> Shared.Model -> () -> ( Model, Effect Msg )
init props shared _ =
    ( { build = RemoteData.Loading
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
            { baseUrl = shared.velaAPI
            , session = shared.session
            , onResponse = GetBuildResponse
            , org = props.org
            , repo = props.repo
            , buildNumber = props.buildNumber
            }
        ]
    )



-- UPDATE


type Msg
    = OnUrlChanged { from : Route (), to : Route () }
    | GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Props contentMsg -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update props shared msg model =
    case msg of
        OnUrlChanged _ ->
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
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetBuildResponse
                    , org = props.org
                    , repo = props.repo
                    , buildNumber = props.buildNumber
                    }
                ]
            )

        GetBuildResponse response ->
            case response of
                Ok ( _, build ) ->
                    ( { model
                        | build = RemoteData.Success build
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | build = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

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
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetBuildResponse
                    , org = props.org
                    , repo = props.repo
                    , buildNumber = props.buildNumber
                    }
                ]
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = props.org ++ "/" ++ props.repo ++ " #" ++ props.buildNumber ++ " " ++ content.title
    , body =
        [ Components.RecentBuilds.view shared
            { builds = shared.builds
            , build = model.build
            , num = 10
            , toPath = props.toBuildPath
            }
        , Components.Build.view shared
            { build = model.build
            , showFullTimestamps = False
            , actionsMenu = Nothing
            }
        , Components.Tabs.viewBuildTabs shared
            { org = props.org
            , repo = props.repo
            , buildNumber = props.buildNumber
            , currentPath = route.path
            }
        ]
            ++ content.body
    }
