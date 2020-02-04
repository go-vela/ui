{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Main exposing (main)

import Alerts exposing (Alert)
import Api
import Api.Pagination as Pagination
import Browser exposing (Document, UrlRequest)
import Browser.Dom as Dom
import Browser.Events exposing (Visibility(..))
import Browser.Navigation as Navigation
import Dict
import Errors exposing (detailedErrorToString)
import Favorites exposing (toFavorite, updateFavorites)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , details
        , div
        , footer
        , h1
        , header
        , li
        , main_
        , nav
        , p
        , summary
        , text
        , ul
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        )
import Html.Events exposing (onClick)
import Html.Lazy exposing (lazy, lazy2, lazy3, lazy4, lazy7)
import Http exposing (Error(..))
import Http.Detailed
import Interop
import Json.Decode as Decode exposing (string)
import Json.Encode as Encode
import List.Extra exposing (setIf, updateIf)
import Logs
    exposing
        ( focusFragmentToFocusId
        , focusLogs
        , focusStep
        , logFocusExists
        , logFocusFragment
        )
import Nav
import Pager
import Pages exposing (Page(..))
import Pages.AddRepos
import Pages.Build
    exposing
        ( clickStep
        , viewingStep
        )
import Pages.Builds exposing (view)
import Pages.Home
import Pages.Hooks
import Pages.Settings exposing (enableUpdate)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (velaLogo)
import Task exposing (perform, succeed)
import Time
    exposing
        ( Posix
        , Zone
        , every
        , here
        , millisToPosix
        , utc
        )
import Toasty as Alerting exposing (Stack)
import Url exposing (Url)
import Url.Builder as UB exposing (QueryParameter)
import Util
import Vela
    exposing
        ( AuthParams
        , Build
        , BuildIdentifier
        , BuildNumber
        , Builds
        , BuildsModel
        , CurrentUser
        , EnableRepo
        , EnableRepos
        , EnableRepositoryPayload
        , Enabling(..)
        , Field
        , FocusFragment
        , HookBuilds
        , Hooks
        , HooksModel
        , Log
        , Logs
        , Org
        , Repo
        , RepoSearchFilters
        , Repositories
        , Repository
        , Session
        , SourceRepositories
        , Step
        , StepNumber
        , Steps
        , Theme(..)
        , UpdateRepositoryPayload
        , UpdateUserPayload
        , User
        , Viewing
        , buildUpdateFavoritesPayload
        , buildUpdateRepoBoolPayload
        , buildUpdateRepoIntPayload
        , buildUpdateRepoStringPayload
        , decodeSession
        , decodeTheme
        , defaultBuilds
        , defaultEnableRepositoryPayload
        , defaultHooks
        , defaultRepository
        , defaultSession
        , encodeEnableRepository
        , encodeSession
        , encodeTheme
        , encodeUpdateRepository
        , encodeUpdateUser
        , stringToTheme
        )



-- TYPES


type alias Flags =
    { isDev : Bool
    , velaAPI : String
    , velaSourceBaseURL : String
    , velaSourceClient : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaSession : Maybe Session
    , velaTheme : String
    }


type alias Model =
    { page : Page
    , session : Maybe Session
    , user : WebData CurrentUser
    , toasties : Stack Alert
    , sourceRepos : WebData SourceRepositories
    , hooks : HooksModel
    , builds : BuildsModel
    , build : WebData Build
    , steps : WebData Steps
    , logs : Logs
    , velaAPI : String
    , velaSourceBaseURL : String
    , velaSourceOauthStartURL : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , navigationKey : Navigation.Key
    , zone : Zone
    , time : Posix
    , filters : RepoSearchFilters
    , favoritesFilter : String
    , repo : WebData Repository
    , inTimeout : Maybe Int
    , entryURL : Url
    , hookBuilds : HookBuilds
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    }


type Interval
    = OneSecond
    | FiveSecond RefreshData


type alias RefreshData =
    { org : Org
    , repo : Repo
    , build_number : Maybe BuildNumber
    , steps : Maybe Steps
    }


init : Flags -> Url -> Navigation.Key -> ( Model, Cmd Msg )
init flags url navKey =
    let
        model : Model
        model =
            { page = Pages.Overview
            , session = flags.velaSession
            , user = NotAsked
            , sourceRepos = NotAsked
            , velaAPI = flags.velaAPI
            , hooks = defaultHooks
            , builds = defaultBuilds
            , build = NotAsked
            , steps = NotAsked
            , logs = []
            , velaSourceOauthStartURL =
                buildUrl flags.velaSourceBaseURL
                    [ "login"
                    , "oauth"
                    , "authorize"
                    ]
                    [ UB.string "scope" "user repo" -- access we need
                    , UB.string "state" "1234"
                    , UB.string "client_id" flags.velaSourceClient
                    ]
            , velaSourceBaseURL = flags.velaSourceBaseURL
            , velaFeedbackURL = flags.velaFeedbackURL
            , velaDocsURL = flags.velaDocsURL
            , navigationKey = navKey
            , toasties = Alerting.initialState
            , zone = utc
            , time = millisToPosix 0
            , filters = Dict.empty
            , favoritesFilter = ""
            , repo = RemoteData.succeed defaultRepository
            , inTimeout = Nothing
            , entryURL = url
            , hookBuilds = Dict.empty
            , theme = stringToTheme flags.velaTheme
            , shift = False
            , visibility = Visible
            }

        ( newModel, newPage ) =
            setNewPage (Routes.match url) model

        setTimeZone =
            Task.perform AdjustTimeZone here

        setTime =
            Task.perform AdjustTime Time.now
    in
    ( newModel
    , Cmd.batch
        [ newPage

        -- for themes, we rely on ports to apply the class on <body>
        , Interop.setTheme <| encodeTheme model.theme
        , setTimeZone
        , setTime
        ]
    )



-- UPDATE


type Msg
    = NoOp
      -- User events
    | NewRoute Routes.Route
    | ClickedLink UrlRequest
    | SearchSourceRepos Org String
    | SearchFavorites String
    | ChangeRepoTimeout String
    | RefreshSettings Org Repo
    | ClickHook Org Repo BuildNumber
    | SetTheme Theme
    | ClickStep Org Repo BuildNumber StepNumber String
    | GotoPage Pagination.Page
      -- Outgoing HTTP requests
    | SignInRequested
    | FetchSourceRepositories
    | ToggleFavorite Org (Maybe Repo)
    | EnableRepo Repository
    | UpdateRepoEvent Org Repo Field Bool
    | UpdateRepoAccess Org Repo Field String
    | UpdateRepoTimeout Org Repo Field Int
    | EnableRepos Repositories
    | DisableRepo Repository
    | RestartBuild Org Repo BuildNumber
      -- Inbound HTTP responses
    | UserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, User ))
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | RepoFavoritedResponse String Bool (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | HooksResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | HookBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | RepoEnabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoDisabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | StepsResponse Org Repo BuildNumber (Maybe String) (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | StepLogResponse FocusFragment (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
      -- Other
    | Error String
    | AlertsUpdate (Alerting.Msg Alert)
    | SessionChanged (Maybe Session)
    | FocusOn String
    | FocusResult (Result Dom.Error ())
    | OnKeyDown String
    | OnKeyUp String
    | UpdateUrl String
    | VisibilityChanged Visibility
      -- Time
    | AdjustTimeZone Zone
    | AdjustTime Posix
    | Tick Interval Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateUrl url ->
            ( model
            , Navigation.pushUrl model.navigationKey url
            )

        NewRoute route ->
            setNewPage route model

        SignInRequested ->
            ( model, Navigation.load model.velaSourceOauthStartURL )

        SessionChanged newSession ->
            ( { model | session = newSession }, Cmd.none )

        FetchSourceRepositories ->
            ( { model | sourceRepos = Loading, filters = Dict.empty }, Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model )

        ToggleFavorite org repo ->
            let
                favorite =
                    toFavorite org repo

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
            , Api.try (RepoFavoritedResponse favorite favorited) (Api.updateCurrentUser model body)
            )

        EnableRepo repo ->
            let
                payload : EnableRepositoryPayload
                payload =
                    buildEnableRepositoryPayload repo model.velaSourceBaseURL

                body : Http.Body
                body =
                    Http.jsonBody <| encodeEnableRepository payload

                currentRepo =
                    RemoteData.withDefault defaultRepository model.repo
            in
            ( { model
                | sourceRepos = enableUpdate repo Loading model.sourceRepos
                , repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Enabling }
              }
            , Api.try (RepoEnabledResponse repo) <| Api.addRepository model body
            )

        UserResponse response ->
            case response of
                Ok ( _, user ) ->
                    let
                        currentSession : Session
                        currentSession =
                            Maybe.withDefault defaultSession model.session

                        session : Session
                        session =
                            { currentSession | username = user.username, token = user.token }

                        redirectTo : String
                        redirectTo =
                            case session.entrypoint of
                                "" ->
                                    Routes.routeToUrl Routes.Overview

                                _ ->
                                    session.entrypoint
                    in
                    ( { model | session = Just session }
                    , Cmd.batch
                        [ Interop.storeSession <| encodeSession session
                        , Navigation.pushUrl model.navigationKey redirectTo
                        ]
                    )

                Err error ->
                    ( { model | session = Nothing }
                    , Cmd.batch
                        [ addError error
                        , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Login
                        ]
                    )

        CurrentUserResponse response ->
            case response of
                Ok ( _, user ) ->
                    ( { model | user = RemoteData.succeed user }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

        RepoResponse response ->
            case response of
                Ok ( _, repoResponse ) ->
                    ( { model | repo = RemoteData.succeed repoResponse }, Cmd.none )

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

        SourceRepositoriesResponse response ->
            case response of
                Ok ( _, repositories ) ->
                    ( { model | sourceRepos = RemoteData.succeed repositories }, Cmd.none )

                Err error ->
                    ( { model | sourceRepos = toFailure error }, addError error )

        RepoEnabledResponse repo response ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository model.repo
            in
            case response of
                Ok ( _, enabledRepo ) ->
                    ( { model
                        | sourceRepos = enableUpdate enabledRepo (RemoteData.succeed True) model.sourceRepos
                        , repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Enabled }
                      }
                    , Cmd.none
                    )
                        |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Success "Success" (enabledRepo.full_name ++ " enabled.") Nothing)

                Err error ->
                    let
                        ( sourceRepos, action ) =
                            repoEnabledError model.sourceRepos repo error
                    in
                    ( { model | sourceRepos = sourceRepos }, action )

        RepoFavoritedResponse favorite favorited response ->
            case response of
                Ok ( _, user ) ->
                    ( { model | user = RemoteData.succeed user }
                    , Cmd.none
                    )
                        |> (if favorited then
                                Alerting.addToast Alerts.config AlertsUpdate (Alerts.Success "Success" (favorite ++ " added to favorites.") Nothing)

                            else
                                Alerting.addToast Alerts.config AlertsUpdate (Alerts.Success "Success" (favorite ++ " removed from favorites.") Nothing)
                           )

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

        RepoUpdatedResponse field response ->
            case response of
                Ok ( _, updatedRepo ) ->
                    ( { model | repo = RemoteData.succeed updatedRepo }, Cmd.none )
                        |> Alerting.addToast Alerts.config AlertsUpdate (Alerts.Success "Success" (Pages.Settings.alert field updatedRepo) Nothing)

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

        DisableRepo repo ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository model.repo

                ( status, action ) =
                    case repo.enabling of
                        Vela.Enabled ->
                            ( Vela.ConfirmDisable, Cmd.none )

                        Vela.ConfirmDisable ->
                            ( Vela.Disabling, Api.try (RepoDisabledResponse repo) <| Api.deleteRepo model repo )

                        _ ->
                            ( repo.enabling, Cmd.none )
            in
            ( { model
                | repo = RemoteData.succeed <| { currentRepo | enabling = status }
              }
            , action
            )

        RepoDisabledResponse repo response ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository model.repo
            in
            case response of
                Ok _ ->
                    ( { model
                        | repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Disabled }
                        , sourceRepos = enableUpdate repo NotAsked model.sourceRepos
                      }
                    , Cmd.none
                    )
                        |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " disabled.") Nothing)

                Err error ->
                    ( model, addError error )

        RestartedBuildResponse org repo buildNumber response ->
            case response of
                Ok ( _, build ) ->
                    let
                        restartedBuild =
                            "Build " ++ String.join "/" [ org, repo, buildNumber ]

                        newBuildNumber =
                            String.fromInt <| build.number

                        newBuild =
                            String.join "/" [ "", org, repo, newBuildNumber ]
                    in
                    ( model
                    , getBuilds model org repo Nothing Nothing
                    )
                        |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Success "Success" (restartedBuild ++ " restarted.") (Just ( "View Build #" ++ newBuildNumber, newBuild )))

                Err error ->
                    ( model, addError error )

        BuildResponse org repo _ response ->
            case response of
                Ok ( _, build ) ->
                    let
                        builds =
                            model.builds
                    in
                    ( { model
                        | builds =
                            { builds
                                | org = org
                                , repo = repo
                            }
                        , build = RemoteData.succeed build
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( model, addError error )

        BuildsResponse org repo response ->
            let
                currentBuilds =
                    model.builds
            in
            case response of
                Ok ( meta, builds ) ->
                    let
                        pager =
                            Pagination.get meta.headers
                    in
                    ( { model
                        | builds =
                            { currentBuilds
                                | org = org
                                , repo = repo
                                , builds = RemoteData.succeed builds
                                , pager = pager
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | builds = { currentBuilds | builds = toFailure error } }, addError error )

        StepResponse _ _ _ _ response ->
            case response of
                Ok ( _, step ) ->
                    ( updateStep model step, Cmd.none )

                Err error ->
                    ( model, addError error )

        StepsResponse org repo buildNumber logFocus response ->
            case response of
                Ok ( _, stepsResponse ) ->
                    let
                        sortedSteps =
                            List.sortBy (\step -> step.number) stepsResponse

                        steps =
                            RemoteData.succeed <| focusStep logFocus sortedSteps

                        cmd =
                            getBuildStepsLogs model org repo buildNumber steps logFocus
                    in
                    ( { model | steps = steps }, cmd )

                Err error ->
                    ( model, addError error )

        StepLogResponse logFocus response ->
            case response of
                Ok ( _, log ) ->
                    let
                        focusId =
                            focusFragmentToFocusId logFocus

                        action =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( updateLogs model log, action )

                Err error ->
                    ( model, addError error )

        UpdateRepoEvent org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoBoolPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload

                action =
                    if Pages.Settings.validEventsUpdate model.repo payload then
                        Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)

                    else
                        addErrorString "Could not disable webhook event. At least one event must be active."
            in
            ( model
            , action
            )

        UpdateRepoAccess org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoStringPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload

                action =
                    if Pages.Settings.validAccessUpdate model.repo payload then
                        Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)

                    else
                        Cmd.none
            in
            ( model
            , action
            )

        UpdateRepoTimeout org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoIntPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload
            in
            ( model
            , Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)
            )

        EnableRepos repos ->
            ( model
            , Cmd.batch <| List.map (Util.dispatch << EnableRepo) repos
            )

        ClickHook org repo buildNumber ->
            let
                ( hookBuilds, action ) =
                    clickHook model org repo buildNumber
            in
            ( { model | hookBuilds = hookBuilds }
            , action
            )

        ClickStep org repo buildNumber stepNumber _ ->
            let
                ( steps, a ) =
                    clickStep model.steps stepNumber

                action =
                    if a then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing

                    else
                        Cmd.none

                stepOpened =
                    not <| viewingStep steps stepNumber

                focused =
                    logFocusExists steps
            in
            ( { model | steps = steps }
            , Cmd.batch <|
                [ action
                , if stepOpened && not focused then
                    Navigation.pushUrl model.navigationKey <| logFocusFragment stepNumber []

                  else
                    Cmd.none
                ]
            )

        SetTheme theme ->
            if theme == model.theme then
                ( model, Cmd.none )

            else
                ( { model | theme = theme }, Interop.setTheme <| encodeTheme theme )

        GotoPage pageNumber ->
            case model.page of
                Pages.RepositoryBuilds org repo _ maybePerPage ->
                    let
                        currentBuilds =
                            model.builds

                        loadingBuilds =
                            { currentBuilds | builds = Loading }
                    in
                    ( { model | builds = loadingBuilds }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo (Just pageNumber) maybePerPage )

                Pages.Hooks org repo _ maybePerPage ->
                    let
                        currentHooks =
                            model.hooks

                        loadingHooks =
                            { currentHooks | hooks = Loading }
                    in
                    ( { model | hooks = loadingHooks }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Hooks org repo (Just pageNumber) maybePerPage )

                _ ->
                    ( model, Cmd.none )

        RestartBuild org repo buildNumber ->
            ( model
            , restartBuild model org repo buildNumber
            )

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Error "Error" error)

        HooksResponse _ _ response ->
            let
                currentHooks =
                    model.hooks
            in
            case response of
                Ok ( meta, hooks ) ->
                    let
                        pager =
                            Pagination.get meta.headers
                    in
                    ( { model | hooks = { currentHooks | hooks = RemoteData.succeed hooks, pager = pager } }, Cmd.none )

                Err error ->
                    ( { model | hooks = { currentHooks | hooks = toFailure error } }, addError error )

        HookBuildResponse org repo buildNumber response ->
            case response of
                Ok ( _, build ) ->
                    ( { model | hookBuilds = Pages.Hooks.receiveHookBuild ( org, repo, buildNumber ) (RemoteData.succeed build) model.hookBuilds }, Cmd.none )

                Err error ->
                    ( { model | hookBuilds = Pages.Hooks.receiveHookBuild ( org, repo, buildNumber ) (toFailure error) model.hookBuilds }, Cmd.none )

        AlertsUpdate subMsg ->
            Alerting.update Alerts.config AlertsUpdate subMsg model

        ClickedLink urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Navigation.pushUrl model.navigationKey <| Url.toString url )

                Browser.External url ->
                    ( model, Navigation.load url )

        SearchSourceRepos org searchBy ->
            let
                filters =
                    Dict.update org (\_ -> Just searchBy) model.filters
            in
            ( { model | filters = filters }, Cmd.none )

        SearchFavorites searchBy ->
            ( { model | favoritesFilter = searchBy }, Cmd.none )

        ChangeRepoTimeout inTimeout ->
            let
                newTimeout =
                    case String.toInt inTimeout of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | inTimeout = newTimeout }, Cmd.none )

        RefreshSettings org repo ->
            ( { model | inTimeout = Nothing, repo = Loading }, Api.try RepoResponse <| Api.getRepo model org repo )

        AdjustTimeZone newZone ->
            ( { model | zone = newZone }
            , Cmd.none
            )

        AdjustTime newTime ->
            ( { model | time = newTime }
            , Cmd.none
            )

        Tick interval time ->
            case interval of
                OneSecond ->
                    ( { model | time = time }, Cmd.none )

                FiveSecond data ->
                    ( model, refreshPage model data )

        FocusOn id ->
            ( model, Dom.focus id |> Task.attempt FocusResult )

        FocusResult result ->
            -- handle success or failure here
            case result of
                Err (Dom.NotFound id) ->
                    -- unable to find dom 'id'
                    ( model, Cmd.none )

                Ok ok ->
                    -- successfully focus the dom
                    ( model, Cmd.none )

        OnKeyDown key ->
            let
                m =
                    if key == "Shift" then
                        { model | shift = True }

                    else
                        model
            in
            ( m, Cmd.none )

        OnKeyUp key ->
            let
                m =
                    if key == "Shift" then
                        { model | shift = False }

                    else
                        model
            in
            ( m, Cmd.none )

        VisibilityChanged visibility ->
            ( { model | visibility = visibility, shift = False }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


keyDecoder : Decode.Decoder String
keyDecoder =
    Decode.field "key" Decode.string


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch <|
        [ Interop.onSessionChange decodeOnSessionChange
        , Interop.onThemeChange decodeOnThemeChange
        , Browser.Events.onKeyDown (Decode.map OnKeyDown keyDecoder)
        , Browser.Events.onKeyUp (Decode.map OnKeyUp keyDecoder)
        , Browser.Events.onVisibilityChange VisibilityChanged
        , refreshSubscriptions model
        ]


decodeOnSessionChange : Decode.Value -> Msg
decodeOnSessionChange sessionJson =
    case Decode.decodeValue decodeSession sessionJson of
        Ok session ->
            if String.isEmpty session.token then
                NewRoute Routes.Login

            else
                SessionChanged (Just session)

        Err _ ->
            -- typically you end up here when getting logged out where we return null
            SessionChanged Nothing


decodeOnThemeChange : Decode.Value -> Msg
decodeOnThemeChange inTheme =
    case Decode.decodeValue decodeTheme inTheme of
        Ok theme ->
            SetTheme theme

        Err _ ->
            SetTheme Dark


{-| refreshPage : takes model and determines if the page should automatically refresh data
-}
refreshSubscriptions : Model -> Sub Msg
refreshSubscriptions model =
    Sub.batch <|
        case model.visibility of
            Visible ->
                [ every Util.oneSecondMillis <| Tick OneSecond
                , every Util.fiveSecondsMillis <| Tick (FiveSecond <| refreshData model)
                ]

            Hidden ->
                []


{-| refreshPage : refreshes Vela data based on current page and build status
-}
refreshPage : Model -> RefreshData -> Cmd Msg
refreshPage model _ =
    let
        page =
            model.page
    in
    case page of
        Pages.RepositoryBuilds org repo maybePage maybePerPage ->
            getBuilds model org repo maybePage maybePerPage

        Pages.Build org repo buildNumber _ ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildSteps model org repo buildNumber
                , refreshLogs model org repo buildNumber model.steps Nothing
                ]

        Pages.Hooks org repo maybePage maybePerPage ->
            Cmd.batch
                [ getHooks model org repo maybePage maybePerPage
                , refreshHookBuilds model
                ]

        _ ->
            Cmd.none


{-| refreshData : takes model and extracts data needed to refresh the page
-}
refreshData : Model -> RefreshData
refreshData model =
    let
        buildNumber =
            case model.build of
                Success build ->
                    Just <| String.fromInt build.number

                _ ->
                    Nothing
    in
    { org = model.builds.org, repo = model.builds.repo, build_number = buildNumber, steps = Nothing }


{-| refreshBuild : takes model org repo and build number and refreshes the build status
-}
refreshBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
refreshBuild model org repo buildNumber =
    let
        refresh =
            getBuild model org repo buildNumber
    in
    if shouldRefresh model.build then
        refresh

    else
        Cmd.none


{-| refreshBuildSteps : takes model org repo and build number and refreshes the build steps based on step status
-}
refreshBuildSteps : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
refreshBuildSteps model org repo buildNumber =
    let
        refresh =
            case model.steps of
                Success steps ->
                    Cmd.batch <|
                        List.map
                            (\step -> getBuildStep model org repo buildNumber <| String.fromInt step.number)
                        <|
                            filterCompletedSteps steps

                _ ->
                    Cmd.none
    in
    if shouldRefresh model.build then
        refresh

    else
        Cmd.none


{-| refreshHookBuilds : takes model org and repo and refreshes the hook builds being viewed by the user
-}
refreshHookBuilds : Model -> Cmd Msg
refreshHookBuilds model =
    let
        builds =
            Dict.keys model.hookBuilds

        buildsToRefresh =
            List.filter
                (\build -> shouldRefreshHookBuild <| Maybe.withDefault ( NotAsked, False ) <| Dict.get build model.hookBuilds)
                builds

        refreshCmds =
            List.map (\( org, repo, buildNumber ) -> getHookBuild model org repo buildNumber) buildsToRefresh
    in
    Cmd.batch refreshCmds


{-| shouldRefresh : takes build and returns true if a refresh is required
-}
shouldRefresh : WebData Build -> Bool
shouldRefresh build =
    case build of
        Success bld ->
            case bld.status of
                -- Do not refresh a build in success or failure state
                Vela.Success ->
                    False

                Vela.Failure ->
                    False

                _ ->
                    True

        NotAsked ->
            True

        -- Do not refresh a Failed or Loading build
        Failure _ ->
            False

        Loading ->
            False


{-| shouldRefreshHookBuild : takes build and viewing state and returns true if a refresh is required
-}
shouldRefreshHookBuild : ( WebData Build, Viewing ) -> Bool
shouldRefreshHookBuild ( build, viewing ) =
    viewing && shouldRefresh build


{-| filterCompletedSteps : filters out completed steps based on success and failure
-}
filterCompletedSteps : Steps -> Steps
filterCompletedSteps steps =
    List.filter (\step -> step.status /= Vela.Success && step.status /= Vela.Failure) steps


{-| refreshLogs : takes model org repo and build number and steps and refreshes the build step logs depending on their status
-}
refreshLogs : Model -> Org -> Repo -> BuildNumber -> WebData Steps -> FocusFragment -> Cmd Msg
refreshLogs model org repo buildNumber inSteps focusFragment =
    let
        stepsToRefresh =
            RemoteData.succeed <|
                case inSteps of
                    Success s ->
                        -- Do not refresh logs for a step in success or failure state
                        List.filter (\step -> step.status /= Vela.Success && step.status /= Vela.Failure) s

                    _ ->
                        []

        refresh =
            getBuildStepsLogs model org repo buildNumber stepsToRefresh focusFragment
    in
    if shouldRefresh model.build then
        refresh

    else
        Cmd.none



-- VIEW


view : Model -> Document Msg
view model =
    let
        ( title, content ) =
            viewContent model
    in
    { title = "Vela - " ++ title
    , body =
        [ lazy2 viewHeader model.session { feedbackLink = model.velaFeedbackURL, docsLink = model.velaDocsURL, theme = model.theme }
        , lazy2 Nav.view { page = model.page, user = model.user, sourceRepos = model.sourceRepos } navMsgs
        , main_ [ class "content-wrap" ]
            [ viewUtil model
            , content
            ]
        , footer [] [ lazy viewAlerts model.toasties ]
        ]
    }


viewContent : Model -> ( String, Html Msg )
viewContent model =
    case model.page of
        Pages.Overview ->
            ( "Overview"
            , lazy3 Pages.Home.view model.user model.favoritesFilter homeMsgs
            )

        Pages.AddRepositories ->
            ( "Add Repositories"
            , lazy2 Pages.AddRepos.view
                { user = model.user
                , sourceRepos = model.sourceRepos
                , filters = model.filters
                }
                addReposMsgs
            )

        Pages.Hooks org repo maybePage _ ->
            let
                page : String
                page =
                    case maybePage of
                        Nothing ->
                            ""

                        Just p ->
                            " (page " ++ String.fromInt p ++ ")"
            in
            ( String.join "/" [ org, repo ] ++ " hooks" ++ page
            , div []
                [ Pager.view model.hooks.pager Pager.defaultLabels GotoPage
                , lazy4 Pages.Hooks.view
                    { hooks = model.hooks
                    , hookBuilds = model.hookBuilds
                    , time = model.time
                    }
                    org
                    repo
                    hooksMsgs
                , Pager.view model.hooks.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.Settings org repo ->
            ( String.join "/" [ org, repo ] ++ " settings"
            , lazy3 Pages.Settings.view model.repo model.inTimeout repoSettingsMsgs
            )

        Pages.RepositoryBuilds org repo maybePage _ ->
            let
                page : String
                page =
                    case maybePage of
                        Nothing ->
                            ""

                        Just p ->
                            " (page " ++ String.fromInt p ++ ")"
            in
            ( String.join "/" [ org, repo ] ++ " builds" ++ page
            , div []
                [ Pager.view model.builds.pager Pager.defaultLabels GotoPage
                , lazy4 Pages.Builds.view model.builds model.time org repo
                , Pager.view model.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.Build org repo buildNumber _ ->
            ( "Build #" ++ buildNumber ++ " - " ++ String.join "/" [ org, repo ]
            , lazy4 Pages.Build.viewBuild
                { navigationKey = model.navigationKey
                , time = model.time
                , build = model.build
                , steps = model.steps
                , logs = model.logs
                , shift = model.shift
                }
                org
                repo
                buildMsgs
            )

        Pages.Login ->
            ( "Login"
            , viewLogin
            )

        Pages.Logout ->
            ( "Logout"
            , h1 [] [ text "Logging out" ]
            )

        Pages.Authenticate _ ->
            ( "Authentication"
            , h1 [ Util.testAttribute "page-h1" ] [ text "Authenticating..." ]
            )

        Pages.NotFound ->
            -- TODO: make this page more helpful
            ( "404"
            , h1 [] [ text "Not Found" ]
            )


viewLogin : Html Msg
viewLogin =
    div []
        [ h1 [] [ text "Authorize Via" ]
        , button [ class "button", onClick SignInRequested, Util.testAttribute "login-button" ]
            [ FeatherIcons.github
                |> FeatherIcons.withSize 20
                |> FeatherIcons.withClass "login-source-icon"
                |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
            , text "GitHub"
            ]
        , p [] [ text "You will be taken to Github to authenticate." ]
        ]


viewHeader : Maybe Session -> { feedbackLink : String, docsLink : String, theme : Theme } -> Html Msg
viewHeader maybeSession { feedbackLink, docsLink, theme } =
    let
        session : Session
        session =
            Maybe.withDefault defaultSession maybeSession
    in
    header []
        [ div [ class "identity", Util.testAttribute "identity" ]
            [ a [ Routes.href Routes.Overview, class "identity-logo-link", attribute "aria-label" "Home" ] [ velaLogo 24 ]
            , case session.username of
                "" ->
                    details [ class "details", class "-marker-right", class "-no-pad", class "identity-name", attribute "role" "navigation" ]
                        [ summary [ class "summary" ] [ text "Vela" ] ]

                _ ->
                    details [ class "details", class "-marker-right", class "-no-pad", class "identity-name", attribute "role" "navigation" ]
                        [ summary [ class "summary" ]
                            [ text session.username
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , ul [ class "identity-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                            [ li [ class "identity-menu-item" ]
                                [ a [ Routes.href Routes.Logout, Util.testAttribute "logout-link", attribute "role" "menuitem" ] [ text "Logout" ] ]
                            ]
                        ]
            ]
        , nav [ class "help-links", attribute "role" "navigation" ]
            [ ul []
                [ li [] [ viewThemeToggle theme ]
                , li [] [ a [ href feedbackLink, attribute "aria-label" "go to feedback" ] [ text "feedback" ] ]
                , li [] [ a [ href docsLink, attribute "aria-label" "go to docs" ] [ text "docs" ] ]
                , li [] [ FeatherIcons.terminal |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] ]
                ]
            ]
        ]


viewUtil : Model -> Html Msg
viewUtil model =
    div [ class "util" ]
        [ lazy7 Pages.Build.viewBuildHistory model.time model.zone model.page model.builds.org model.builds.repo model.builds.builds 10 ]


viewAlerts : Stack Alert -> Html Msg
viewAlerts toasties =
    div [ Util.testAttribute "alerts", class "alerts" ] [ Alerting.view Alerts.config Alerts.view AlertsUpdate toasties ]


viewThemeToggle : Theme -> Html Msg
viewThemeToggle theme =
    let
        ( newTheme, themeAria ) =
            case theme of
                Dark ->
                    ( Light, "enable light mode" )

                Light ->
                    ( Dark, "enable dark mode" )
    in
    button [ class "button", class "-link", attribute "aria-label" themeAria, onClick (SetTheme newTheme) ] [ text "switch theme" ]



-- HELPERS


buildUrl : String -> List String -> List QueryParameter -> String
buildUrl base paths params =
    UB.crossOrigin base paths params


setNewPage : Routes.Route -> Model -> ( Model, Cmd Msg )
setNewPage route model =
    let
        sessionHasToken : Bool
        sessionHasToken =
            case model.session of
                Just session ->
                    String.length session.token > 0

                Nothing ->
                    False
    in
    case ( route, sessionHasToken ) of
        -- Logged in and on auth flow pages - what are you doing here?
        ( Routes.Login, True ) ->
            ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Overview )

        ( Routes.Authenticate _, True ) ->
            ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Overview )

        -- "Not logged in" (yet) and on auth flow pages, continue on..
        ( Routes.Authenticate { code, state }, False ) ->
            ( { model | page = Pages.Authenticate <| AuthParams code state }
            , Api.try UserResponse <| Api.getUser model <| AuthParams code state
            )

        -- On the login page but not logged in.. good place to be
        ( Routes.Login, False ) ->
            ( { model | page = Pages.Login }, Cmd.none )

        -- "Normal" page handling below
        ( Routes.Overview, True ) ->
            loadOverviewPage model

        ( Routes.AddRepositories, True ) ->
            loadAddReposPage model

        ( Routes.Hooks org repo maybePage maybePerPage, True ) ->
            loadHooksPage model org repo maybePage maybePerPage

        ( Routes.Settings org repo, True ) ->
            loadSettingsPage model org repo

        ( Routes.RepositoryBuilds org repo maybePage maybePerPage, True ) ->
            let
                currentSession : Session
                currentSession =
                    Maybe.withDefault defaultSession model.session
            in
            loadRepoBuildsPage model org repo currentSession maybePage maybePerPage

        ( Routes.Build org repo buildNumber logFocus, True ) ->
            case model.page of
                Pages.Build o r b _ ->
                    if not <| buildChanged ( org, repo, buildNumber ) ( o, r, b ) then
                        let
                            ( page, steps, action ) =
                                focusLogs model model.steps org repo buildNumber logFocus getBuildStepsLogs
                        in
                        ( { model | page = page, steps = steps }, action )

                    else
                        loadBuildPage model org repo buildNumber logFocus

                _ ->
                    loadBuildPage model org repo buildNumber logFocus

        ( Routes.Logout, True ) ->
            ( { model | session = Nothing }
            , Cmd.batch
                [ Interop.storeSession Encode.null
                , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Login
                ]
            )

        -- Not found page handling
        ( Routes.NotFound, True ) ->
            ( { model | page = Pages.NotFound }, Cmd.none )

        {--Hitting any page and not being logged in will load the login page content

           Note: we're not using .pushUrl to retain ability for user to use brower's back b
           utton
        --}
        ( _, False ) ->
            ( { model | page = Pages.Login }
            , Interop.storeSession <| encodeSession <| Session "" "" <| Url.toString model.entryURL
            )


loadAddReposPage : Model -> ( Model, Cmd Msg )
loadAddReposPage model =
    case model.sourceRepos of
        NotAsked ->
            ( { model | page = Pages.AddRepositories, sourceRepos = Loading }
            , Cmd.batch
                [ Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model
                , getCurrentUser model
                ]
            )

        Failure _ ->
            ( { model | page = Pages.AddRepositories, sourceRepos = Loading }
            , Cmd.batch
                [ Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model
                , getCurrentUser model
                ]
            )

        _ ->
            ( { model | page = Pages.AddRepositories }, getCurrentUser model )


loadOverviewPage : Model -> ( Model, Cmd Msg )
loadOverviewPage model =
    ( { model | page = Pages.Overview }
    , Cmd.batch
        [ getCurrentUser model
        ]
    )


{-| buildChanged : takes two build identifiers and returns if the build has changed
-}
buildChanged : BuildIdentifier -> BuildIdentifier -> Bool
buildChanged ( orgA, repoA, buildNumA ) ( orgB, repoB, buildNumB ) =
    not <| orgA == orgB && repoA == repoB && buildNumA == buildNumB


{-| loadHooksPage : takes model org and repo and loads the hooks page.
-}
loadHooksPage : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadHooksPage model org repo maybePage maybePerPage =
    -- Fetch builds from Api
    let
        loadedHooks =
            model.hooks

        loadingHooks =
            { loadedHooks | hooks = Loading }
    in
    ( { model | page = Pages.Hooks org repo maybePage maybePerPage, hooks = loadingHooks, hookBuilds = Dict.empty }
    , Cmd.batch
        [ getHooks model org repo maybePage maybePerPage
        , getCurrentUser model
        ]
    )


{-| loadSettingsPage : takes model org and repo and loads the page for updating repo configurations
-}
loadSettingsPage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadSettingsPage model org repo =
    -- Fetch repo from Api
    ( { model | page = Pages.Settings org repo, repo = Loading, inTimeout = Nothing }
    , Cmd.batch
        [ getRepo model org repo
        , getCurrentUser model
        ]
    )


{-| loadRepoBuildsPage : takes model org and repo and loads the appropriate builds.

    loadRepoBuildsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadRepoBuildsPage : Model -> Org -> Repo -> Session -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadRepoBuildsPage model org repo _ maybePage maybePerPage =
    let
        -- Builds already loaded
        loadedBuilds =
            model.builds

        -- Set builds to Loading
        loadingBuilds =
            { loadedBuilds | org = org, repo = repo, builds = Loading }
    in
    -- Fetch builds from Api
    ( { model | page = Pages.RepositoryBuilds org repo maybePage maybePerPage, builds = loadingBuilds }
    , Cmd.batch
        [ getBuilds model org repo maybePage maybePerPage
        , getCurrentUser model
        ]
    )


{-| loadBuildPage : takes model org, repo, and build number and loads the appropriate build.

    loadBuildPage   Checks if the build has already been loaded from the repo view. If not, fetches the build from the Api.

-}
loadBuildPage : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> ( Model, Cmd Msg )
loadBuildPage model org repo buildNumber focusFragment =
    let
        modelBuilds =
            model.builds

        builds =
            if not <| Util.isSuccess model.builds.builds then
                { modelBuilds | builds = Loading }

            else
                model.builds
    in
    -- Fetch build from Api
    ( { model
        | page = Pages.Build org repo buildNumber focusFragment
        , builds = builds
        , build = Loading
        , steps = NotAsked
        , logs = []
      }
    , Cmd.batch
        [ getBuilds model org repo Nothing Nothing
        , getBuild model org repo buildNumber
        , getAllBuildSteps model org repo buildNumber focusFragment
        ]
    )


{-| repoEnabledError : takes model repo and error and updates the source repos within the model

    repoEnabledError : consumes 409 conflicts that result from the repo already being enabled

-}
repoEnabledError : WebData SourceRepositories -> Repository -> Http.Detailed.Error String -> ( WebData SourceRepositories, Cmd Msg )
repoEnabledError sourceRepos repo error =
    let
        ( enabled, action ) =
            case error of
                Http.Detailed.BadStatus metadata _ ->
                    case metadata.statusCode of
                        409 ->
                            ( RemoteData.succeed True, Cmd.none )

                        _ ->
                            ( toFailure error, addError error )

                _ ->
                    ( toFailure error, addError error )
    in
    ( enableUpdate repo enabled sourceRepos
    , action
    )


{-| buildEnableRepositoryPayload : builds the payload for adding a repository via the api
-}
buildEnableRepositoryPayload : Repository -> String -> EnableRepositoryPayload
buildEnableRepositoryPayload repo velaSourceBaseURL =
    { defaultEnableRepositoryPayload
        | org = repo.org
        , name = repo.name
        , full_name = repo.org ++ "/" ++ repo.name
        , link = String.join "/" [ velaSourceBaseURL, repo.org, repo.name ]
        , clone = String.join "/" [ velaSourceBaseURL, repo.org, repo.name ] ++ ".git"
    }


{-| addError : takes a detailed http error and produces a Cmd Msg that invokes an action in the Errors module
-}
addError : Http.Detailed.Error String -> Cmd Msg
addError error =
    succeed
        (Error <| detailedErrorToString error)
        |> perform identity


{-| addErrorString : takes a string and produces a Cmd Msg that invokes an action in the Errors module
-}
addErrorString : String -> Cmd Msg
addErrorString error =
    succeed
        (Error <| error)
        |> perform identity


{-| toFailure : maps a detailed error into a WebData Failure value
-}
toFailure : Http.Detailed.Error String -> WebData a
toFailure error =
    Failure <| Errors.detailedErrorToError error


{-| stepsIds : extracts Ids from list of steps and returns List Int
-}
stepsIds : Steps -> List Int
stepsIds steps =
    List.map (\step -> step.number) steps


{-| logIds : extracts Ids from list of logs and returns List Int
-}
logIds : Logs -> List Int
logIds logs =
    List.map (\log -> log.id) <| successfulLogs logs


{-| logIds : extracts successful logs from list of logs and returns List Log
-}
successfulLogs : Logs -> List Log
successfulLogs logs =
    List.filterMap
        (\log ->
            case log of
                Success log_ ->
                    Just log_

                _ ->
                    Nothing
        )
        logs


{-| updateStep : takes model and incoming step and updates the list of steps if necessary
-}
updateStep : Model -> Step -> Model
updateStep model incomingStep =
    let
        steps =
            case model.steps of
                Success s ->
                    s

                _ ->
                    []

        stepExists =
            List.member incomingStep.number <| stepsIds steps
    in
    if stepExists then
        { model
            | steps =
                RemoteData.succeed <|
                    updateIf (\step -> incomingStep.number == step.number)
                        (\step -> { incomingStep | viewing = step.viewing })
                        steps
        }

    else
        { model | steps = RemoteData.succeed <| incomingStep :: steps }


{-| updateLogs : takes model and incoming log and updates the list of logs if necessary
-}
updateLogs : Model -> Log -> Model
updateLogs model incomingLog =
    let
        logs =
            model.logs

        logExists =
            List.member incomingLog.id <| logIds logs
    in
    if logExists then
        { model | logs = updateLog incomingLog logs }

    else if incomingLog.id /= 0 then
        { model | logs = addLog incomingLog logs }

    else
        model


{-| updateLogs : takes incoming log and logs and updates the appropriate log data
-}
updateLog : Log -> Logs -> Logs
updateLog incomingLog logs =
    setIf
        (\log ->
            case log of
                Success log_ ->
                    incomingLog.id == log_.id && incomingLog.data /= log_.data

                _ ->
                    True
        )
        (RemoteData.succeed incomingLog)
        logs


{-| addLog : takes incoming log and logs and adds log when not present
-}
addLog : Log -> Logs -> Logs
addLog incomingLog logs =
    RemoteData.succeed incomingLog :: logs


{-| clickHook : takes model org repo and build number and fetches build information from the api
-}
clickHook : Model -> Org -> Repo -> BuildNumber -> ( HookBuilds, Cmd Msg )
clickHook model org repo buildNumber =
    if buildNumber == "0" then
        ( model.hookBuilds
        , Cmd.none
        )

    else
        let
            ( buildInfo, action ) =
                case Dict.get ( org, repo, buildNumber ) model.hookBuilds of
                    Just ( webdataBuild, viewing ) ->
                        case webdataBuild of
                            Success _ ->
                                ( ( webdataBuild, not viewing ), Cmd.none )

                            Failure err ->
                                ( ( Failure err, not viewing ), Cmd.none )

                            _ ->
                                ( ( Loading, not viewing ), Cmd.none )

                    _ ->
                        ( ( Loading, True ), getHookBuild model org repo buildNumber )
        in
        ( Dict.update ( org, repo, buildNumber ) (\_ -> Just buildInfo) model.hookBuilds
        , action
        )


{-| homeMsgs : prepares the input record required for the Home page to route Msgs back to Main.elm
-}
homeMsgs : Pages.Home.Msgs Msg
homeMsgs =
    Pages.Home.Msgs ToggleFavorite SearchFavorites


{-| buildMsgs : prepares the input record required for the Build page to route Msgs back to Main.elm
-}
buildMsgs : Pages.Build.Msgs Msg
buildMsgs =
    Pages.Build.Msgs ClickStep UpdateUrl


{-| navMsgs : prepares the input record required for the nav component to route Msgs back to Main.elm
-}
navMsgs : Nav.Msgs Msg
navMsgs =
    Nav.Msgs FetchSourceRepositories ToggleFavorite RefreshSettings RestartBuild


{-| addReposMsgs : prepares the input record required for the AddRepos page to route Msgs back to Main.elm
-}
addReposMsgs : Pages.AddRepos.Msgs Msg
addReposMsgs =
    Pages.AddRepos.Msgs SearchSourceRepos EnableRepo EnableRepos ToggleFavorite


{-| hooksMsgs : prepares the input record required for the Hooks page to route Msgs back to Main.elm
-}
hooksMsgs : Org -> Repo -> BuildNumber -> Msg
hooksMsgs =
    ClickHook


{-| repoSettingsMsgs : prepares the input record required for the Settings page to route Msgs back to Main.elm
-}
repoSettingsMsgs : Pages.Settings.Msgs Msg
repoSettingsMsgs =
    Pages.Settings.Msgs UpdateRepoEvent UpdateRepoAccess UpdateRepoTimeout ChangeRepoTimeout DisableRepo EnableRepo



-- API HELPERS


getCurrentUser : Model -> Cmd Msg
getCurrentUser model =
    Api.try CurrentUserResponse <| Api.getCurrentUser model


getHooks : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getHooks model org repo maybePage maybePerPage =
    Api.try (HooksResponse org repo) <| Api.getHooks model maybePage maybePerPage org repo


getHookBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getHookBuild model org repo buildNumber =
    Api.try (HookBuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getRepo : Model -> Org -> Repo -> Cmd Msg
getRepo model org repo =
    Api.try RepoResponse <| Api.getRepo model org repo


getBuilds : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getBuilds model org repo maybePage maybePerPage =
    Api.try (BuildsResponse org repo) <| Api.getBuilds model maybePage maybePerPage org repo


getBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.try (BuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getAllBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
getAllBuildSteps model org repo buildNumber logFocus =
    Api.try (StepsResponse org repo buildNumber logFocus) <| Api.getSteps model Nothing Nothing org repo buildNumber


getBuildStep : Model -> Org -> Repo -> BuildNumber -> StepNumber -> Cmd Msg
getBuildStep model org repo buildNumber stepNumber =
    Api.try (StepResponse org repo buildNumber stepNumber) <| Api.getStep model org repo buildNumber stepNumber


getBuildStepLogs : Model -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Cmd Msg
getBuildStepLogs model org repo buildNumber stepNumber logFocus =
    Api.try (StepLogResponse logFocus) <| Api.getStepLogs model org repo buildNumber stepNumber


getBuildStepsLogs : Model -> Org -> Repo -> BuildNumber -> WebData Steps -> FocusFragment -> Cmd Msg
getBuildStepsLogs model org repo buildNumber steps logFocus =
    let
        buildSteps =
            case steps of
                RemoteData.Success s ->
                    s

                _ ->
                    []
    in
    Cmd.batch <|
        List.map
            (\step ->
                if step.viewing then
                    getBuildStepLogs model org repo buildNumber (String.fromInt step.number) logFocus

                else
                    Cmd.none
            )
            buildSteps


restartBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
restartBuild model org repo buildNumber =
    Api.try (RestartedBuildResponse org repo buildNumber) <| Api.restartBuild model org repo buildNumber



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = ClickedLink
        , onUrlChange = Routes.match >> NewRoute
        }
