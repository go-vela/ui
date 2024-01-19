{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared exposing (Flags, Model, Msg, decoder, init, subscriptions, update)

-- todo: these need to be refined, only expose what is needed

import Api.Api as Api
import Api.Operations
import Auth.Jwt
import Auth.Session exposing (..)
import Browser.Dom exposing (..)
import Browser.Events exposing (Visibility(..))
import Components.Alerts as Alerts
import Components.Favorites as Favorites
import Dict exposing (..)
import Effect exposing (Effect)
import Http
import Http.Detailed
import Interop
import Json.Decode
import Json.Decode.Pipeline exposing (required)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg
import Task
import Time
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


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.succeed Flags
        |> required "isDev" Json.Decode.bool
        |> required "velaAPI" Json.Decode.string
        |> required "velaFeedbackURL" Json.Decode.string
        |> required "velaDocsURL" Json.Decode.string
        |> required "velaTheme" Json.Decode.string
        |> required "velaRedirect" Json.Decode.string
        |> required "velaLogBytesLimit" Json.Decode.int
        |> required "velaMaxBuildLimit" Json.Decode.int
        |> required "velaScheduleAllowlist" Json.Decode.string



-- todo: comments


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
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

        setTimeZone =
            Task.perform (\zone -> Shared.Msg.AdjustTimeZone { zone = zone }) Time.here
                |> Effect.sendCmd

        setTime =
            Task.perform (\time -> Shared.Msg.AdjustTime { time = time }) Time.now
                |> Effect.sendCmd

        setTheme =
            flags.velaTheme
                |> stringToTheme
                |> Vela.encodeTheme
                |> Interop.setTheme
                |> Effect.sendCmd

        fetchInitialToken =
            if String.length flags.velaRedirect == 0 then
                Effect.sendCmd <| Api.try Shared.Msg.TokenResponse <| Api.Operations.getToken flags.velaAPI

            else
                Effect.none
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
      , zone = Time.utc
      , time = Time.millisToPosix 0
      , repo = defaultRepoModel
      , theme = stringToTheme flags.velaTheme
      , shift = False
      , visibility = Visible
      , buildMenuOpen = []
      , favicon = defaultFavicon
      , pipeline = defaultPipeline
      , templates = defaultPipelineTemplates
      }
    , Effect.batch
        [ setTimeZone
        , setTime
        , setTheme
        , fetchInitialToken
        ]
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

        -- TIME
        Shared.Msg.AdjustTimeZone options ->
            ( { model | zone = options.zone }
            , Effect.none
            )

        Shared.Msg.AdjustTime options ->
            ( { model | time = options.time }
            , Effect.none
            )

        -- REFRESH
        Shared.Msg.Tick options ->
            ( model, Effect.none )

        -- AUTH
        Shared.Msg.FinishAuthentication options ->
            ( model
            , Effect.sendCmd <|
                Api.try Shared.Msg.TokenResponse <|
                    Api.Operations.finishAuthentication model.velaAPI <|
                        Vela.AuthParams options.code options.state
            )

        Shared.Msg.Logout ->
            ( model
            , Api.try
                Shared.Msg.LogoutResponse
                (Api.Operations.logout model.velaAPI model.session)
                |> Effect.sendCmd
            )

        Shared.Msg.LogoutResponse _ ->
            ( { model | session = Unauthenticated }
            , Effect.pushPath <| Route.Path.AccountLogin_
            )

        -- USER
        Shared.Msg.GetCurrentUser ->
            ( { model | user = Loading }
            , Api.try
                Shared.Msg.CurrentUserResponse
                (Api.Operations.getCurrentUser model.velaAPI model.session)
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
                (Api.Operations.updateCurrentUser model.velaAPI model.session body)
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

        -- BUILD GRAPH
        Shared.Msg.BuildGraphInteraction _ ->
            ( model, Effect.none )

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

        -- THEME
        Shared.Msg.SetTheme options ->
            if options.theme == model.theme then
                ( model, Effect.none )

            else
                ( { model | theme = options.theme }, Effect.sendCmd <| Interop.setTheme <| Vela.encodeTheme options.theme )

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
        Shared.Msg.FocusOn options ->
            ( model, Browser.Dom.focus options.target |> Task.attempt Shared.Msg.FocusResult |> Effect.sendCmd )

        Shared.Msg.FocusResult result ->
            -- handle success or failure here
            case result of
                Err (Browser.Dom.NotFound _) ->
                    -- unable to find dom 'id'
                    ( model, Effect.none )

                Ok _ ->
                    -- successfully focus the dom
                    ( model, Effect.none )

        Shared.Msg.TokenResponse response ->
            let
                -- todo: how do we capture the scenario where
                -- the user is logged off a page and we need to
                -- redirect them back to the page they were on?
                velaRedirect =
                    case model.velaRedirect of
                        "" ->
                            case Dict.get "from" route.query of
                                Just f ->
                                    f

                                Nothing ->
                                    "/"

                        _ ->
                            model.velaRedirect
            in
            case response of
                Ok ( _, token ) ->
                    let
                        currentSession =
                            model.session

                        payload =
                            Auth.Jwt.extractJwtClaims token

                        newSessionDetails =
                            SessionDetails token payload.exp payload.sub

                        actions =
                            case currentSession of
                                Unauthenticated ->
                                    velaRedirect
                                        |> Route.Path.fromString
                                        |> Maybe.withDefault Route.Path.Home_
                                        |> Effect.pushPath
                                        |> List.singleton

                                Authenticated _ ->
                                    []
                    in
                    ( { model
                        | session = Authenticated newSessionDetails
                        , velaRedirect = ""
                      }
                    , Effect.batch <|
                        actions
                            ++ [ Effect.clearRedirect {}
                               , refreshAccessToken Shared.Msg.RefreshAccessToken newSessionDetails |> Effect.sendCmd
                               ]
                    )

                Err error ->
                    let
                        redirectPage =
                            Effect.none

                        -- case model.page of
                        --     Main.Pages.Model.AccountLogin_ _ ->
                        --         Cmd.none
                        --     _ ->
                        --         Browser.Navigation.pushUrl model.key <| Route.Path.toString Route.Path.Login_
                    in
                    case error of
                        Http.Detailed.BadStatus meta _ ->
                            case meta.statusCode of
                                401 ->
                                    let
                                        actions =
                                            case model.session of
                                                Unauthenticated ->
                                                    [ redirectPage
                                                    , Effect.setRedirect { redirect = velaRedirect }
                                                    ]

                                                Authenticated _ ->
                                                    [ Effect.addAlertError { content = "Your session has expired or you logged in somewhere else, please log in again.", addToastIfUnique = True }
                                                    , redirectPage
                                                    , Effect.setRedirect { redirect = velaRedirect }
                                                    ]
                                    in
                                    ( { model
                                        | session =
                                            Unauthenticated
                                        , velaRedirect = velaRedirect
                                      }
                                    , Effect.batch actions
                                    )

                                _ ->
                                    ( { model
                                        | session = Unauthenticated
                                        , velaRedirect = velaRedirect
                                      }
                                    , Effect.batch
                                        [ Effect.handleHttpError { httpError = error }
                                        , redirectPage
                                        ]
                                    )

                        _ ->
                            ( { model
                                | session = Unauthenticated
                                , velaRedirect = velaRedirect
                              }
                            , Effect.batch
                                [ Effect.handleHttpError { httpError = error }
                                , redirectPage
                                ]
                            )

        Shared.Msg.RefreshAccessToken ->
            ( model
            , Effect.sendCmd <| Api.try Shared.Msg.TokenResponse <| Api.Operations.getToken model.velaAPI
            )


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ model =
    Sub.batch
        [ -- todo: move this to the build graph page, when we have one
          Interop.onGraphInteraction
            (Vela.decodeOnGraphInteraction Shared.Msg.BuildGraphInteraction Shared.Msg.NoOp)
        ]
