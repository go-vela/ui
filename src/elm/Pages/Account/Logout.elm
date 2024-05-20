{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.Logout exposing (Model, Msg, page)

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


{-| Model : alias for a model object for the page.
-}
type alias Model =
    {}


{-| init : initializes page with no arguments.
-}
init : Route () -> () -> ( Model, Effect Msg )
init route () =
    ( {}
    , Effect.logout { from = Dict.get "from" route.query }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
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
