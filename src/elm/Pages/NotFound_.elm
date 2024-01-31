{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.NotFound_ exposing (Model, Msg, page)

import Effect exposing (Effect)
import Html exposing (..)
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }
        |> Page.withLayout toLayout



-- LAYOUT


toLayout : Model -> Layouts.Layout Msg
toLayout model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , repo = Nothing
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = "Not Found"
    , body =
        [ text "page not found"
        ]
    }
