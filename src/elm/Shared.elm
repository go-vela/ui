{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared exposing (Flags, Model, Msg, decoder, init, subscriptions, update)

-- todo: these need to be refined, only expose what is needed

import Api.Api as Api
import Api.Operations_
import Auth.Session exposing (..)
import Browser.Dom exposing (..)
import Browser.Events exposing (Visibility(..))
import Components.Alerts as Alerts
import Components.Favorites as Favorites
import Dict exposing (..)
import Effect exposing (Effect)
import Http
import Interop
import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Pages exposing (..)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg
import Task
import Time exposing (..)
import Toasty as Alerting
import Url exposing (..)
import Utils.Errors as Errors
import Utils.Helpers as Util exposing (..)
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

        -- THEME
        Shared.Msg.SetTheme theme ->
            if theme == model.theme then
                ( model, Effect.none )

            else
                ( { model | theme = theme }, Effect.sendCmd <| Interop.setTheme <| Vela.encodeTheme theme )

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
                    , Effect.handleHttpError { httpError = error }
                    )

        -- FAVORITES
        Shared.Msg.UpdateFavorites options ->
            let
                favorite =
                    Favorites.toFavorite options.org options.maybeRepo

                favoriteUpdateFn =
                    case options.updateType of
                        Favorites.Add ->
                            Favorites.addFavorite

                        Favorites.Toggle ->
                            Favorites.toggleFavorite

                ( favorites, favorited ) =
                    favoriteUpdateFn model.user favorite

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
                    in
                    ( { model | user = RemoteData.succeed user }
                    , Effect.addAlertSuccess { content = alertMsg, addToastIfUnique = True }
                    )

                Err error ->
                    ( { model | user = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
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

        -- ALERTS
        Shared.Msg.AlertsUpdate subMsg ->
            Alerting.update Alerts.successConfig Shared.Msg.AlertsUpdate subMsg model
                |> Tuple.mapSecond Effect.sendCmd

        Shared.Msg.AddAlertSuccess options ->
            let
                addAlertFn =
                    if options.addToastIfUnique then
                        Alerting.addToastIfUnique

                    else
                        Alerting.addToast
            in
            addAlertFn Alerts.successConfig
                Shared.Msg.AlertsUpdate
                (Alerts.Success "Success" options.content Nothing)
                ( model, Cmd.none )
                |> Tuple.mapSecond Effect.sendCmd

        Shared.Msg.AddAlertError options ->
            let
                addAlertFn =
                    if options.addToastIfUnique then
                        Alerting.addToastIfUnique

                    else
                        Alerting.addToast
            in
            addAlertFn Alerts.errorConfig
                Shared.Msg.AlertsUpdate
                (Alerts.Error "Error" options.content)
                ( model, Cmd.none )
                |> Tuple.mapSecond Effect.sendCmd

        -- ERRORS
        Shared.Msg.HandleHttpError error ->
            ( model
            , Effect.addAlertError { content = Errors.detailedErrorToString error, addToastIfUnique = True }
            )

        -- DOM
        Shared.Msg.FocusOn target ->
            ( model, Browser.Dom.focus target |> Task.attempt Shared.Msg.FocusResult |> Effect.sendCmd )

        Shared.Msg.FocusResult result ->
            -- handle success or failure here
            case result of
                Err (Browser.Dom.NotFound _) ->
                    -- unable to find dom 'id'
                    ( model, Effect.none )

                Ok _ ->
                    -- successfully focus the dom
                    ( model, Effect.none )


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ model =
    Sub.none
