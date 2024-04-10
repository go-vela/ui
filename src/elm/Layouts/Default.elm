{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default exposing (Model, Msg, Props, layout)

import Api.Endpoint exposing (Endpoint(..))
import Auth.Session exposing (Session(..))
import Components.Alerts exposing (Alert)
import Components.Footer
import Components.Header
import Components.Help
import Effect exposing (Effect)
import Html exposing (..)
import Interop
import Json.Decode
import Layout exposing (Layout)
import Route exposing (Route)
import Shared
import Toasty as Alerting
import Utils.Favicons as Favicons
import Utils.Helpers as Util
import Utils.Theme as Theme
import View exposing (View)


{-| Props : alias for an object representing properties for default layouts.
-}
type alias Props =
    { helpCommands : List Components.Help.Command
    }


{-| layout : takes in properties, shared model, route, and returns a default layout.
-}
layout : Props -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init shared
        , update = update
        , view = view props shared route
        , subscriptions = subscriptions
        }



-- MODEL


{-| Model : alias for a model object for the default layout.
-}
type alias Model =
    { showIdentity : Bool
    , showHelp : Bool
    }


{-| init : takes a shared model and returns a model and an effect.
-}
init : Shared.Model -> () -> ( Model, Effect Msg )
init shared _ =
    ( { showIdentity = False
      , showHelp = False
      }
    , Effect.updateFavicon { favicon = Favicons.defaultFavicon }
    )



-- UPDATE


{-| Msg : possible messages for the default layout.
-}
type Msg
    = NoOp
      -- HEADER
    | ShowHideIdentity (Maybe Bool)
    | ShowHideHelp (Maybe Bool)
      -- THEME
    | SetTheme Theme.Theme
      -- ALERTS
    | AlertsUpdate (Alerting.Msg Alert)
    | AddAlertCopiedToClipboard String


{-| update : takes in a message, model, and returns a new model and an effect.
-}
update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        -- HEADER
        ShowHideIdentity show ->
            ( { model
                | showIdentity =
                    case show of
                        Just s ->
                            s

                        Nothing ->
                            not model.showIdentity
              }
            , Effect.none
            )

        ShowHideHelp show ->
            ( { model
                | showHelp =
                    case show of
                        Just s ->
                            s

                        Nothing ->
                            not model.showHelp
              }
            , Effect.none
            )

        -- THEME
        SetTheme theme ->
            ( model, Effect.setTheme { theme = theme } )

        -- ALERTS
        AlertsUpdate alert ->
            ( model
            , Effect.alertsUpdate { alert = alert }
            )

        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess
                { content = "'" ++ contentCopied ++ "' copied to clipboard."
                , addToastIfUnique = False
                , link = Nothing
                }
            )


{-| subscriptions : takes model and returns a batch of subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Util.onMouseDownSubscription "identity" model.showIdentity ShowHideIdentity
        , Util.onMouseDownSubscription "contextual-help" model.showHelp ShowHideHelp
        , Interop.onThemeChange decodeOnThemeChange
        ]


{-| decodeOnThemeChange : takes interaction in json and decodes it into a SetTheme Msg
-}
decodeOnThemeChange : Json.Decode.Value -> Msg
decodeOnThemeChange inTheme =
    case Json.Decode.decodeValue Theme.decodeTheme inTheme of
        Ok theme ->
            SetTheme theme

        Err _ ->
            SetTheme Theme.Dark



-- VIEW


{-| view : takes in properties, shared model, route, and a content object and returns a view.
-}
view : Props -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title =
        if String.isEmpty content.title then
            "Vela"

        else
            content.title ++ " | Vela"
    , body =
        [ Components.Header.view
            shared
            { from = Route.toString route
            , theme = shared.theme
            , setTheme = SetTheme
            , helpProps =
                { show = model.showHelp
                , showHide = ShowHideHelp
                , commands = props.helpCommands
                , showCopyAlert = AddAlertCopiedToClipboard
                }
            , showId = model.showIdentity
            , showHideIdentity = ShowHideIdentity
            }
            |> Html.map toContentMsg
        , span [] content.body
        , Components.Footer.view
            { toasties = shared.toasties
            , copyAlertMsg = AddAlertCopiedToClipboard
            , alertsUpdateMsg = AlertsUpdate
            }
            |> Html.map toContentMsg
        ]
    }
