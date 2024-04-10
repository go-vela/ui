{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.Login exposing (..)

import Api.Endpoint
import Browser.Navigation
import Components.Crumbs
import Components.Nav
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , button
        , div
        , h1
        , main_
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


{-| page : shared model, route, and returns the login page.
-}
page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update shared
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout toLayout



-- LAYOUT


{-| toLayout : takes model and passes the login page info to Layouts.
-}
toLayout : Model -> Layouts.Layout Msg
toLayout model =
    Layouts.Default
        { helpCommands =
            [ { name = "Authenticate"
              , content = "vela login"
              , docs = Just "authentication"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for the login page.
-}
type alias Model =
    {}


{-| init : initializes a login page with no arguments.
-}
init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Effect.none
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
      -- AUTH
    | SignInRequested


{-| update : takes current models, message, and returns an updated model and effect.
-}
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


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for the login page.
-}
view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Account", Nothing )
            , ( "Login", Nothing )
            ]
    in
    { title = "Login"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ Util.testAttribute "login_" ]
                [ if String.length shared.velaRedirect /= 0 then
                    viewLogin

                  else
                    text ""
                ]
            ]
        ]
    }


{-| viewLogin : renders a div with authorize button on the login page.
-}
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
