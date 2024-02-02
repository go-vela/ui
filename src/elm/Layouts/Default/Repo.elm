{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Repo exposing (Model, Msg, Props, layout, map)

import Components.Crumbs
import Components.Help
import Components.Tabs
import Components.Util
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (..)
import Layout exposing (Layout)
import Layouts.Default
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Url exposing (Url)
import Utils.Interval as Interval
import View exposing (View)


type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    , helpCommands : List Components.Help.Command
    , crumbs : List Components.Crumbs.Crumb
    , org : String
    , repo : String
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    , helpCommands = props.helpCommands
    , crumbs = props.crumbs
    , org = props.org
    , repo = props.repo
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout (Layouts.Default.Props contentMsg) Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared route
        , update = update props route
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withOnUrlChanged OnUrlChanged
        |> Layout.withParentProps
            { navButtons = props.navButtons
            , utilButtons = []
            , helpCommands = props.helpCommands
            , crumbs = props.crumbs
            , repo = Just ( props.org, props.repo )
            }



-- MODEL


type alias Model =
    { tabHistory : Dict String Url }


init : Props contentMsg -> Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init props shared route _ =
    ( { tabHistory = Dict.empty
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
        , Effect.getRepoHooksShared
            { pageNumber = Nothing
            , perPage = Nothing
            , maybeEvent = Nothing
            , org = props.org
            , repo = props.repo
            }
        ]
    )



-- UPDATE


type Msg
    = --BROWSER
      OnUrlChanged { from : Route (), to : Route () }
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Props contentMsg -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update props route msg model =
    case msg of
        OnUrlChanged options ->
            ( { model
                | tabHistory =
                    model.tabHistory |> Dict.insert (Route.Path.toString options.to.path) options.to.url
              }
            , Effect.replaceRouteRemoveTabHistorySkipDomFocus route
            )

        Tick options ->
            ( model
            , Effect.batch
                [ Effect.getCurrentUser {}
                , Effect.getRepoBuildsShared
                    { pageNumber = Nothing
                    , perPage = Nothing
                    , maybeEvent = Nothing
                    , org = props.org
                    , repo = props.repo
                    }
                , Effect.getRepoHooksShared
                    { pageNumber = Nothing
                    , perPage = Nothing
                    , maybeEvent = Nothing
                    , org = props.org
                    , repo = props.repo
                    }
                ]
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = props.org ++ "/" ++ props.repo ++ " " ++ content.title
    , body =
        Components.Util.view shared
            route
            (Components.Tabs.viewRepoTabs
                shared
                { org = props.org
                , repo = props.repo
                , currentPath = route.path
                , tabHistory = model.tabHistory
                }
                :: props.utilButtons
            )
            :: content.body
    }
