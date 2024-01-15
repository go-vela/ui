module Layouts.Default exposing (Model, Msg, Props, layout, map)

import Alerts exposing (Alert)
import Components.Footer
import Components.Header
import Components.Nav
import Components.Util
import Effect exposing (Effect)
import Help.Commands
import Html exposing (..)
import Html.Attributes exposing (class)
import Layout exposing (Layout)
import Pages
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Toasty as Alerting
import Util
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
        { init = init
        , update = update
        , view = view props shared route
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp
    | CopyAlert String
    | AlertsUpdate (Alerting.Msg Alert)
    | SetTheme Theme
    | ShowHideIdentity (Maybe Bool)
    | ShowHideHelp (Maybe Bool)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        CopyAlert contentCopied ->
            ( model
            , Effect.showCopyToClipboardAlert { contentCopied = contentCopied }
            )

        AlertsUpdate alert ->
            ( model
            , Effect.alertsUpdate alert
            )

        SetTheme _ ->
            ( model
            , Effect.none
            )

        ShowHideIdentity _ ->
            ( model
            , Effect.none
            )

        ShowHideHelp _ ->
            ( model
            , Effect.none
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



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
            , help = helpArgs shared
            , showId = shared.showIdentity
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


helpArg : WebData a -> Help.Commands.Arg
helpArg arg =
    { success = Util.isSuccess arg, loading = Util.isLoading arg }


helpArgs : Shared.Model -> Help.Commands.Model Msg
helpArgs shared =
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
    , show = shared.showHelp
    , toggle = ShowHideHelp
    , copy = CopyAlert
    , noOp = NoOp
    , page = Pages.NotFound

    -- TODO: use env flag velaDocsURL
    -- , velaDocsURL = model.velaDocsURL
    , velaDocsURL = "https://go-vela.github.io/docs"
    }
