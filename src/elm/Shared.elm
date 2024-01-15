module Shared exposing (Flags, Model, Msg, decoder, init, update)

-- todo: these need to be refined, only expose what is needed

import Alerts
import Api.Api as Api
import Api.Operations_
import Auth.Session exposing (..)
import Browser.Dom exposing (..)
import Browser.Events exposing (Visibility(..))
import Dict exposing (..)
import Effect exposing (Effect)
import Errors
import Favorites
import Http
import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Pages exposing (..)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg
import Time exposing (..)
import Toasty as Alerting
import Url exposing (..)
import Util exposing (..)
import Vela
    exposing
        ( UpdateUserPayload
        , defaultFavicon
        , defaultPipeline
        , defaultPipelineTemplates
        , defaultRepoModel
        , encodeUpdateUser
        , stringToTheme
        )



-- INIT


type alias Model =
    Shared.Model.Model



-- todo: comments, what goes in here, why


type alias Flags =
    { isDev : Bool
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaTheme : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , velaScheduleAllowlist : String
    }


decoder : Decode.Decoder Flags
decoder =
    Decode.succeed Flags
        |> required "isDev" Decode.bool
        |> required "velaAPI" Decode.string
        |> required "velaFeedbackURL" Decode.string
        |> required "velaDocsURL" Decode.string
        |> required "velaTheme" Decode.string
        |> required "velaRedirect" Decode.string
        |> required "velaLogBytesLimit" Decode.int
        |> required "velaMaxBuildLimit" Decode.int
        |> required "velaScheduleAllowlist" Decode.string



-- todo: comments


init : Result Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
        flags : Flags
        flags =
            case flagsResult of
                Ok value ->
                    value

                Err reason ->
                    -- something went wrong with the flags decoder
                    -- todo: log the error, crash the app, what to do here
                    -- and how did Elm handle this before manually decoding
                    { isDev = True
                    , velaAPI = ""
                    , velaFeedbackURL = ""
                    , velaDocsURL = ""
                    , velaTheme = ""
                    , velaRedirect = ""
                    , velaLogBytesLimit = 0
                    , velaMaxBuildLimit = 0
                    , velaScheduleAllowlist = ""
                    }
    in
    -- todo: these need to be logically ordered (flags, session, user, data models, etc)
    ( { session = Unauthenticated
      , user = NotAsked
      , velaAPI = flags.velaAPI
      , velaFeedbackURL = flags.velaFeedbackURL
      , velaDocsURL = flags.velaDocsURL
      , velaRedirect = flags.velaRedirect
      , velaLogBytesLimit = flags.velaLogBytesLimit
      , velaMaxBuildLimit = flags.velaMaxBuildLimit
      , velaScheduleAllowlist = Util.stringToAllowlist flags.velaScheduleAllowlist
      , toasties = Alerting.initialState
      , zone = utc
      , time = millisToPosix 0
      , repo = defaultRepoModel
      , theme = stringToTheme flags.velaTheme
      , shift = False
      , visibility = Visible
      , showHelp = False
      , showIdentity = False
      , buildMenuOpen = []
      , favicon = defaultFavicon
      , pipeline = defaultPipeline
      , templates = defaultPipelineTemplates

      -- todo: these need to be refactored with Msg
      -- , schedulesModel = initSchedulesModel
      -- , secretsModel = initSecretsModel
      -- , deploymentModel = initDeploymentsModel
      }
    , Effect.none
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        Shared.Msg.NoOp ->
            ( model
            , Effect.none
            )

        -- AUTH
        Shared.Msg.Logout ->
            ( model
            , Api.try
                Shared.Msg.LogoutResponse
                (Api.Operations_.logout model.velaAPI model.session)
                |> Effect.sendCmd
            )

        Shared.Msg.LogoutResponse _ ->
            ( { model | session = Unauthenticated }
            , Effect.pushPath <| Route.Path.Login_
            )

        -- USER
        Shared.Msg.GetCurrentUser ->
            ( { model | user = Loading }
            , Api.try
                Shared.Msg.CurrentUserResponse
                (Api.Operations_.getCurrentUser model.velaAPI model.session)
                |> Effect.sendCmd
            )

        Shared.Msg.CurrentUserResponse response ->
            case response of
                Ok ( _, user ) ->
                    ( { model | user = RemoteData.succeed user }
                    , Effect.none
                    )

                Err error ->
                    ( { model | user = Errors.toFailure error }
                    , Effect.addError error
                    )

        -- FAVORITES
        Shared.Msg.ToggleFavorites options ->
            let
                favorite =
                    Favorites.toFavorite options.org options.maybeRepo

                ( favorites, favorited ) =
                    Favorites.updateFavorites model.user favorite

                payload : UpdateUserPayload
                payload =
                    Vela.buildUpdateFavoritesPayload favorites

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateUser payload
            in
            ( model
            , Api.try
                (Shared.Msg.RepoFavoriteResponse { favorite = favorite, favorited = favorited })
                (Api.Operations_.updateCurrentUser model.velaAPI model.session body)
                |> Effect.sendCmd
            )

        Shared.Msg.RepoFavoriteResponse options response ->
            case response of
                Ok ( _, user ) ->
                    let
                        alertMsg =
                            if options.favorited then
                                options.favorite ++ " added to favorites."

                            else
                                options.favorite ++ " removed from favorites."

                        ( um, cmd ) =
                            Alerting.addToast
                                Alerts.successConfig
                                Shared.Msg.AlertsUpdate
                                (Alerts.Success "Success" alertMsg Nothing)
                                ( { model | user = RemoteData.succeed user }, Cmd.none )
                    in
                    ( um, cmd |> Effect.sendCmd )

                Err error ->
                    ( { model | user = Errors.toFailure error }
                    , Effect.addError error
                    )

        -- PAGINATION
        Shared.Msg.GotoPage options ->
            let
                repo =
                    model.repo

                deployments =
                    model.repo.deployments
            in
            case route.path of
                Route.Path.Org_Repo_Deployments_ params ->
                    ( { model | repo = { repo | deployments = { deployments | deployments = Loading } } }
                    , Effect.pushRoute
                        { path = route.path
                        , query = Dict.update "page" (\_ -> Just <| String.fromInt options.pageNumber) route.query
                        , hash = Just "gotopage"
                        }
                    )

                _ ->
                    ( model, Effect.none )

        -- ERRORS
        Shared.Msg.AddError error ->
            ( model
            , Errors.addError Shared.Msg.HandleError error |> Effect.sendCmd
            )

        Shared.Msg.HandleError error ->
            let
                ( um, cmd ) =
                    Alerting.addToastIfUnique Alerts.errorConfig
                        Shared.Msg.AlertsUpdate
                        (Alerts.Error "Error" error)
                        ( model, Cmd.none )
            in
            ( um, cmd |> Effect.sendCmd )

        -- ALERTS
        Shared.Msg.AlertsUpdate subMsg ->
            let
                ( um, cmd ) =
                    Alerting.update Alerts.successConfig Shared.Msg.AlertsUpdate subMsg model
            in
            ( um, cmd |> Effect.sendCmd )

        -- MISC
        Shared.Msg.ShowCopyToClipboardAlert options ->
            let
                ( sharedWithAlert, cmd ) =
                    Alerting.addToast Alerts.successConfig
                        Shared.Msg.AlertsUpdate
                        (Alerts.Success ""
                            ("Copied " ++ Alerts.wrapAlertMessage options.contentCopied ++ "to your clipboard.")
                            Nothing
                        )
                        ( model, Cmd.none )
            in
            ( sharedWithAlert, cmd |> Effect.sendCmd )



-- SUBSCRIPTIONS
-- todo: vader: move Main.elm subscriptions into shared and pages


subscriptions : () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
