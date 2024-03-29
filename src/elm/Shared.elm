{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared exposing (Flags, Model, Msg, decoder, init, subscriptions, update)

import Api.Api as Api
import Api.Operations
import Auth.Jwt
import Auth.Session
import Browser.Dom
import Browser.Events exposing (Visibility(..))
import Components.Alerts
import Dict
import Effect exposing (Effect)
import File.Download
import Http
import Http.Detailed
import Interop
import Json.Decode
import Json.Decode.Pipeline exposing (required)
import RemoteData
import Route exposing (Route)
import Route.Path
import Route.Query
import Shared.Model
import Shared.Msg
import Task
import Time
import Toasty as Alerting
import Url
import Utils.Errors as Errors
import Utils.Favicons as Favicons
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Utils.Theme as Theme
import Vela exposing (defaultUpdateUserPayload)



-- INIT


{-| Model : alias for the main shared model.
-}
type alias Model =
    Shared.Model.Model


{-| Flags : the required flags for the app.
-}
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


{-| decoder : this will ensure the returned required flags are of the proper type.
-}
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


{-| init : takes in a result of flags and a route and returns a model and a message.
-}
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
                |> Theme.stringToTheme
                |> Theme.encodeTheme
                |> Interop.setTheme
                |> Effect.sendCmd

        setFavicon =
            Effect.updateFavicon
                { favicon = Favicons.defaultFavicon }

        fetchInitialToken =
            if String.length flags.velaRedirect == 0 then
                Effect.sendCmd <| Api.try Shared.Msg.TokenResponse <| Api.Operations.getToken flags.velaAPI

            else
                Effect.none

        uiBaseURL =
            route.url |> (\entryUrl -> Url.toString { entryUrl | path = "" })
    in
    ( { -- FLAGS
        velaAPIBaseURL = flags.velaAPI
      , velaFeedbackURL = flags.velaFeedbackURL
      , velaDocsURL = flags.velaDocsURL
      , velaRedirect = flags.velaRedirect
      , velaLogBytesLimit = flags.velaLogBytesLimit
      , velaMaxBuildLimit = flags.velaMaxBuildLimit
      , velaScheduleAllowlist = Util.stringToAllowlist flags.velaScheduleAllowlist

      -- BASE URL
      , velaUIBaseURL = uiBaseURL

      -- AUTH
      , session = Auth.Session.Unauthenticated

      -- USER
      , user = RemoteData.NotAsked

      -- TIME
      , zone = Time.utc
      , time = Time.millisToPosix 0

      -- KEY MODIFIERS
      , shift = False

      -- VISIBILITY
      , visibility = Visible

      -- FAVICON
      , favicon = Favicons.defaultFavicon

      -- THEME
      , theme = Theme.stringToTheme flags.velaTheme

      -- ALERTS
      , toasties = Alerting.initialState

      -- SOURCE REPOS
      , sourceRepos = RemoteData.NotAsked

      -- BUILDS
      , builds = RemoteData.NotAsked

      -- HOOKS
      , hooks = RemoteData.NotAsked
      }
    , Effect.batch
        [ setTimeZone
        , setTime
        , setTheme
        , setFavicon
        , fetchInitialToken
        ]
    )



-- UPDATE


{-| Msg : alias for the main shared message.
-}
type alias Msg =
    Shared.Msg.Msg


{-| update : takes in a route, a message, and a model and returns a new model and a message.
-}
update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        Shared.Msg.NoOp ->
            ( model
            , Effect.none
            )

        -- BROWSER
        Shared.Msg.FocusOn options ->
            ( model
            , Browser.Dom.focus options.target |> Task.attempt Shared.Msg.FocusResult |> Effect.sendCmd
            )

        Shared.Msg.FocusResult result ->
            case result of
                Err (Browser.Dom.NotFound _) ->
                    ( model, Effect.none )

                Ok _ ->
                    ( model, Effect.none )

        Shared.Msg.DownloadFile options ->
            ( model
            , File.Download.string
                options.filename
                "text"
                (options.map options.content)
                |> Effect.sendCmd
            )

        Shared.Msg.OnKeyDown options ->
            ( case options.key of
                "Shift" ->
                    { model | shift = True }

                _ ->
                    model
            , Effect.none
            )

        Shared.Msg.OnKeyUp options ->
            ( case options.key of
                "Shift" ->
                    { model | shift = False }

                _ ->
                    model
            , Effect.none
            )

        Shared.Msg.VisibilityChanged options ->
            ( { model | visibility = options.visibility, shift = False }
            , Effect.none
            )

        -- FAVICON
        Shared.Msg.UpdateFavicon options ->
            let
                ( newFavicon, updateFavicon ) =
                    Favicons.updateFavicon model.favicon options.favicon
            in
            ( { model | favicon = newFavicon }, updateFavicon |> Effect.sendCmd )

        -- TIME
        Shared.Msg.AdjustTimeZone options ->
            ( { model | zone = options.zone }
            , Effect.none
            )

        Shared.Msg.AdjustTime options ->
            ( { model | time = options.time }
            , Effect.none
            )

        -- AUTH
        Shared.Msg.FinishAuthentication options ->
            ( model
            , Effect.sendCmd <|
                Api.try Shared.Msg.TokenResponse <|
                    Api.Operations.finishAuthentication model.velaAPIBaseURL <|
                        Auth.Session.AuthParams options.code options.state
            )

        Shared.Msg.TokenResponse response ->
            let
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

                redirectRoute =
                    Route.parsePath velaRedirect
                        |> (\parsed ->
                                { path = Maybe.withDefault Route.Path.Home_ <| Route.Path.fromString parsed.path
                                , query = Route.Query.fromString <| Maybe.withDefault "" parsed.query
                                , hash = parsed.hash
                                }
                           )
            in
            case response of
                Ok ( _, token ) ->
                    let
                        currentSession =
                            model.session

                        payload =
                            Auth.Jwt.extractJwtClaims token

                        newSessionDetails =
                            Auth.Session.SessionDetails token payload.exp payload.sub

                        redirectEffect =
                            case currentSession of
                                Auth.Session.Unauthenticated ->
                                    Effect.replaceRoute
                                        redirectRoute

                                Auth.Session.Authenticated _ ->
                                    Effect.none
                    in
                    ( { model
                        | session = Auth.Session.Authenticated newSessionDetails
                        , velaRedirect = ""
                      }
                    , Effect.batch <|
                        [ redirectEffect
                        , Effect.clearRedirect {}
                        , Effect.sendCmd <|
                            Auth.Session.refreshAccessToken Shared.Msg.RefreshToken newSessionDetails
                        ]
                    )

                Err error ->
                    let
                        redirectToLogin =
                            case route.path of
                                Route.Path.Account_Login ->
                                    Effect.none

                                _ ->
                                    Effect.replacePath Route.Path.Account_Login
                    in
                    case error of
                        Http.Detailed.BadStatus meta _ ->
                            case meta.statusCode of
                                401 ->
                                    let
                                        actions =
                                            case model.session of
                                                Auth.Session.Unauthenticated ->
                                                    [ redirectToLogin
                                                    , Effect.setRedirect { redirect = velaRedirect }
                                                    ]

                                                Auth.Session.Authenticated _ ->
                                                    [ redirectToLogin
                                                    , Effect.setRedirect { redirect = velaRedirect }
                                                    , Effect.addAlertError
                                                        { content = "Your session has expired or you logged in somewhere else, please log in again."
                                                        , addToastIfUnique = True
                                                        , link = Nothing
                                                        }
                                                    ]
                                    in
                                    ( { model
                                        | session =
                                            Auth.Session.Unauthenticated
                                        , velaRedirect = velaRedirect
                                      }
                                    , Effect.batch actions
                                    )

                                _ ->
                                    ( { model
                                        | session = Auth.Session.Unauthenticated
                                        , velaRedirect = velaRedirect
                                      }
                                    , Effect.batch
                                        [ redirectToLogin
                                        , Effect.setRedirect { redirect = velaRedirect }
                                        , Effect.handleHttpError
                                            { error = error
                                            , shouldShowAlertFn = Errors.showAlertAlways
                                            }
                                        ]
                                    )

                        _ ->
                            ( { model
                                | session = Auth.Session.Unauthenticated
                                , velaRedirect = velaRedirect
                              }
                            , Effect.batch
                                [ redirectToLogin
                                , Effect.setRedirect { redirect = velaRedirect }
                                , Effect.handleHttpError
                                    { error = error
                                    , shouldShowAlertFn = Errors.showAlertAlways
                                    }
                                ]
                            )

        Shared.Msg.RefreshToken ->
            ( model
            , Effect.sendCmd <|
                Api.try Shared.Msg.TokenResponse <|
                    Api.Operations.getToken model.velaAPIBaseURL
            )

        Shared.Msg.Logout options ->
            ( model
            , Effect.batch
                [ Effect.setRedirect { redirect = Maybe.withDefault "/" options.from }
                , Api.try
                    (Shared.Msg.LogoutResponse options)
                    (Api.Operations.logout model.velaAPIBaseURL model.session)
                    |> Effect.sendCmd
                ]
            )

        Shared.Msg.LogoutResponse options _ ->
            let
                from =
                    Maybe.withDefault "/" options.from
            in
            ( { model | session = Auth.Session.Unauthenticated, velaRedirect = from }
            , Effect.replaceRoute <|
                { path = Route.Path.Account_Login
                , query =
                    Dict.fromList
                        [ ( "from", from ) ]
                , hash = Nothing
                }
            )

        -- USER
        Shared.Msg.GetCurrentUser ->
            ( model
            , Api.try
                Shared.Msg.CurrentUserResponse
                (Api.Operations.getCurrentUser model.velaAPIBaseURL model.session)
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
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- SOURCE REPOS
        Shared.Msg.UpdateSourceRepos options ->
            ( { model | sourceRepos = options.sourceRepos }
            , Effect.none
            )

        -- FAVORITES
        Shared.Msg.UpdateFavorite options ->
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

                payload =
                    { defaultUpdateUserPayload | favorites = Just favorites }

                body =
                    Http.jsonBody <| Vela.encodeUpdateUser payload
            in
            ( model
            , Api.try
                (Shared.Msg.UpdateFavoriteResponse { favorite = favorite, favorited = favorited })
                (Api.Operations.updateCurrentUser model.velaAPIBaseURL model.session body)
                |> Effect.sendCmd
            )

        Shared.Msg.UpdateFavoriteResponse options response ->
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
                    , Effect.addAlertSuccess { content = alertMsg, addToastIfUnique = True, link = Nothing }
                    )

                Err error ->
                    ( { model | user = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        Shared.Msg.AddFavorites options ->
            let
                favorites =
                    Favorites.addFavorites model.user options.favorites

                payload =
                    { defaultUpdateUserPayload | favorites = Just favorites }

                body =
                    Http.jsonBody <| Vela.encodeUpdateUser payload
            in
            ( model
            , Api.try
                (Shared.Msg.AddFavoritesResponse { favorites = options.favorites })
                (Api.Operations.updateCurrentUser model.velaAPIBaseURL model.session body)
                |> Effect.sendCmd
            )

        Shared.Msg.AddFavoritesResponse options response ->
            case response of
                Ok ( _, user ) ->
                    let
                        alertMsg =
                            (String.fromInt <| List.length options.favorites) ++ " repo(s) added to favorites."
                    in
                    ( { model | user = RemoteData.succeed user }
                    , Effect.addAlertSuccess { content = alertMsg, addToastIfUnique = True, link = Nothing }
                    )

                Err error ->
                    ( { model | user = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- BUILDS
        Shared.Msg.GetRepoBuilds options ->
            ( model
            , Api.try
                Shared.Msg.GetRepoBuildsResponse
                (Api.Operations.getRepoBuilds model.velaAPIBaseURL model.session options)
                |> Effect.sendCmd
            )

        Shared.Msg.GetRepoBuildsResponse response ->
            case response of
                Ok ( _, builds ) ->
                    ( { model | builds = RemoteData.succeed builds }
                    , Effect.none
                    )

                Err error ->
                    ( { model | builds = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- HOOKS
        Shared.Msg.GetRepoHooks options ->
            ( model
            , Api.try
                Shared.Msg.GetRepoHooksResponse
                (Api.Operations.getRepoHooks model.velaAPIBaseURL model.session options)
                |> Effect.sendCmd
            )

        Shared.Msg.GetRepoHooksResponse response ->
            case response of
                Ok ( _, hooks ) ->
                    ( { model | hooks = RemoteData.succeed hooks }
                    , Effect.none
                    )

                Err error ->
                    ( { model | hooks = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- THEME
        Shared.Msg.SetTheme options ->
            if options.theme == model.theme then
                ( model, Effect.none )

            else
                ( { model | theme = options.theme }
                , Effect.sendCmd <| Interop.setTheme <| Theme.encodeTheme options.theme
                )

        -- ALERTS
        Shared.Msg.AlertsUpdate subMsg ->
            Alerting.update Components.Alerts.successConfig Shared.Msg.AlertsUpdate subMsg model
                |> Tuple.mapSecond Effect.sendCmd

        Shared.Msg.AddAlertSuccess options ->
            let
                addAlertFn =
                    if options.addToastIfUnique then
                        Alerting.addToastIfUnique

                    else
                        Alerting.addToast
            in
            addAlertFn Components.Alerts.successConfig
                Shared.Msg.AlertsUpdate
                (Components.Alerts.Success "Success" options.content options.link)
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
            addAlertFn Components.Alerts.errorConfig
                Shared.Msg.AlertsUpdate
                (Components.Alerts.Error "Error" options.content)
                ( model, Cmd.none )
                |> Tuple.mapSecond Effect.sendCmd

        -- ERRORS
        Shared.Msg.HandleHttpError options ->
            let
                ( shared, redirect ) =
                    case options.error of
                        -- todo: maybe we pass in a status code we want to ignore
                        --   so secrets can skip this alert for 401s
                        --
                        -- Http.Detailed.BadStatus meta _ ->
                        --     case meta.statusCode of
                        --         -- todo: FIX THIS! secrets can easily return a 401 for normal reasons
                        --         401 ->
                        --             ( { model
                        --                 | session = Auth.Session.Unauthenticated
                        --                 , velaRedirect = "/"
                        --               }
                        --                      , Effect.replacePath <| Route.Path.Account_Login
                        --             )
                        --         _ ->
                        --             ( model, Effect.none )
                        _ ->
                            ( model, Effect.none )
            in
            ( shared
            , Effect.batch
                [ if options.shouldShowAlertFn options.error then
                    Effect.addAlertError
                        { content = Errors.detailedErrorToString options.error
                        , addToastIfUnique = True
                        , link = Nothing
                        }

                  else
                    Effect.none
                , redirect
                ]
            )

        -- REFRESH
        Shared.Msg.Tick options ->
            case options.interval of
                Interval.OneSecond ->
                    ( { model | time = options.time }, Effect.none )

                Interval.FiveSeconds ->
                    ( model, Effect.none )


{-| subscriptions : takes in a route and model and returns a subscription message.
-}
subscriptions : Route () -> Model -> Sub Msg
subscriptions _ model =
    Sub.batch
        [ Interval.tickEveryOneSecond Shared.Msg.Tick
        , Interval.tickEveryFiveSeconds Shared.Msg.Tick
        , Browser.Events.onKeyDown
            (Json.Decode.map
                (\key -> Shared.Msg.OnKeyDown { key = key })
                (Json.Decode.field "key" Json.Decode.string)
            )
        , Browser.Events.onKeyUp
            (Json.Decode.map
                (\key -> Shared.Msg.OnKeyUp { key = key })
                (Json.Decode.field "key" Json.Decode.string)
            )
        , Browser.Events.onVisibilityChange
            (\visibility -> Shared.Msg.VisibilityChanged { visibility = visibility })
        ]
