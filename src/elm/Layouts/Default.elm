{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default exposing (Model, Msg, Props, layout, map)

import Api.Endpoint exposing (Endpoint(..))
import Auth.Session exposing (Session(..))
import Components.Alerts exposing (Alert)
import Components.Crumbs
import Components.Favorites
import Components.Footer
import Components.Header
import Components.Help
import Components.Nav
import Components.Util
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes exposing (class)
import Interop
import Json.Decode
import Layout exposing (Layout)
import Maybe.Extra
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Toasty as Alerting
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Theme as Theme
import View exposing (View)


type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    , helpCommands : List Components.Help.Command
    , crumbs : List Components.Crumbs.Crumb
    , repo : Maybe ( String, String )
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    , helpCommands = props.helpCommands
    , crumbs = props.crumbs
    , repo = props.repo
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init shared
        , update = update
        , view = view props shared route
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { showIdentity : Bool
    , showHelp : Bool
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared _ =
    ( { showIdentity = False
      , showHelp = False
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp
      -- HEADER
    | ShowHideIdentity (Maybe Bool)
    | ShowHideHelp (Maybe Bool)
      -- FAVORITES
    | ToggleFavorite String (Maybe String)
      -- THEME
    | SetTheme Theme.Theme
      -- ALERTS
    | AlertsUpdate (Alerting.Msg Alert)
    | AddAlertCopiedToClipboard String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.updateFavorites
                { org = org
                , maybeRepo = maybeRepo
                , updateType = Favorites.Toggle
                }
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
            , Effect.addAlertSuccess { content = "'" ++ contentCopied ++ "' copied to clipboard.", addToastIfUnique = False }
            )


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


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
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

            -- todo: use props for this
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
        , Components.Nav.view shared
            route
            { buttons =
                props.navButtons
                    ++ [ props.repo
                            |> Maybe.Extra.unwrap (text "")
                                (\( org, repo ) ->
                                    Components.Favorites.viewStarToggle
                                        { msg = ToggleFavorite
                                        , org = org
                                        , repo = repo
                                        , user = shared.user
                                        }
                                        |> Html.map toContentMsg
                                )
                       ]
            , crumbs = Components.Crumbs.view route.path props.crumbs
            }
        , main_ [ class "content-wrap" ]
            (Components.Util.view shared route props.utilButtons
                :: content.body
            )
        , Components.Footer.view
            { toasties = shared.toasties
            , copyAlertMsg = AddAlertCopiedToClipboard
            , alertsUpdateMsg = AlertsUpdate
            }
            |> Html.map toContentMsg
        ]
    }
