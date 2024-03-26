{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.Settings exposing (..)

import Auth
import Auth.Session exposing (Session(..))
import Components.Crumbs
import Components.Nav
import DateFormat.Relative exposing (relativeTime)
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , br
        , button
        , div
        , em
        , h2
        , label
        , main_
        , p
        , section
        , text
        , textarea
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , for
        , id
        , readonly
        , rows
        , wrap
        )
import Html.Events exposing (onClick)
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Helpers as Util
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
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
      -- ALERTS
    | AddAlertCopiedToClipboard String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- ALERTS
        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess
                { content = "'" ++ contentCopied ++ "' copied to clipboard."
                , addToastIfUnique = False
                , link = Nothing
                }
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
            [ ( "Overview", Just Route.Path.Home_ )
            , ( "My Settings", Nothing )
            ]
    in
    { title = "My Settings"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ Util.testAttribute "user-settings" ]
                [ viewAccount_Settings shared model
                ]
            ]
        ]
    }


viewAccount_Settings : Shared.Model -> Model -> Html Msg
viewAccount_Settings shared model =
    div [ class "my-settings", Util.testAttribute "settings" ] <|
        case shared.session of
            Authenticated auth ->
                let
                    timeRemaining =
                        if Time.posixToMillis auth.expiresAt < Time.posixToMillis shared.time then
                            "Token has expired"

                        else
                            "Expires " ++ relativeTime shared.time auth.expiresAt ++ "."
                in
                [ section [ class "settings", Util.testAttribute "user-token" ]
                    [ h2 [ class "settings-title" ] [ text "Authentication Token" ]
                    , p [ class "settings-description" ] [ text timeRemaining, br [] [], em [] [ text "Token will refresh before it expires." ] ]
                    , div [ class "form-controls", class "-no-x-pad" ]
                        [ label [ class "form-label", class "visually-hidden", for "token" ] [ text "Auth Token" ]
                        , textarea
                            [ class "form-control"
                            , class "copy-display"
                            , class "-is-expanded"
                            , id "token"
                            , rows 4
                            , readonly True
                            , wrap "soft"
                            ]
                            [ text auth.token ]
                        , div [ class "vert-icon-container" ]
                            [ button
                                [ class "copy-button"
                                , class "button"
                                , class "-icon"
                                , class "-white"
                                , attribute "data-clipboard-text" auth.token
                                , attribute "aria-label" "copy token"
                                , Util.testAttribute "copy-token"
                                , onClick <| AddAlertCopiedToClipboard auth.token
                                ]
                                [ FeatherIcons.copy
                                    |> FeatherIcons.withSize 18
                                    |> FeatherIcons.toHtml []
                                ]
                            ]
                        ]
                    ]
                ]

            Unauthenticated ->
                []
