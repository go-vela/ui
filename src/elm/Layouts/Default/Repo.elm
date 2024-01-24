{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Repo exposing (Model, Msg, Props, layout, map)

import Components.Tabs
import Effect exposing (Effect)
import Html exposing (..)
import Layout exposing (Layout)
import Layouts.Default
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Vela
import View exposing (View)


type alias Props contentMsg =
    { org : String
    , repo : String
    , navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { org = props.org
    , repo = props.repo
    , navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout (Layouts.Default.Props contentMsg) Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared
        , update = update
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withParentProps
            { navButtons = []
            , utilButtons =
                [ Components.Tabs.viewRepoTabs
                    shared
                    { org = props.org
                    , repo = props.repo
                    , currentPath = route.path
                    }
                ]
            }



-- MODEL


type alias Model =
    {}


init : Props contentMsg -> Shared.Model -> () -> ( Model, Effect Msg )
init props shared _ =
    ( {}
    , Effect.batch
        [ Effect.getRepoBuildsShared
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
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = content.title
    , body = content.body
    }
