module Shared exposing (Flags, Model, Msg, decoder, init, update)

-- todo: these need to be refined, only expose what is needed

import Alerts
import Api.Api as Api
import Api.Endpoint as Endpoint exposing (Endpoint)
import Api.Operations_ exposing (updateCurrentUser)
import Auth.Session exposing (..)
import Browser.Dom exposing (..)
import Browser.Events exposing (Visibility(..))
import Dict exposing (..)
import Effect exposing (Effect)
import Errors exposing (Error, addError, toFailure)
import Favorites exposing (addFavorite, toFavorite, updateFavorites)
import Http
import Http.Detailed
import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Pages exposing (..)
import RemoteData exposing (..)
import Route exposing (Route)
import Shared.Model
import Shared.Msg
import Task exposing (Task)
import Time exposing (..)
import Toasty as Alerting
import Url exposing (..)
import Util exposing (..)
import Vela exposing (UpdateUserPayload, buildUpdateFavoritesPayload, defaultFavicon, defaultPipeline, defaultPipelineTemplates, defaultRepoModel, encodeUpdateUser, stringToTheme)



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


init : Result Decode.Error Flags -> Route () -> Url -> ( Model, Effect Msg )
init flagsResult route url =
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
      , fetchingToken = String.length flags.velaRedirect == 0
      , user = NotAsked
      , sourceRepos = NotAsked
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
      , filters = Dict.empty
      , repo = defaultRepoModel
      , entryURL = url
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

        Shared.Msg.ToggleFavorites options ->
            let
                favorite =
                    toFavorite options.org options.maybeRepo

                ( favorites, favorited ) =
                    updateFavorites model.user favorite

                payload : UpdateUserPayload
                payload =
                    buildUpdateFavoritesPayload favorites

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
                    ( { model | user = toFailure error }
                    , Errors.addError Shared.Msg.HandleError error |> Effect.sendCmd
                    )

        -- ERRORS
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



-- SUBSCRIPTIONS
-- todo: vader: move Main.elm subscriptions into shared


subscriptions : () -> Model -> Sub Msg
subscriptions route model =
    Sub.none



-- API
-- todo: vader: this should be moved when we can solve the cyclical dependency
-- {-| RequestConfig : a basic configuration record for an API request
-- -}
-- type alias RequestConfig a =
--     { method : String
--     , headers : List Http.Header
--     , url : String
--     , body : Http.Body
--     , decoder : Decoder a
--     }
-- {-| Request : wraps a configuration for an API request
-- -}
-- type Request a
--     = Request (RequestConfig a)
-- {-| request : turn a request configuration into a request
-- -}
-- request : RequestConfig a -> Request a
-- request =
--     Request
-- {-| toTask : turn a request config into an HTTP task
-- -}
-- toTask : Request a -> Task (Http.Detailed.Error String) ( Http.Metadata, a )
-- toTask (Request config) =
--     Http.riskyTask
--         { body = config.body
--         , headers = config.headers
--         , method = config.method
--         , resolver = Http.stringResolver <| Http.Detailed.responseToJson config.decoder
--         , timeout = Nothing
--         , url = config.url
--         }
-- {-| try : default way to request information from an endpoint
--     example usage:
--         Api.try UserResponse <| Api.getUser model authParams
-- -}
-- try : (Result (Http.Detailed.Error String) ( Http.Metadata, a ) -> msg) -> Request a -> Effect msg
-- try msg request_ =
--     toTask request_
--         |> Task.attempt msg
--         |> Effect.sendCmd
--         -- map to Effect
--         -- or put this directly into Effects
-- {-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-- -}
-- updateCurrentUser : Model -> Http.Body -> Request CurrentUser
-- updateCurrentUser model body =
--     put model.velaAPI Endpoint.CurrentUser body decodeCurrentUser
--         |> withAuth model.session
-- {-| put : creates a PUT request configuration
-- -}
-- put : String -> Endpoint -> Http.Body -> Decoder b -> Request b
-- put api endpoint body d =
--     request
--         { method = "PUT"
--         , headers = []
--         , url = Endpoint.toUrl api endpoint
--         , body = body
--         , decoder = d
--         }
-- {-| withAuth : returns an auth header with given Bearer token
-- -}
-- withAuth : Session -> Request a -> Request a
-- withAuth session (Request config) =
--     let
--         token : String
--         token =
--             case session of
--                 Unauthenticated ->
--                     ""
--                 Authenticated auth ->
--                     auth.token
--     in
--     request { config | headers = Http.header "authorization" ("Bearer " ++ token) :: config.headers }
