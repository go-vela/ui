{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Repo exposing (Model, Msg, Props, layout, map)

import Components.Crumbs
import Components.Help
import Components.Tabs
import Effect exposing (Effect)
import Html exposing (..)
import Layout exposing (Layout)
import Layouts.Default
import Route exposing (Route)
import Shared
import Time
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
        { init = init props shared
        , update = update props
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withParentProps
            { navButtons = props.navButtons
            , utilButtons =
                Components.Tabs.viewRepoTabs
                    shared
                    { org = props.org
                    , repo = props.repo
                    , currentPath = route.path
                    }
                    :: props.utilButtons
            , helpCommands = props.helpCommands
            , crumbs = props.crumbs
            , repo = Just ( props.org, props.repo )
            }



-- MODEL


type alias Model =
    {}


init : Props contentMsg -> Shared.Model -> () -> ( Model, Effect Msg )
init props shared _ =
    ( {}
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
    = Tick { time : Time.Posix, interval : Interval.Interval }


update : Props contentMsg -> Msg -> Model -> ( Model, Effect Msg )
update props msg model =
    case msg of
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
    , body = content.body
    }