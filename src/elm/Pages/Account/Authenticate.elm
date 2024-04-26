{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.Authenticate exposing (Model, Msg, page)

import Dict
import Effect exposing (Effect)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init route
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


type alias Model =
    {}


init : Route () -> () -> ( Model, Effect Msg )
init route () =
    let
        code =
            Dict.get "code" route.query

        state =
            Dict.get "state" route.query
    in
    ( {}
    , Effect.finishAuthentication { code = code, state = state }
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


view : Model -> View Msg
view model =
    View.none
