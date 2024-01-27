{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Org exposing (Model, Msg, Props, layout, map)

import Components.Tabs
import Effect exposing (Effect)
import Html exposing (..)
import Layout exposing (Layout)
import Layouts.Default
import Route exposing (Route)
import Shared
import View exposing (View)


type alias Props contentMsg =
    { org : String
    , navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { org = props.org
    , navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.navButtons
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout (Layouts.Default.Props contentMsg) Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init shared
        , update = update
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withParentProps
            { navButtons = props.navButtons
            , utilButtons =
                [ Components.Tabs.viewOrgTabs
                    { org = props.org
                    , currentPath = route.path
                    , maybePage = Nothing
                    , maybePerPage = Nothing
                    , maybeEvent = Nothing
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
    { title = props.org ++ " " ++ content.title
    , body =
        [ Html.span [] content.body
        ]
    }