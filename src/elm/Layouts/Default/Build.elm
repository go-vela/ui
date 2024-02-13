{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Build exposing (Model, Msg, Props, layout, map)

import Components.Build
import Components.Crumbs
import Components.Help
import Components.Nav
import Components.RecentBuilds
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, main_, text)
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
import Utils.Interval as Interval
import Vela
import View exposing (View)


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


type alias Model =
    { build : WebData Vela.Build
    , tabHistory : Dict String Url
    }


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


type Msg
    = --BROWSER
      OnUrlChanged { from : Route (), to : Route () }
      -- BUILD
    | GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


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
                        [ Effect.handleHttpError { httpError = error }
                        , Effect.updateFavicon { favicon = Favicons.statusToFavicon Vela.Error }
                        ]
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


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = props.org ++ "/" ++ props.repo ++ " #" ++ props.buildNumber ++ " " ++ content.title
    , body =
        [ Components.Nav.view shared
            route
            { buttons = [ text "<move build buttons here>" ] ++ props.navButtons
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
                }
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
