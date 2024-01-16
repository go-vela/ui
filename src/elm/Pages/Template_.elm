{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Template_ exposing (..)

import Effect exposing (Effect)
import Html
    exposing
        ( div
        , h1
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        )
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }



-- INIT


type alias Model =
    { form : Form
    , apiResponse : WebData {}
    }


{-| Form : template record to hold user input fields
-}
type alias Form =
    { field : String
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { form =
            { field = ""
            }
      , apiResponse = NotAsked
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp
    | TemplateMsgChangeMe String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        TemplateMsgChangeMe _ ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : Shared.Model -> Model -> View Msg
view shared model =
    let
        body =
            div [ Util.testAttribute "template_" ] <|
                case shared.user of
                    Success u ->
                        [ text "loaded shared.user" ]

                    Loading ->
                        [ h1 [] [ text "Loading user...", span [ class "loading-ellipsis" ] [] ] ]

                    NotAsked ->
                        [ text "not asked" ]

                    Failure _ ->
                        [ text "failed" ]
    in
    { title = "Pages.Template_"
    , body =
        [ body
        ]
    }
