{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.Login exposing (..)

import Api.Endpoint
import Browser.Navigation
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , button
        , div
        , h1
        , p
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import Html.Events exposing (onClick)
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update shared
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
        , crumbs =
            [ ( "Account", Nothing )
            , ( "Login", Nothing )
            ]
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
      -- AUTH
    | SignInRequested


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- AUTH
        SignInRequested ->
            ( model
            , (Browser.Navigation.load <| Api.Endpoint.toUrl shared.velaAPIBaseURL Api.Endpoint.Login) |> Effect.sendCmd
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    let
        body =
            div [ Util.testAttribute "login_" ]
                [ if String.length shared.velaRedirect /= 0 then
                    viewLogin

                  else
                    text ""
                ]
    in
    { title = "Login"
    , body =
        [ body
        ]
    }


viewLogin : Html Msg
viewLogin =
    div []
        [ h1 [] [ text "Authorize Via" ]
        , button [ class "button", onClick SignInRequested, Util.testAttribute "login-button" ]
            [ FeatherIcons.github
                |> FeatherIcons.withSize 20
                |> FeatherIcons.withClass "login-source-icon"
                |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
            , text "GitHub"
            ]
        , p [] [ text "You will be taken to GitHub to authenticate." ]
        ]
