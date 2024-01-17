{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Repo exposing (Model, Msg, Props, layout, map)

import Components.Alerts as Alerts exposing (Alert)
import Components.Footer
import Components.Header
import Components.Tabs
import Components.Util
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes exposing (class)
import Interop
import Json.Decode
import Layout exposing (Layout)
import Layouts.Default
import Pages
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Toasty as Alerting
import Utils.HelpCommands
import Utils.Helpers as Util
import Vela exposing (Theme)
import View exposing (View)


type alias Props contentMsg =
    { org : String, repo : String, nil : List contentMsg }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { org = props.org, repo = props.repo, nil = List.map fn props.nil }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout (Layouts.Default.Props contentMsg) Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init shared
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
                    , scheduleAllowlist = shared.velaScheduleAllowlist
                    }
                ]
            }



-- MODEL


type alias Model =
    {}


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared _ =
    ( {}
    , Effect.none
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
    { title =
        if String.isEmpty content.title then
            "Vela"

        else
            content.title ++ " | Vela"
    , body =
        [ Html.span [] content.body
        ]
    }
