{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.NotFound_ exposing (Model, Msg, page)

import Components.Crumbs
import Components.Nav
import Effect exposing (Effect)
import Html exposing (main_, text)
import Html.Attributes exposing (class)
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout toLayout



-- LAYOUT


toLayout : Model -> Layouts.Layout Msg
toLayout model =
    Layouts.Default
        { helpCommands = []
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


view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home ), ( "Not Found", Nothing ) ]
    in
    { title = "Not Found"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ text "page not found"
            ]
        ]
    }
