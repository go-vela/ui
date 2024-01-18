{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default exposing (Model, Msg, Props, layout, map)

import Components.Alerts as Alerts exposing (Alert)
import Components.Footer
import Components.Header
import Components.Nav
import Components.Util
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes exposing (class)
import Interop
import Json.Decode
import Layout exposing (Layout)
import Pages
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Toasty as Alerting
import Utils.HelpCommands
import Utils.Helpers as Util
import Vela exposing (Theme)
import View exposing (View)


type alias Props contentMsg =
    { navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { navButtons =
        props.navButtons
            |> List.map (Html.map fn)
    , utilButtons =
        props.utilButtons
            |> List.map (Html.map fn)
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
    | ShowHideIdentity (Maybe Bool)
    | ShowHideHelp (Maybe Bool)
    | SetTheme Theme
    | AlertsUpdate (Alerting.Msg Alert)
    | CopyAlert String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

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

        SetTheme theme ->
            ( model, Effect.setTheme { theme = theme } )

        AlertsUpdate alert ->
            ( model
            , Effect.alertsUpdate { alert = alert }
            )

        CopyAlert contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
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
    case Json.Decode.decodeValue Vela.decodeTheme inTheme of
        Ok theme ->
            SetTheme theme

        Err _ ->
            SetTheme Vela.Dark



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
            { session = shared.session
            , feedbackLink = shared.velaFeedbackURL
            , docsLink = shared.velaDocsURL
            , theme = shared.theme
            , setTheme = SetTheme
            , help = helpArgs shared model
            , showId = model.showIdentity
            , showHideIdentity = ShowHideIdentity
            }
            |> Html.map toContentMsg
        , Components.Nav.view shared route props.navButtons
        , main_ [ class "content-wrap" ]
            (Components.Util.view shared route props.utilButtons
                :: content.body
            )
        , Components.Footer.view
            { toasties = shared.toasties
            , copyAlertMsg = CopyAlert
            , alertsUpdateMsg = AlertsUpdate
            }
            |> Html.map toContentMsg
        ]
    }


helpArg : WebData a -> Utils.HelpCommands.Arg
helpArg arg =
    { success = Util.isSuccess arg, loading = Util.isLoading arg }


helpArgs : Shared.Model -> Model -> Utils.HelpCommands.Model Msg
helpArgs shared model =
    { user = helpArg shared.user

    -- todo: this needs to also be a layout prop input
    , sourceRepos = helpArg RemoteData.NotAsked
    , orgRepos = helpArg shared.repo.orgRepos.orgRepos
    , builds = helpArg shared.repo.builds.builds
    , deployments = helpArg shared.repo.deployments.deployments
    , build = helpArg shared.repo.build.build
    , repo = helpArg shared.repo.repo
    , hooks = helpArg shared.repo.hooks.hooks

    -- , secrets = helpArg secretsModel.repoSecrets
    , secrets = helpArg RemoteData.NotAsked
    , show = model.showHelp
    , toggle = ShowHideHelp
    , copy = CopyAlert
    , noOp = NoOp
    , page = Pages.NotFound

    -- TODO: use env flag velaDocsURL
    -- , velaDocsURL = model.velaDocsURL
    , velaDocsURL = "https://go-vela.github.io/docs"
    }
