{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Pulls exposing (Model, Msg, page)

import Dict
import Effect exposing (Effect)
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


page : Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
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


init : Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init route () =
    ( {}
    , Effect.replaceRoute <|
        { path = Route.Path.Org__Repo_ route.params
        , query = Dict.fromList [ ( "event", "pull_request" ) ]
        , hash = Nothing
        }
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
