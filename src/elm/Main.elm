{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Main exposing (main)

import Alerts exposing (Alert)
import Api
import Api.Endpoint
import Api.Pagination as Pagination
import Browser exposing (Document, UrlRequest)
import Browser.Dom as Dom
import Browser.Events exposing (Visibility(..))
import Browser.Navigation as Navigation
import Dict
import Errors exposing (Error, addErrorString, detailedErrorToString, toFailure)
import Favorites exposing (toFavorite, updateFavorites)
import FeatherIcons
import File.Download as Download
import Focus exposing (ExpandTemplatesQuery, Fragment, RefQuery, focusFragmentToFocusId, lineRangeId, parseFocusFragment, resourceFocusFragment)
import Help.Commands
import Help.View
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
        , input
        , label
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
        , checked
        , class
        , classList
        , for
        , href
        , id
        , name
        , type_
        )
import Html.Events exposing (onClick)
import Html.Lazy exposing (lazy, lazy2, lazy3, lazy4, lazy5, lazy6, lazy7)
import Http
import Http.Detailed
import Interop
import Json.Decode as Decode exposing (string)
import Json.Encode as Encode
import List.Extra exposing (updateIf)
import Maybe
import Nav exposing (viewNav, viewUtil)
import Pager
import Pages exposing (Page(..), onPage)
import Pages.Build.Logs
    exposing
        ( focusStepLogs
        , focusServiceLogs
        , getCurrentResource
        , stepBottomTrackerFocusId
        )
import Pages.Build.Model
import Pages.Build.Update exposing (clickStep,expandActiveService,clickService, expandActiveStep, isViewingStep,  isViewingService, setAllStepViews)
import Pages.Build.View
import Pages.Builds exposing (view)
import Pages.Home
import Pages.Hooks
import Pages.Pipeline.Model
import Pages.Pipeline.View
import Pages.RepoSettings exposing (enableUpdate)
import Pages.Secrets.Model
import Pages.Secrets.Update
import Pages.Secrets.View
import Pages.Settings
import Pages.SourceRepos
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import String.Extra
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
        , BuildNumber
        , Builds
        , BuildsModel
        , ChownRepo
        , CurrentUser
        , EnableRepo
        , EnableRepos
        , EnableRepositoryPayload
        , Enabling(..)
        , Engine
        , Event,Services,Service
        , Favicon
        , Field
        , FocusFragment
        , Hooks
        , HooksModel
        , Key
        , Log
        , Logs,updateBuildServices
        , Name
        , Org
        , PipelineConfig
        , PipelineModel
        , PipelineTemplates
        , Ref
        , RepairRepo
        , Repo
        , RepoModel
        , RepoResourceIdentifier
        , RepoSearchFilters
        , Repositories
        , Repository
        , Secret
        , SecretType(..)
        , Secrets
        , Session
        , SourceRepositories
        , Step
        , StepNumber
        , Steps
        , Team
        , Templates
        , Theme(..)
        , Type
        , UpdateRepositoryPayload
        , UpdateUserPayload
        , User
        , buildUpdateFavoritesPayload
        , buildUpdateRepoBoolPayload
        , buildUpdateRepoIntPayload
        , buildUpdateRepoStringPayload
        , decodeSession
        , decodeTheme
        , defaultBuilds
        , defaultEnableRepositoryPayload
        , defaultFavicon
        , defaultHooks
        , defaultPipeline
        , defaultPipelineTemplates
        , defaultRepoModel
        , defaultRepository
        , defaultSession
        , encodeEnableRepository
        , encodeSession
        , encodeTheme
        , encodeUpdateRepository
        , encodeUpdateUser
        , isComplete
        , secretTypeToString
        , statusToFavicon
        , stringToTheme
        , updateBuild
        , updateBuildFocusFragment
        , updateBuildLogs
        , updateBuildSteps
        , updateBuilds,ServiceNumber
        , updateHooks
        , updateHooksModel
        , updateOrgRepo
        , updateRepo
        )



-- TYPES


type alias Flags =
    { isDev : Bool
    , velaAPI : String
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
    , repo : RepoModel
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , navigationKey : Navigation.Key
    , zone : Zone
    , time : Posix
    , filters : RepoSearchFilters
    , favoritesFilter : String
    , inTimeout : Maybe Int
    , entryURL : Url
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    , showHelp : Bool
    , showIdentity : Bool
    , favicon : Favicon
    , secretsModel : Pages.Secrets.Model.Model Msg
    , pipeline : PipelineModel
    , templates : PipelineTemplates
    }


type Interval
    = OneSecond
    | OneSecondHidden
    | FiveSecond RefreshData
    | FiveSecondHidden RefreshData


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
            , velaFeedbackURL = flags.velaFeedbackURL
            , velaDocsURL = flags.velaDocsURL
            , navigationKey = navKey
            , toasties = Alerting.initialState
            , zone = utc
            , time = millisToPosix 0
            , filters = Dict.empty
            , favoritesFilter = ""
            , repo = defaultRepoModel
            , inTimeout = Nothing
            , entryURL = url
            , theme = stringToTheme flags.velaTheme
            , shift = False
            , visibility = Visible
            , showHelp = False
            , showIdentity = False
            , favicon = defaultFavicon
            , secretsModel = initSecretsModel
            , pipeline = defaultPipeline
            , templates = defaultPipelineTemplates
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
    = -- User events
      NewRoute Routes.Route
    | ClickedLink UrlRequest
    | SearchSourceRepos Org String
    | SearchFavorites String
    | ChangeRepoTimeout String
    | RefreshSettings Org Repo
    | RefreshHooks Org Repo
    | RefreshSecrets Engine SecretType Org Repo
    | FocusLineNumber Int
    | SetTheme Theme
    | GotoPage Pagination.Page
    | ShowHideHelp (Maybe Bool)
    | ShowHideIdentity (Maybe Bool)
    | Copy String
    | DownloadTextFile String String
    | ExpandAllSteps Org Repo BuildNumber
    | CollapseAllSteps
    | ExpandStep Org Repo BuildNumber StepNumber
    | ExpandService Org Repo BuildNumber ServiceNumber
    | FollowStep Int
    | ClickBuildNavTab Route
      -- Outgoing HTTP requests
    | SignInRequested
    | FetchSourceRepositories
    | ToggleFavorite Org (Maybe Repo)
    | EnableRepos Repositories
    | EnableRepo Repository
    | DisableRepo Repository
    | ChownRepo Repository
    | RepairRepo Repository
    | UpdateRepoEvent Org Repo Field Bool
    | UpdateRepoAccess Org Repo Field String
    | UpdateRepoTimeout Org Repo Field Int
    | RestartBuild Org Repo BuildNumber
    | GetPipelineConfig Org Repo (Maybe BuildNumber) (Maybe String) Bool
    | ExpandPipelineConfig Org Repo (Maybe BuildNumber) (Maybe String) Bool
      -- Inbound HTTP responses
    | UserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, User ))
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | RepoFavoritedResponse String Bool (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoEnabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoDisabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoChownedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoRepairedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | HooksResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | StepsResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | StepLogResponse StepNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
    | ServicesResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Services ))
    | ServiceLogResponse ServiceNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
    | GetPipelineConfigResponse Org Repo (Maybe Ref) (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ExpandPipelineConfigResponse Org Repo (Maybe Ref) (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | GetPipelineTemplatesResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Templates ))
    | SecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | RepoSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
    | OrgSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
    | SharedSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
    | DeleteSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- Time
    | AdjustTimeZone Zone
    | AdjustTime Posix
    | Tick Interval Posix
      -- Components
    | AddSecretUpdate Engine Pages.Secrets.Model.Msg
      -- Other
    | HandleError Error
    | AlertsUpdate (Alerting.Msg Alert)
    | SessionChanged (Maybe Session)
    | FilterBuildEventBy (Maybe Event) Org Repo
    | FocusOn String
    | FocusResult (Result Dom.Error ())
    | OnKeyDown String
    | OnKeyUp String
    | VisibilityChanged Visibility
    | PushUrl String
      -- NoOp
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        rm =
            model.repo

        pipeline =
            model.pipeline
    in
    case msg of
        -- User events
        NewRoute route ->
            setNewPage route model

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
            ( { model | inTimeout = Nothing, repo = updateRepo rm Loading }, Api.try RepoResponse <| Api.getRepo model org repo )

        RefreshHooks org repo ->
            ( { model | repo = updateHooks rm Loading }, getHooks model org repo Nothing Nothing )

        RefreshSecrets engine type_ org key ->
            let
                secretsModel =
                    model.secretsModel
            in
            case type_ of
                Vela.RepoSecret ->
                    ( { model | secretsModel = { secretsModel | repoSecrets = Loading } }
                    , getRepoSecrets model Nothing Nothing engine org key
                    )

                Vela.OrgSecret ->
                    ( { model | secretsModel = { secretsModel | orgSecrets = Loading } }
                    , getOrgSecrets model Nothing Nothing engine org
                    )

                Vela.SharedSecret ->
                    ( { model | secretsModel = { secretsModel | sharedSecrets = Loading } }
                    , getSharedSecrets model Nothing Nothing engine org key
                    )

        FocusLineNumber line ->
            let
                url =
                    lineRangeId "config" "0" line pipeline.lineFocus model.shift
            in
            ( { model
                | pipeline =
                    { pipeline
                        | lineFocus = pipeline.lineFocus
                    }
              }
            , Navigation.pushUrl model.navigationKey <| url
            )

        SetTheme theme ->
            if theme == model.theme then
                ( model, Cmd.none )

            else
                ( { model | theme = theme }, Interop.setTheme <| encodeTheme theme )

        GotoPage pageNumber ->
            case model.page of
                Pages.RepositoryBuilds org repo _ maybePerPage maybeEvent ->
                    let
                        currentBuilds =
                            rm.builds

                        loadingBuilds =
                            { currentBuilds | builds = Loading }
                    in
                    ( { model | repo = updateBuilds rm loadingBuilds }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo (Just pageNumber) maybePerPage maybeEvent )

                Pages.Hooks org repo _ maybePerPage ->
                    let
                        currentHooks =
                            rm.hooks

                        loadingHooks =
                            { currentHooks | hooks = Loading }
                    in
                    ( { model | repo = updateHooksModel rm loadingHooks }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Hooks org repo (Just pageNumber) maybePerPage )

                Pages.RepoSecrets engine org repo _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | repoSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepoSecrets engine org repo (Just pageNumber) maybePerPage )

                Pages.OrgSecrets engine org _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | orgSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.OrgSecrets engine org (Just pageNumber) maybePerPage )

                Pages.SharedSecrets engine org team _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | sharedSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.SharedSecrets engine org team (Just pageNumber) maybePerPage )

                _ ->
                    ( model, Cmd.none )

        ShowHideHelp show ->
            ( { model
                | showHelp =
                    case show of
                        Just s ->
                            s

                        Nothing ->
                            not model.showHelp
              }
            , Cmd.none
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
            , Cmd.none
            )

        Copy content ->
            ( model, Cmd.none )
                |> Alerting.addToast Alerts.successConfig
                    AlertsUpdate
                    (Alerts.Success ""
                        ("Copied " ++ wrapAlertMessage content ++ "to your clipboard.")
                        Nothing
                    )

        DownloadTextFile filename content ->
            ( model
            , Download.string filename "text" content
            )

        ExpandAllSteps org repo buildNumber ->
            let
                build =
                    rm.build

                steps =
                    RemoteData.unwrap build.steps
                        (\steps_ -> steps_ |> setAllStepViews True |> RemoteData.succeed)
                        build.steps

                -- refresh logs for expanded steps
                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | repo = { rm | build = { build | steps = steps } } }
            , action
            )

        CollapseAllSteps ->
            let
                build =
                    rm.build

                steps =
                    build.steps
                        |> RemoteData.unwrap build.steps
                            (\steps_ -> steps_ |> setAllStepViews False |> RemoteData.succeed)
            in
            ( { model | repo = { rm | build = { build | steps = steps, followingStep = 0 } } }
            , Cmd.none
            )

        ExpandStep org repo buildNumber stepNumber ->
            let
                build =
                    rm.build

                ( steps, fetchStepLogs ) =
                    clickStep build.steps stepNumber

                action =
                    if fetchStepLogs then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing True

                    else
                        Cmd.none

                stepOpened =
                    isViewingStep steps stepNumber

                -- step clicked is step being followed
                onFollowedStep =
                    build.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                follow =
                    if onFollowedStep && not stepOpened then
                        -- stop following a step when collapsed
                        0

                    else
                        build.followingStep
            in
            ( { model | repo = { rm | build = { build | steps = steps, followingStep = follow } } }
            , Cmd.batch <|
                [ action
                , if stepOpened then
                    Navigation.pushUrl model.navigationKey <| resourceFocusFragment "step" stepNumber []

                  else
                    Cmd.none
                ]
            )

        FollowStep step ->
            let
                build =
                    rm.build
            in
            ( { model | repo = { rm | build = { build | followingStep = step } } }
            , Cmd.none
            )


-- services

        ExpandService org repo buildNumber serviceNumber ->
            let
                build =
                    rm.build

                ( services, fetchServiceLogs ) =
                    clickService build.services serviceNumber

                action =
                    if fetchServiceLogs then
                        getBuildServiceLogs model org repo buildNumber serviceNumber Nothing True

                    else
                        Cmd.none

                serviceOpened =
                    isViewingService services serviceNumber

                -- step clicked is step being followed
                onFollowedService =
                    build.followingService == (Maybe.withDefault -1 <| String.toInt serviceNumber)

                follow =
                    if onFollowedService && not serviceOpened then
                        -- stop following a step when collapsed
                        0

                    else
                        build.followingService
            in
            ( { model | repo = { rm | build = { build | services = services, followingService = follow } } }
            , Cmd.batch <|
                [ action
                , if serviceOpened then
                    Navigation.pushUrl model.navigationKey <| resourceFocusFragment "service" serviceNumber []

                  else
                    Cmd.none
                ]
            )




        ClickBuildNavTab route ->
            case route of
                Routes.Build o r b l   ->
                    let
                        rt =
                            Routes.Build o r b l  
                    in
                    ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl rt )

                _ ->
                    ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl route )

        -- Outgoing HTTP requests
        SignInRequested ->
            ( model, Navigation.load <| Api.Endpoint.toUrl model.velaAPI Api.Endpoint.Login )

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

        EnableRepos repos ->
            ( model
            , Cmd.batch <| List.map (Util.dispatch << EnableRepo) repos
            )

        EnableRepo repo ->
            let
                payload : EnableRepositoryPayload
                payload =
                    buildEnableRepositoryPayload repo

                body : Http.Body
                body =
                    Http.jsonBody <| encodeEnableRepository payload

                currentRepo =
                    RemoteData.withDefault defaultRepository rm.repo
            in
            ( { model
                | sourceRepos = enableUpdate repo Loading model.sourceRepos
                , repo = updateRepo rm <| RemoteData.succeed <| { currentRepo | enabling = Vela.Enabling }
              }
            , Api.try (RepoEnabledResponse repo) <| Api.enableRepository model body
            )

        DisableRepo repo ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository rm.repo

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
                | repo = { rm | repo = RemoteData.succeed <| { currentRepo | enabling = status } }
              }
            , action
            )

        ChownRepo repo ->
            ( model, Api.try (RepoChownedResponse repo) <| Api.chownRepo model repo )

        RepairRepo repo ->
            ( model, Api.try (RepoRepairedResponse repo) <| Api.repairRepo model repo )

        UpdateRepoEvent org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoBoolPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload

                cmd =
                    if Pages.RepoSettings.validEventsUpdate rm.repo payload then
                        Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)

                    else
                        addErrorString "Could not disable webhook event. At least one event must be active." HandleError
            in
            ( model
            , cmd
            )

        UpdateRepoAccess org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoStringPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload

                cmd =
                    if Pages.RepoSettings.validAccessUpdate rm.repo payload then
                        Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)

                    else
                        Cmd.none
            in
            ( model
            , cmd
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

        RestartBuild org repo buildNumber ->
            ( model
            , restartBuild model org repo buildNumber
            )

        GetPipelineConfig org repo buildNumber ref expansionToggle ->
            ( { model
                | pipeline =
                    { pipeline
                        | expanding = True
                    }
              }
            , Cmd.batch
                [ getPipelineConfig model org repo ref
                , Navigation.replaceUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref Nothing Nothing
                ]
            )

        ExpandPipelineConfig org repo buildNumber ref expansionToggle ->
            ( { model
                | pipeline =
                    { pipeline
                        | expanding = True
                    }
              }
            , Cmd.batch
                [ expandPipelineConfig model org repo ref
                , Navigation.replaceUrl model.navigationKey <| Routes.routeToUrl <| Routes.Pipeline org repo ref (Just "true") Nothing
                ]
            )

        -- Inbound HTTP responses
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
                    ( { model | user = toFailure error }, addError error )

        SourceRepositoriesResponse response ->
            case response of
                Ok ( _, repositories ) ->
                    ( { model | sourceRepos = RemoteData.succeed repositories }, Util.dispatch <| FocusOn "global-search-input" )

                Err error ->
                    ( { model | sourceRepos = toFailure error }, addError error )

        RepoFavoritedResponse favorite favorited response ->
            case response of
                Ok ( _, user ) ->
                    ( { model | user = RemoteData.succeed user }
                    , Cmd.none
                    )
                        |> (if favorited then
                                Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (favorite ++ " added to favorites.") Nothing)

                            else
                                Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (favorite ++ " removed from favorites.") Nothing)
                           )

                Err error ->
                    ( { model | user = toFailure error }, addError error )

        RepoResponse response ->
            case response of
                Ok ( _, repoResponse ) ->
                    ( { model | repo = updateRepo rm <| RemoteData.succeed repoResponse }, Cmd.none )

                Err error ->
                    ( { model | repo = updateRepo rm <| toFailure error }, addError error )

        RepoEnabledResponse repo response ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository rm.repo
            in
            case response of
                Ok ( _, enabledRepo ) ->
                    ( { model
                        | sourceRepos = enableUpdate enabledRepo (RemoteData.succeed True) model.sourceRepos
                        , repo = { rm | repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Enabled } }
                      }
                    , Util.dispatch <| ToggleFavorite repo.org <| Just repo.name
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (enabledRepo.full_name ++ " enabled.") Nothing)

                Err error ->
                    let
                        ( sourceRepos, action ) =
                            repoEnabledError model.sourceRepos repo error
                    in
                    ( { model | sourceRepos = sourceRepos }, action )

        RepoDisabledResponse repo response ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository rm.repo
            in
            case response of
                Ok _ ->
                    ( { model
                        | repo = { rm | repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Disabled } }
                        , sourceRepos = enableUpdate repo NotAsked model.sourceRepos
                      }
                    , Cmd.none
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " disabled.") Nothing)

                Err error ->
                    ( model, addError error )

        RepoUpdatedResponse field response ->
            case response of
                Ok ( _, updatedRepo ) ->
                    ( { model | repo = { rm | repo = RemoteData.succeed updatedRepo } }, Cmd.none )
                        |> Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (Pages.RepoSettings.alert field updatedRepo) Nothing)

                Err error ->
                    ( { model | repo = { rm | repo = toFailure error } }, addError error )

        RepoChownedResponse repo response ->
            case response of
                Ok _ ->
                    ( model, Cmd.none )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" ("You are now the owner of " ++ repo.full_name) Nothing)

                Err error ->
                    ( model, addError error )

        RepoRepairedResponse repo response ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository rm.repo
            in
            case response of
                Ok _ ->
                    -- TODO: could 'refresh' settings page instead
                    ( { model
                        | sourceRepos = enableUpdate repo (RemoteData.succeed True) model.sourceRepos
                        , repo = { rm | repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Enabled } }
                      }
                    , Cmd.none
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " has been repaired.") Nothing)

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
                    , getBuilds model org repo Nothing Nothing Nothing
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (restartedBuild ++ " restarted.") (Just ( "View Build #" ++ newBuildNumber, newBuild )))

                Err error ->
                    ( model, addError error )

        BuildsResponse org repo response ->
            let
                currentBuilds =
                    rm.builds
            in
            case response of
                Ok ( meta, builds ) ->
                    let
                        pager =
                            Pagination.get meta.headers
                    in
                    ( { model
                        | repo =
                            { rm
                                | builds =
                                    { currentBuilds
                                        | builds = RemoteData.succeed builds
                                        , pager = pager
                                    }
                                , org = org
                                , name = repo
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = updateBuilds rm { currentBuilds | builds = toFailure error } }, addError error )

        HooksResponse _ _ response ->
            let
                currentHooks =
                    rm.hooks
            in
            case response of
                Ok ( meta, hooks ) ->
                    let
                        pager =
                            Pagination.get meta.headers
                    in
                    ( { model | repo = updateHooksModel rm { currentHooks | hooks = RemoteData.succeed hooks, pager = pager } }, Cmd.none )

                Err error ->
                    ( { model | repo = updateHooks rm <| toFailure error }, addError error )

        BuildResponse org repo _ response ->
            case response of
                Ok ( _, build ) ->
                    let
                        builds =
                            rm.builds
                    in
                    ( { model
                        | repo =
                            updateBuild
                                { rm
                                    | org = org
                                    , name = repo
                                }
                            <|
                                RemoteData.succeed build
                        , favicon = statusToFavicon build.status
                      }
                    , Interop.setFavicon <| Encode.string <| statusToFavicon build.status
                    )

                Err error ->
                    ( { model | repo = { rm | repo = toFailure error } }, addError error )

        StepsResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, steps ) ->
                    let
                        mergedSteps =
                            steps
                                |> List.sortBy .number
                                |> Pages.Build.Update.mergeSteps logFocus refresh rm.build.steps

                        updatedModel =
                            { model | repo = updateBuildSteps rm <| RemoteData.succeed mergedSteps }

                        cmd =
                            getBuildStepsLogs updatedModel org repo buildNumber mergedSteps logFocus refresh
                    in
                    ( updatedModel, cmd )

                Err error ->
                    ( model, addError error )

        StepResponse _ _ _ _ response ->
            case response of
                Ok ( _, step ) ->
                    ( updateStep model step, Cmd.none )

                Err error ->
                    ( model, addError error )

        StepLogResponse stepNumber logFocus refresh response ->
            case response of
                Ok ( _, incomingLog ) ->
                    let
                        following =
                            rm.build.followingStep /= 0

                        onFollowedStep =
                            rm.build.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                        ( steps, focusId ) =
                            if following && refresh && onFollowedStep then
                                ( rm.build.steps
                                    |> RemoteData.unwrap rm.build.steps
                                        (\s -> expandActiveStep stepNumber s |> RemoteData.succeed)
                                , stepBottomTrackerFocusId <| String.fromInt rm.build.followingStep
                                )

                            else if not refresh then
                                ( rm.build.steps, Util.extractFocusIdFromRange <| focusFragmentToFocusId "step" logFocus )

                            else
                                ( rm.build.steps, "" )

                        cmd =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( updateLogs { model | repo = updateBuildSteps rm steps } incomingLog
                    , cmd
                    )

                Err error ->
                    ( model, addError error )

        ServicesResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, services ) ->
                    let
                        mergedServices =
                            services
                                |> List.sortBy .number
                                |> Pages.Build.Update.mergeServices logFocus refresh rm.build.services

                        updatedModel =
                            { model | repo = updateBuildServices rm <| RemoteData.succeed mergedServices }

                        cmd =
                            getBuildServicesLogs updatedModel org repo buildNumber mergedServices logFocus refresh
                    in
                    ( updatedModel, cmd )

                Err error ->
                    ( model, addError error )
        ServiceLogResponse serviceNumber logFocus refresh response ->
            case response of
                Ok ( _, incomingLog ) ->
                    let
                        following =
                            rm.build.followingService /= 0

                        onFollowedService =
                            rm.build.followingService == (Maybe.withDefault -1 <| String.toInt serviceNumber)

                        ( services, focusId ) =
                            if following && refresh && onFollowedService then
                                ( rm.build.services
                                    |> RemoteData.unwrap rm.build.services
                                        (\s -> expandActiveService serviceNumber s |> RemoteData.succeed)
                                , stepBottomTrackerFocusId <| String.fromInt rm.build.followingService
                                )

                            else if not refresh then
                                ( rm.build.services, Util.extractFocusIdFromRange <| focusFragmentToFocusId "service" logFocus )

                            else
                                ( rm.build.services, "" )

                        cmd =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( updateLogs { model | repo = updateBuildServices rm services } incomingLog
                    , cmd
                    )

                Err error ->
                    ( model, addError error )

        GetPipelineConfigResponse org repo ref response ->
            case response of
                Ok ( meta, config ) ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed { data = config }, "" )
                                , expanded = False
                                , expanding = False
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( toFailure error, detailedErrorToString error )
                            }
                      }
                    , Errors.addError error HandleError
                    )

        ExpandPipelineConfigResponse org repo ref response ->
            case response of
                Ok ( _, config ) ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed { data = config }, "" )
                                , expanded = True
                                , expanding = False
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( Errors.toFailure error, detailedErrorToString error )
                                , expanding = False
                                , expanded = True
                            }
                      }
                    , addError error
                    )

        GetPipelineTemplatesResponse org repo response ->
            case response of
                Ok ( meta, templates ) ->
                    ( { model
                        | templates = ( RemoteData.succeed templates, "" )
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | templates = ( toFailure error, detailedErrorToString error ) }, addError error )

        SecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    let
                        secretsModel =
                            model.secretsModel

                        updatedSecretsModel =
                            Pages.Secrets.Update.reinitializeSecretUpdate secretsModel secret
                    in
                    ( { model | secretsModel = updatedSecretsModel }
                    , Cmd.none
                    )

                Err error ->
                    ( model, addError error )

        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    let
                        secretsModel =
                            model.secretsModel

                        updatedSecretsModel =
                            Pages.Secrets.Update.reinitializeSecretAdd secretsModel
                    in
                    ( { model | secretsModel = updatedSecretsModel }
                    , Cmd.none
                    )
                        |> addSecretResponseAlert secret

                Err error ->
                    ( model, addError error )

        UpdateSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    let
                        secretsModel =
                            model.secretsModel

                        updatedSecretsModel =
                            Pages.Secrets.Update.reinitializeSecretUpdate secretsModel secret
                    in
                    ( { model | secretsModel = updatedSecretsModel }
                    , Cmd.none
                    )
                        |> updateSecretResponseAlert secret

                Err error ->
                    ( model, addError error )

        RepoSecretsResponse response ->
            receiveSecrets model response Vela.RepoSecret

        OrgSecretsResponse response ->
            receiveSecrets model response Vela.OrgSecret

        SharedSecretsResponse response ->
            receiveSecrets model response Vela.SharedSecret

        DeleteSecretResponse response ->
            case response of
                Ok ( _, r_string ) ->
                    let
                        secretsModel =
                            model.secretsModel

                        secretsType =
                            secretTypeToString secretsModel.type_

                        alertMessage =
                            secretsModel.form.name ++ " removed from " ++ secretsType ++ " secrets."

                        redirectTo =
                            Pages.Secrets.Update.deleteSecretRedirect secretsModel
                    in
                    ( model, Navigation.pushUrl model.navigationKey redirectTo )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" alertMessage Nothing)

                Err error ->
                    ( model, addError error )

        -- Time
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
                    let
                        ( favicon, cmd ) =
                            refreshFavicon model.page model.favicon rm.build.build
                    in
                    ( { model | time = time, favicon = favicon }, cmd )

                FiveSecond _ ->
                    ( model, refreshPage model )

                OneSecondHidden ->
                    let
                        ( favicon, cmd ) =
                            refreshFavicon model.page model.favicon rm.build.build
                    in
                    ( { model | time = time, favicon = favicon }, cmd )

                FiveSecondHidden data ->
                    ( model, refreshPageHidden model data )

        -- Components
        AddSecretUpdate engine m ->
            let
                ( newModel, action ) =
                    Pages.Secrets.Update.update model m
            in
            ( newModel
            , action
            )

        -- Other
        HandleError error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error)

        AlertsUpdate subMsg ->
            Alerting.update Alerts.successConfig AlertsUpdate subMsg model

        SessionChanged newSession ->
            ( { model | session = newSession }, Cmd.none )

        FilterBuildEventBy maybeEvent org repo ->
            let
                builds =
                    rm.builds
            in
            ( { model | repo = { rm | builds = { builds | builds = Loading, pager = [] } } }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo Nothing Nothing maybeEvent )

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
            let
                cmd =
                    case visibility of
                        Visible ->
                            refreshPage model

                        Hidden ->
                            Cmd.none
            in
            ( { model | visibility = visibility, shift = False }, cmd )

        PushUrl url ->
            ( model
            , Navigation.pushUrl model.navigationKey url
            )

        -- NoOp
        NoOp ->
            ( model, Cmd.none )


{-| addSecretResponseAlert : takes secret and produces Toasty alert for when adding a secret
-}
addSecretResponseAlert :
    Secret
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
addSecretResponseAlert secret =
    let
        type_ =
            secretTypeToString secret.type_

        msg =
            secret.name ++ " added to " ++ type_ ++ " secrets."
    in
    Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" msg Nothing)


{-| updateSecretResponseAlert : takes secret and produces Toasty alert for when updating a secret
-}
updateSecretResponseAlert :
    Secret
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
updateSecretResponseAlert secret =
    let
        type_ =
            secretTypeToString secret.type_

        msg =
            String.Extra.toSentenceCase <| type_ ++ " secret " ++ secret.name ++ " updated."
    in
    Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" msg Nothing)



-- SUBSCRIPTIONS


keyDecoder : Decode.Decoder String
keyDecoder =
    Decode.field "key" Decode.string


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch <|
        [ Interop.onSessionChange decodeOnSessionChange
        , Interop.onThemeChange decodeOnThemeChange
        , onMouseDown "contextual-help" model ShowHideHelp
        , onMouseDown "identity" model ShowHideIdentity
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


{-| refreshSubscriptions : takes model and returns the subscriptions for automatically refreshing page data
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
                [ every Util.oneSecondMillis <| Tick OneSecondHidden
                , every Util.fiveSecondsMillis <| Tick (FiveSecondHidden <| refreshData model)
                ]


{-| refreshFavicon : takes page and restores the favicon to the default when not viewing the build page
-}
refreshFavicon : Page -> Favicon -> WebData Build -> ( Favicon, Cmd Msg )
refreshFavicon page currentFavicon build =
    case page of
        Pages.Build _ _ _ _   ->
            case build of
                RemoteData.Success b ->
                    let
                        newFavicon =
                            statusToFavicon b.status
                    in
                    if currentFavicon /= newFavicon then
                        ( newFavicon, Interop.setFavicon <| Encode.string newFavicon )

                    else
                        ( currentFavicon, Cmd.none )

                _ ->
                    ( currentFavicon, Cmd.none )

        _ ->
            if currentFavicon /= defaultFavicon then
                ( defaultFavicon, Interop.setFavicon <| Encode.string defaultFavicon )

            else
                ( currentFavicon, Cmd.none )


{-| refreshPage : refreshes Vela data based on current page and build status
-}
refreshPage : Model -> Cmd Msg
refreshPage model =
    let
        page =
            model.page
    in
    case page of
        Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            getBuilds model org repo maybePage maybePerPage maybeEvent

        Pages.Build org repo buildNumber focusFragment   ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildSteps model org repo buildNumber focusFragment
                , refreshLogs model org repo buildNumber model.repo.build.steps Nothing
                ]

    
        Pages.BuildPipeline org repo buildNumber _ _ _ ->
            Cmd.batch
            [ getBuilds model org repo Nothing Nothing Nothing
            , refreshBuild model org repo buildNumber
            ]

        Pages.Hooks org repo maybePage maybePerPage ->
            Cmd.batch
                [ getHooks model org repo maybePage maybePerPage
                ]

        Pages.OrgSecrets engine org maybePage maybePerPage ->
            Cmd.batch
                [ getOrgSecrets model maybePage maybePerPage engine org
                ]

        Pages.RepoSecrets engine org repo maybePage maybePerPage ->
            Cmd.batch
                [ getRepoSecrets model maybePage maybePerPage engine org repo
                ]

        Pages.SharedSecrets engine org team maybePage maybePerPage ->
            Cmd.batch
                [ getSharedSecrets model maybePage maybePerPage engine org team
                ]

        _ ->
            Cmd.none


{-| refreshPageHidden : refreshes Vela data based on current page and build status when tab is not visible
-}
refreshPageHidden : Model -> RefreshData -> Cmd Msg
refreshPageHidden model _ =
    let
        page =
            model.page
    in
    case page of
        Pages.Build org repo buildNumber   _ ->
            Cmd.batch
                [ refreshBuild model org repo buildNumber
                ]

        _ ->
            Cmd.none


{-| refreshData : takes model and extracts data needed to refresh the page
-}
refreshData : Model -> RefreshData
refreshData model =
    let
        rm =
            model.repo

        buildNumber =
            case rm.build.build of
                Success build ->
                    Just <| String.fromInt build.number

                _ ->
                    Nothing
    in
    { org = rm.org, repo = rm.name, build_number = buildNumber, steps = Nothing }


{-| refreshBuild : takes model org repo and build number and refreshes the build status
-}
refreshBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
refreshBuild model org repo buildNumber =
    let
        refresh =
            getBuild model org repo buildNumber
    in
    if shouldRefresh model.repo.build.build then
        refresh

    else
        Cmd.none


{-| refreshBuildSteps : takes model org repo and build number and refreshes the build steps based on step status
-}
refreshBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildSteps model org repo buildNumber focusFragment =
    if shouldRefresh model.repo.build.build then
        getAllBuildSteps model org repo buildNumber focusFragment True

    else
        Cmd.none


{-| shouldRefresh : takes build and returns true if a refresh is required
-}
shouldRefresh : WebData Build -> Bool
shouldRefresh build =
    case build of
        Success bld ->
            not <| isComplete bld.status

        NotAsked ->
            True

        -- Do not refresh a Failed or Loading build
        Failure _ ->
            False

        Loading ->
            False


{-| refreshLogs : takes model org repo and build number and steps and refreshes the build step logs depending on their status
-}
refreshLogs : Model -> Org -> Repo -> BuildNumber -> WebData Steps -> FocusFragment -> Cmd Msg
refreshLogs model org repo buildNumber inSteps focusFragment =
    let
        stepsToRefresh =
            case inSteps of
                Success s ->
                    -- Do not refresh logs for a step in success or failure state
                    List.filter (\step -> step.status /= Vela.Success && step.status /= Vela.Failure) s

                _ ->
                    []

        refresh =
            getBuildStepsLogs model org repo buildNumber stepsToRefresh focusFragment True
    in
    if shouldRefresh model.repo.build.build then
        refresh

    else
        Cmd.none


{-| onMouseDown : takes model and returns subscriptions for handling onMouseDown events at the browser level
-}
onMouseDown : String -> Model -> (Maybe Bool -> Msg) -> Sub Msg
onMouseDown targetId model triggerMsg =
    if model.showHelp then
        Browser.Events.onMouseDown (outsideTarget targetId <| triggerMsg <| Just False)

    else if model.showIdentity then
        Browser.Events.onMouseDown (outsideTarget targetId <| triggerMsg <| Just False)

    else
        Sub.none


{-| outsideTarget : returns decoder for handling clicks that occur from outside the currently focused/open dropdown
-}
outsideTarget : String -> Msg -> Decode.Decoder Msg
outsideTarget targetId msg =
    Decode.field "target" (isOutsideTarget targetId)
        |> Decode.andThen
            (\isOutside ->
                if isOutside then
                    Decode.succeed msg

                else
                    Decode.fail "inside dropdown"
            )


{-| isOutsideTarget : returns decoder for determining if click target occurred from within a specified element
-}
isOutsideTarget : String -> Decode.Decoder Bool
isOutsideTarget targetId =
    Decode.oneOf
        [ Decode.field "id" Decode.string
            |> Decode.andThen
                (\id ->
                    if targetId == id then
                        -- found match by id
                        Decode.succeed False

                    else
                        -- try next decoder
                        Decode.fail "continue"
                )
        , Decode.lazy (\_ -> isOutsideTarget targetId |> Decode.field "parentNode")

        -- fallback if all previous decoders failed
        , Decode.succeed True
        ]



-- VIEW


view : Model -> Document Msg
view model =
    let
        ( title, content ) =
            viewContent model
    in
    { title = "Vela - " ++ title
    , body =
        [ lazy2 viewHeader model.session { feedbackLink = model.velaFeedbackURL, docsLink = model.velaDocsURL, theme = model.theme, help = helpArgs model, showId = model.showIdentity }
        , lazy2 Nav.viewNav model navMsgs
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

        Pages.SourceRepositories ->
            ( "Source Repositories"
            , lazy2 Pages.SourceRepos.view
                { user = model.user
                , sourceRepos = model.sourceRepos
                , filters = model.filters
                }
                sourceReposMsgs
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
                [ Pager.view model.repo.hooks.pager Pager.defaultLabels GotoPage
                , lazy Pages.Hooks.view
                    { hooks = model.repo.hooks
                    , time = model.time
                    }
                , Pager.view model.repo.hooks.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepoSettings org repo ->
            ( String.join "/" [ org, repo ] ++ " settings"
            , lazy5 Pages.RepoSettings.view model.repo.repo model.inTimeout repoSettingsMsgs model.velaAPI (Url.toString model.entryURL)
            )

        Pages.RepoSecrets engine org repo _ _ ->
            ( String.join "/" [ org, repo ] ++ " " ++ engine ++ " repo secrets"
            , div []
                [ Html.map (\_ -> NoOp) <| lazy Pages.Secrets.View.viewRepoSecrets model
                , Html.map (\_ -> NoOp) <| lazy3 Pages.Secrets.View.viewOrgSecrets model True False
                ]
            )

        Pages.OrgSecrets engine org maybePage _ ->
            let
                page : String
                page =
                    case maybePage of
                        Nothing ->
                            ""

                        Just p ->
                            " (page " ++ String.fromInt p ++ ")"
            in
            ( String.join "/" [ org ] ++ " " ++ engine ++ " org secrets" ++ page
            , div []
                [ Html.map (\_ -> NoOp) <| lazy3 Pages.Secrets.View.viewOrgSecrets model False True
                , Pager.view model.secretsModel.orgSecretsPager { previousLabel = "prev", nextLabel = "next" } GotoPage
                ]
            )

        Pages.SharedSecrets engine org team _ _ ->
            ( String.join "/" [ org, team ] ++ " " ++ engine ++ " shared secrets"
            , div []
                [ Pager.view model.secretsModel.sharedSecretsPager { previousLabel = "prev", nextLabel = "next" } GotoPage
                , Html.map (\_ -> NoOp) <| lazy Pages.Secrets.View.viewSharedSecrets model
                , Pager.view model.secretsModel.sharedSecretsPager { previousLabel = "prev", nextLabel = "next" } GotoPage
                ]
            )

        Pages.AddOrgSecret engine _ ->
            ( "add " ++ engine ++ " org secret"
            , Html.map (\m -> AddSecretUpdate engine m) <| lazy Pages.Secrets.View.addSecret model
            )

        Pages.AddRepoSecret engine _ _ ->
            ( "add " ++ engine ++ " repo secret"
            , Html.map (\m -> AddSecretUpdate engine m) <| lazy Pages.Secrets.View.addSecret model
            )

        Pages.AddSharedSecret engine _ _ ->
            ( "add " ++ engine ++ " shared secret"
            , Html.map (\m -> AddSecretUpdate engine m) <| lazy Pages.Secrets.View.addSecret model
            )

        Pages.OrgSecret engine org name ->
            ( String.join "/" [ org, name ] ++ " update " ++ engine ++ " org secret"
            , Html.map (\m -> AddSecretUpdate engine m) <| lazy Pages.Secrets.View.editSecret model
            )

        Pages.RepoSecret engine org repo name ->
            ( String.join "/" [ org, repo, name ] ++ " update " ++ engine ++ " repo secret"
            , Html.map (\m -> AddSecretUpdate engine m) <| lazy Pages.Secrets.View.editSecret model
            )

        Pages.SharedSecret engine org team name ->
            ( String.join "/" [ org, team, name ] ++ " update " ++ engine ++ " shared secret"
            , Html.map (\m -> AddSecretUpdate engine m) <| lazy Pages.Secrets.View.editSecret model
            )

        Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            let
                page : String
                page =
                    case maybePage of
                        Nothing ->
                            ""

                        Just p ->
                            " (page " ++ String.fromInt p ++ ")"

                shouldRenderFilter : Bool
                shouldRenderFilter =
                    case ( model.repo.builds.builds, maybeEvent ) of
                        ( Success result, Nothing ) ->
                            not <| List.length result == 0

                        ( Success _, _ ) ->
                            True

                        ( Loading, _ ) ->
                            True

                        _ ->
                            False
            in
            ( String.join "/" [ org, repo ] ++ " builds" ++ page
            , div []
                [ viewBuildsFilter shouldRenderFilter org repo maybeEvent
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy6 Pages.Builds.view model.repo.builds model.time model.zone org repo maybeEvent
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.Build org repo buildNumber _  ->
            
            ( "Build #" ++ buildNumber ++ " - " ++ String.join "/" [ org, repo ]
            , Pages.Build.View.viewBuild
                            model
                            buildMsgs
                            org
                            repo 
            )

        Pages.BuildServices org repo buildNumber _  ->
            
            ( "Build #" ++ buildNumber ++ " - " ++ String.join "/" [ org, repo ]
            , Pages.Build.View.viewBuildServices 
                            model
                            buildMsgs
                            org
                            repo 
            )

        Pages.BuildPipeline org repo buildNumber ref expand lineFocus ->
            ( "Pipeline " ++ String.join "/" [ org, repo ]
            ,  Pages.Pipeline.View.viewPipeline
                        model
                        pipelineMsgs
                        ref
                        |> Pages.Build.View.wrapWithBuildPreview
                            model
                            org
                            repo

 
            )
        Pages.Pipeline org repo   ref expand lineFocus ->
            ( "Pipeline " ++ String.join "/" [ org, repo ]
            , Pages.Pipeline.View.viewPipeline
                        model
                        pipelineMsgs
                        ref
            )



        Pages.Settings ->
            ( "Settings"
            , Pages.Settings.view model.session (Pages.Settings.Msgs Copy)
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


viewBuildsFilter : Bool -> Org -> Repo -> Maybe Event -> Html Msg
viewBuildsFilter shouldRender org repo maybeEvent =
    let
        eventEnum : List String
        eventEnum =
            [ "all", "push", "pull_request", "tag", "deployment", "comment" ]

        eventToMaybe : String -> Maybe Event
        eventToMaybe event =
            case event of
                "all" ->
                    Nothing

                _ ->
                    Just event
    in
    if shouldRender then
        div [ class "form-controls", class "build-filters", Util.testAttribute "build-filter" ] <|
            div [] [ text "Filter by Event:" ]
                :: List.map
                    (\e ->
                        div [ class "form-control" ]
                            [ input
                                [ type_ "radio"
                                , id <| "filter-" ++ e
                                , name "build-filter"
                                , Util.testAttribute <| "build-filter-" ++ e
                                , checked <| maybeEvent == eventToMaybe e
                                , onClick <| FilterBuildEventBy (eventToMaybe e) org repo
                                , attribute "aria-label" <| "filter to show " ++ e ++ " events"
                                ]
                                []
                            , label
                                [ class "form-label"
                                , for <| "filter-" ++ e
                                ]
                                [ text <| String.replace "_" " " e ]
                            ]
                    )
                    eventEnum

    else
        text ""


buildMsgs : Pages.Build.Model.Msgs Msg
buildMsgs =
    { clickBuildNavTab = ClickBuildNavTab
    , collapseAllSteps = CollapseAllSteps
    , expandAllSteps = ExpandAllSteps
    , expandStep = ExpandStep
    , expandService = ExpandService
    , logsMsgs =
        { focusLine = PushUrl
        , download = DownloadTextFile
        , focusOn = FocusOn
        , followStep = FollowStep
        }
    }


pipelineMsgs : Pages.Pipeline.Model.Msgs Msg
pipelineMsgs =
    { get = GetPipelineConfig, expand = ExpandPipelineConfig, focusLineNumber = FocusLineNumber, clickNavTab = ClickBuildNavTab }


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


viewHeader : Maybe Session -> { feedbackLink : String, docsLink : String, theme : Theme, help : Help.Commands.Model Msg, showId : Bool } -> Html Msg
viewHeader maybeSession { feedbackLink, docsLink, theme, help, showId } =
    let
        session : Session
        session =
            Maybe.withDefault defaultSession maybeSession

        identityBaseClassList : Html.Attribute Msg
        identityBaseClassList =
            classList
                [ ( "details", True )
                , ( "-marker-right", True )
                , ( "-no-pad", True )
                , ( "identity-name", True )
                ]

        identityAttributeList : List (Html.Attribute Msg)
        identityAttributeList =
            attribute "role" "navigation" :: Util.open showId
    in
    header []
        [ div [ class "identity", id "identity", Util.testAttribute "identity" ]
            [ a [ Routes.href Routes.Overview, class "identity-logo-link", attribute "aria-label" "Home" ] [ velaLogo 24 ]
            , case session.username of
                "" ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (ShowHideIdentity Nothing), Util.testAttribute "identity-summary" ] [ text "Vela" ] ]

                _ ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (ShowHideIdentity Nothing), Util.testAttribute "identity-summary" ]
                            [ text session.username
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , ul [ class "identity-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                            [ li [ class "identity-menu-item" ]
                                [ a [ Routes.href Routes.Settings, Util.testAttribute "settings-link", attribute "role" "menuitem" ] [ text "Settings" ] ]
                            , li [ class "identity-menu-item" ]
                                [ a [ Routes.href Routes.Logout, Util.testAttribute "logout-link", attribute "role" "menuitem" ] [ text "Logout" ] ]
                            ]
                        ]
            ]
        , nav [ class "help-links", attribute "role" "navigation" ]
            [ ul []
                [ li [] [ viewThemeToggle theme ]
                , li [] [ a [ href feedbackLink, attribute "aria-label" "go to feedback" ] [ text "feedback" ] ]
                , li [] [ a [ href docsLink, attribute "aria-label" "go to docs" ] [ text "docs" ] ]
                , Help.View.help help
                ]
            ]
        ]


helpArg : WebData a -> Help.Commands.Arg
helpArg arg =
    { success = Util.isSuccess arg, loading = Util.isLoading arg }


helpArgs : Model -> Help.Commands.Model Msg
helpArgs model =
    { user = helpArg model.user
    , sourceRepos = helpArg model.sourceRepos
    , builds = helpArg model.repo.builds.builds
    , build = helpArg model.repo.build.build
    , repo = helpArg model.repo.repo
    , hooks = helpArg model.repo.hooks.hooks
    , secrets = helpArg model.secretsModel.repoSecrets
    , show = model.showHelp
    , toggle = ShowHideHelp
    , copy = Copy
    , noOp = NoOp
    , page = model.page
    }


viewAlerts : Stack Alert -> Html Msg
viewAlerts toasties =
    div [ Util.testAttribute "alerts", class "alerts" ] [ Alerting.view Alerts.successConfig (Alerts.view Copy) AlertsUpdate toasties ]


wrapAlertMessage : String -> String
wrapAlertMessage message =
    if not <| String.isEmpty message then
        "`" ++ message ++ "` "

    else
        message


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

        rm =
            model.repo

        build =
            rm.build
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

        ( Routes.SourceRepositories, True ) ->
            loadSourceReposPage model

        ( Routes.Hooks org repo maybePage maybePerPage, True ) ->
            loadHooksPage model org repo maybePage maybePerPage

        ( Routes.RepoSettings org repo, True ) ->
            loadRepoSettingsPage model org repo

        ( Routes.OrgSecrets engine org maybePage maybePerPage, True ) ->
            loadOrgSecretsPage model maybePage maybePerPage engine org

        ( Routes.RepoSecrets engine org repo maybePage maybePerPage, True ) ->
            loadRepoSecretsPage model maybePage maybePerPage engine org repo

        ( Routes.SharedSecrets engine org team maybePage maybePerPage, True ) ->
            loadSharedSecretsPage model maybePage maybePerPage engine org team

        ( Routes.AddOrgSecret engine org, True ) ->
            loadAddOrgSecretPage model engine org

        ( Routes.AddRepoSecret engine org repo, True ) ->
            loadAddRepoSecretPage model engine org repo

        ( Routes.AddSharedSecret engine org team, True ) ->
            loadAddSharedSecretPage model engine org team

        ( Routes.OrgSecret engine org name, True ) ->
            loadUpdateOrgSecretPage model engine org name

        ( Routes.RepoSecret engine org repo name, True ) ->
            loadUpdateRepoSecretPage model engine org repo name

        ( Routes.SharedSecret engine org team name, True ) ->
            loadUpdateSharedSecretPage model engine org team name

        ( Routes.RepositoryBuilds org repo maybePage maybePerPage maybeEvent, True ) ->
            let
                currentSession : Session
                currentSession =
                    Maybe.withDefault defaultSession model.session
            in
            loadRepoBuildsPage model org repo currentSession maybePage maybePerPage maybeEvent

        ( Routes.Build org repo buildNumber lineFocus  , True ) ->
            let
                _ = buildChanged (Pages.Build org repo buildNumber lineFocus) model.page
            in

            case model.page of
                Pages.BuildPipeline o r b _ _ _ ->
                    case rm.build.build of
                        NotAsked ->
                            loadBuildPage model org repo buildNumber lineFocus True  

                        Failure _ ->
                            loadBuildPage model org repo buildNumber lineFocus True   

                        _ ->
                            if not <| resourceChanged ( org, repo, rm.build.buildNumber ) ( o, r,  b ) then
                                let
                                    ( steps, action ) =
                                        focusStepLogs model (RemoteData.withDefault [] rm.build.steps) org repo buildNumber lineFocus getBuildStepsLogs
                                in
                                ( { model
                                    | page = Pages.Build org repo buildNumber lineFocus  
                                    , repo =
                                        { rm
                                            | build =
                                                { build
                                                    | buildNumber = buildNumber
                                                    , followingStep = 0
                                                    , steps = RemoteData.succeed steps
                                                    , focusFragment =
                                                        case lineFocus of
                                                            Just l ->
                                                                Just <| "#" ++ l

                                                            Nothing ->
                                                                Nothing
                                                }
                                        }
                                  }
                                , Cmd.batch
                                    [ getBuild model org repo buildNumber
                                    , getAllBuildSteps model org repo buildNumber lineFocus False
                                    , action
                                    ]
                                )

                            else
                                loadBuildPage model org repo buildNumber lineFocus True  

                Pages.Build o r b _   ->
                    if not <| resourceChanged ( org, repo, buildNumber ) ( o, r, b ) then
                        let
                            ( steps, action ) =
                                focusStepLogs model (RemoteData.withDefault [] rm.build.steps) org repo buildNumber lineFocus getBuildStepsLogs
                        in
                        ( { model
                            | page = Pages.Build org repo buildNumber lineFocus   
                                    , repo =
                                        { rm
                                            | build =
                                                { build
                                                    | buildNumber = buildNumber
                                                    , steps = RemoteData.succeed steps
                                                    , focusFragment =
                                                        case lineFocus of
                                                            Just l ->
                                                                Just <| "#" ++ l

                                                            Nothing ->
                                                                Nothing
                                                }
                                        }
                                  }
                        , action
                        )

                    else
                        loadBuildPage model org repo buildNumber lineFocus False  
                Pages.BuildServices o r b _   ->
                    if not <| resourceChanged ( org, repo, buildNumber ) ( o, r, b ) then
                        let
                            ( steps, action ) =
                                focusStepLogs model (RemoteData.withDefault [] rm.build.steps) org repo buildNumber lineFocus getBuildStepsLogs
                        in
                        ( { model
                            | page = Pages.Build org repo buildNumber lineFocus   
                                    , repo =
                                        { rm
                                            | build =
                                                { build
                                                    | buildNumber = buildNumber
                                                    , steps = RemoteData.succeed steps
                                                    , focusFragment =
                                                        case lineFocus of
                                                            Just l ->
                                                                Just <| "#" ++ l

                                                            Nothing ->
                                                                Nothing
                                                }
                                        }
                                }
                        , action
                        ) 

                    else 
                        loadBuildPage model org repo buildNumber lineFocus False  
                _ ->
                    loadBuildPage model org repo buildNumber lineFocus False  
        ( Routes.BuildServices org repo buildNumber lineFocus  , True ) ->
                case model.page of
                    Pages.BuildServices o r b _   ->
                        if not <| resourceChanged ( org, repo, buildNumber ) ( o, r, b ) then
                            let
                                ( services, action ) =
                                    focusServiceLogs model (RemoteData.withDefault [] rm.build.services) org repo buildNumber lineFocus getBuildServicesLogs
                            in
                            ( { model
                                | page = Pages.BuildServices org repo buildNumber lineFocus   
                                        , repo =
                                            { rm
                                                | build =
                                                    { build
                                                        | buildNumber = buildNumber
                                                        , services = RemoteData.succeed services
                                                        , focusFragment =
                                                            case lineFocus of
                                                                Just l ->
                                                                    Just <| "#" ++ l

                                                                Nothing ->
                                                                    Nothing
                                                    }
                                            }
                                    }
                            , action
                            )

                        else
                            loadBuildServicesPage model org repo buildNumber lineFocus False  
                    Pages.Build o r b _   ->
                        if not <| resourceChanged ( org, repo, buildNumber ) ( o, r, b ) then
                            let
                                ( services, action ) =
                                    focusServiceLogs model (RemoteData.withDefault [] rm.build.services) org repo buildNumber lineFocus getBuildServicesLogs
                            in
                            ( { model
                                | page = Pages.BuildServices org repo buildNumber lineFocus   
                                        , repo =
                                            { rm
                                                | build =
                                                    { build
                                                        | buildNumber = buildNumber
                                                        , services = RemoteData.succeed services
                                                        , focusFragment =
                                                            case lineFocus of
                                                                Just l ->
                                                                    Just <| "#" ++ l

                                                                Nothing ->
                                                                    Nothing
                                                    }
                                            }
                                    }
                            , action
                            ) 

                        else 
                            loadBuildServicesPage model org repo buildNumber lineFocus False  

                    _ ->
                        loadBuildServicesPage model org repo buildNumber lineFocus False  
        ( Routes.BuildPipeline org repo buildNumber ref expand lineFocus, True ) ->
                    case model.page of
                        -- todo handle build and ref?
                        -- todo handle maybe values
                        Pages.BuildPipeline o r  b r_ ex _ ->
                            let
                                pipeline =
                                    model.pipeline

                                parsed =
                                    parseFocusFragment lineFocus

                                currentRef =
                                    ( org, repo, Maybe.withDefault "" r_ )

                                incomingRef =
                                    ( o, r, Maybe.withDefault "_" ref )
                                currentBuild =
                                    ( org, repo,  b )

                                incomingBuild =
                                    ( o, r, buildNumber )
                            in
                            if resourceChanged currentRef incomingRef || resourceChanged currentBuild incomingBuild then
                                loadBuildPipelinePage model org repo buildNumber  ref expand lineFocus False                            
                            else
                                ( { model
                                    | pipeline =
                                        { pipeline | lineFocus = ( parsed.lineA, parsed.lineB ) }
                                  }
                                , Cmd.none
                                )

                        Pages.Build o r b   _   ->
                            loadBuildPipelinePage model org repo buildNumber  ref expand lineFocus True

                        _ ->

                            loadBuildPipelinePage model org repo buildNumber  ref expand lineFocus False
        ( Routes.Pipeline org repo   ref expand lineFocus, True ) ->
            let
                ( newModel, action ) =
                    loadPipelinePage model org repo   ref expand lineFocus False
            in
            ( newModel, action ) |> setPipelineFocusFragment lineFocus

        ( Routes.Settings, True ) ->
            ( { model | page = Pages.Settings, showIdentity = False }, Cmd.none )

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

buildChanged : Page -> Page -> Bool
buildChanged onPage toPage =
    let
        (onIdentifier, onFocus) =
            case onPage of
                Pages.Build o r b f ->
                    ((o, r, b), f)
                Pages.BuildServices o r b f ->
                    ((o, r, b), f)
                Pages.BuildPipeline o r b _ _ f ->
                    ((o, r, b), f)
                _ ->
                    (("","","" ), Nothing)
        (toIdentifier, toFocus) =
            case onPage of
                Pages.Build o r b f ->
                    ((o, r, b), f)
                Pages.BuildServices o r b f ->
                    ((o, r, b), f)
                Pages.BuildPipeline o r b _ _ f ->
                    ((o, r, b), f)
                _ ->
                    (("","","" ), Nothing)
    in
        if not <| resourceChanged onIdentifier toIdentifier then
            if onFocus == toFocus then
                let
                    _ = Debug.log "focus changed on:" onFocus
                    _ = Debug.log "focus changed to:" toFocus
                in
                    True
            else
                True
        else
            True
    
setBuildFocusFragment : FocusFragment -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
setBuildFocusFragment logFocus ( model, c ) =
    let
        rm =
            model.repo
    in
    ( { model
        | repo =
            updateBuildFocusFragment rm <|
                case logFocus of
                    Just l ->
                        Just <| "#" ++ l

                    Nothing ->
                        Nothing
      }
    , c
    )


setPipelineFocusFragment : FocusFragment -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
setPipelineFocusFragment logFocus ( model, c ) =
    let
        p =
            model.pipeline
    in
    ( { model
        | pipeline =
            { p
                | focusFragment =
                    case logFocus of
                        Just l ->
                            Just <| "#" ++ l

                        Nothing ->
                            Nothing
            }
      }
    , c
    )


loadSourceReposPage : Model -> ( Model, Cmd Msg )
loadSourceReposPage model =
    case model.sourceRepos of
        NotAsked ->
            ( { model | page = Pages.SourceRepositories, sourceRepos = Loading }
            , Cmd.batch
                [ Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model
                , getCurrentUser model
                ]
            )

        Failure _ ->
            ( { model | page = Pages.SourceRepositories, sourceRepos = Loading }
            , Cmd.batch
                [ Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model
                , getCurrentUser model
                ]
            )

        _ ->
            ( { model | page = Pages.SourceRepositories }, getCurrentUser model )


loadOverviewPage : Model -> ( Model, Cmd Msg )
loadOverviewPage model =
    ( { model | page = Pages.Overview }
    , Cmd.batch
        [ getCurrentUser model
        ]
    )


{-| resourceChanged : takes two repo resource identifiers and returns if the build has changed
-}
resourceChanged : RepoResourceIdentifier -> RepoResourceIdentifier -> Bool
resourceChanged ( orgA, repoA, idA ) ( orgB, repoB, idB ) =
    not <| orgA == orgB && repoA == repoB && idA == idB


loadRepoSubPage : Model -> Org -> Repo -> Page -> ( Model, Cmd Msg )
loadRepoSubPage model org repo toPage =
    let
        rm =
            model.repo

        builds =
            rm.builds

        hooks =
            rm.hooks

        build =
            rm.build

        secretsModel =
            model.secretsModel

        fetchSecrets : Org -> Repo -> Cmd Msg
        fetchSecrets o r =
            Cmd.batch [ getAllRepoSecrets model "native" o r, getAllOrgSecrets model "native" o ]

        -- update model and dispatch cmds depending on initialization state and destination
        ( loadModel, loadCmd ) =
            -- repo data has not been initialized or org/repo has changed
            if not rm.initialized || resourceChanged ( rm.org, rm.name, "" ) ( org, repo, "" ) then
                ( { model
                    | secretsModel =
                        { secretsModel
                            | repoSecrets = Loading
                            , orgSecrets = Loading
                            , org = org
                            , repo = repo
                            , engine = "native"
                            , type_ = Vela.RepoSecret
                        }
                    , repo =
                        { rm
                            | org = org
                            , name = repo
                            , repo = Loading
                            , builds =
                                case toPage of
                                    Pages.RepositoryBuilds o r maybePage maybePerPage maybeEvent ->
                                        { builds | builds = Loading, maybeEvent = maybeEvent, maybePage = maybePage, maybePerPage = maybePerPage }

                                    _ ->
                                        { builds | builds = Loading, maybePage = Nothing, maybePerPage = Nothing, maybeEvent = Nothing }
                            , hooks =
                                case toPage of
                                    Pages.Hooks o r maybePage maybePerPage ->
                                        { hooks | hooks = Loading, maybePage = maybePage, maybePerPage = maybePerPage }

                                    _ ->
                                        { hooks | hooks = Loading, maybePage = Nothing, maybePerPage = Nothing }
                            , build = { build | steps = NotAsked }
                            , initialized = True
                        }
                  }
                , Cmd.batch
                    [ getCurrentUser model
                    , getRepo model org repo
                    , case toPage of
                        Pages.RepositoryBuilds o r maybePage maybePerPage maybeEvent ->
                            getBuilds model o r maybePage maybePerPage maybeEvent

                        _ ->
                            getBuilds model org repo Nothing Nothing Nothing
                    , case toPage of
                        Pages.Hooks o r maybePage maybePerPage ->
                            getHooks model o r maybePage maybePerPage

                        _ ->
                            getHooks model org repo Nothing Nothing
                    , case toPage of
                        Pages.RepoSecrets engine o r maybePage maybePerPage ->
                            fetchSecrets o r

                        _ ->
                            fetchSecrets org repo
                    ]
                )

            else
                -- repo data has already been initialized and org/repo has not changed, aka tab switch
                case toPage of
                    Pages.RepositoryBuilds o r maybePage maybePerPage maybeEvent ->
                        ( { model
                            | repo =
                                { rm
                                    | builds =
                                        { builds | maybePage = maybePage, maybePerPage = maybePerPage, maybeEvent = maybeEvent }
                                }
                          }
                        , getBuilds model o r maybePage maybePerPage maybeEvent
                        )

                    Pages.RepoSecrets engine o r maybePage maybePerPage ->
                        ( model, fetchSecrets o r )

                    Pages.Hooks o r maybePage maybePerPage ->
                        ( { model
                            | repo = updateHooksModel rm { hooks | maybePage = maybePage, maybePerPage = maybePerPage }
                          }
                        , getHooks model o r maybePage maybePerPage
                        )

                    Pages.RepoSettings o r ->
                        ( model, getRepo model o r )

                    -- page is not a repo subpage
                    _ ->
                        ( model, Cmd.none )
    in
    ( { loadModel | page = toPage }, loadCmd )


{-| loadRepoBuildsPage : takes model org and repo and loads the appropriate builds.

    loadRepoBuildsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadRepoBuildsPage : Model -> Org -> Repo -> Session -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> ( Model, Cmd Msg )
loadRepoBuildsPage model org repo _ maybePage maybePerPage maybeEvent =
    loadRepoSubPage model org repo <| Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent


{-| loadRepoSecretsPage : takes model org and repo and loads the page for managing repo secrets
-}
loadRepoSecretsPage :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Repo
    -> ( Model, Cmd Msg )
loadRepoSecretsPage model maybePage maybePerPage engine org repo =
    loadRepoSubPage model org repo <| Pages.RepoSecrets engine org repo maybePage maybePerPage


{-| loadHooksPage : takes model org and repo and loads the hooks page.
-}
loadHooksPage : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadHooksPage model org repo maybePage maybePerPage =
    loadRepoSubPage model org repo <| Pages.Hooks org repo maybePage maybePerPage


{-| loadSettingsPage : takes model org and repo and loads the page for updating repo configurations
-}
loadRepoSettingsPage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadRepoSettingsPage model org repo =
    loadRepoSubPage model org repo <| Pages.RepoSettings org repo


{-| loadOrgSecretsPage : takes model org and loads the page for managing org secrets
-}
loadOrgSecretsPage :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> ( Model, Cmd Msg )
loadOrgSecretsPage model maybePage maybePerPage engine org =
    -- Fetch secrets from Api
    let
        secretsModel =
            model.secretsModel
    in
    ( { model
        | page =
            Pages.OrgSecrets engine org maybePage maybePerPage
        , secretsModel =
            { secretsModel
                | orgSecrets = Loading
                , org = org
                , engine = engine
                , type_ = Vela.OrgSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getOrgSecrets model maybePage maybePerPage engine org
        ]
    )


{-| loadSharedSecretsPage : takes model org and team and loads the page for managing shared secrets
-}
loadSharedSecretsPage :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Team
    -> ( Model, Cmd Msg )
loadSharedSecretsPage model maybePage maybePerPage engine org team =
    -- Fetch secrets from Api
    let
        secretsModel =
            model.secretsModel
    in
    ( { model
        | page =
            Pages.SharedSecrets engine org team maybePage maybePerPage
        , secretsModel =
            { secretsModel
                | repoSecrets = Loading
                , org = org
                , team = team
                , engine = engine
                , type_ = Vela.SharedSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSharedSecrets model maybePage maybePerPage engine org team
        ]
    )


{-| loadAddOrgSecretPage : takes model and engine loads the page for adding secrets
-}
loadAddOrgSecretPage : Model -> Engine -> Org -> ( Model, Cmd Msg )
loadAddOrgSecretPage model engine org =
    -- Fetch secrets from Api
    let
        secretsModel =
            Pages.Secrets.Update.reinitializeSecretAdd model.secretsModel
    in
    ( { model
        | page = Pages.AddOrgSecret engine org
        , secretsModel =
            { secretsModel
                | sharedSecrets = Loading
                , org = org
                , engine = engine
                , type_ = Vela.OrgSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        ]
    )


{-| loadAddRepoSecretPage : takes model engine org and repo and loads the page for adding secrets
-}
loadAddRepoSecretPage : Model -> Engine -> Org -> Repo -> ( Model, Cmd Msg )
loadAddRepoSecretPage model engine org repo =
    -- Fetch secrets from Api
    let
        secretsModel =
            Pages.Secrets.Update.reinitializeSecretAdd model.secretsModel
    in
    ( { model
        | page = Pages.AddRepoSecret engine org repo
        , secretsModel =
            { secretsModel
                | org = org
                , repo = repo
                , engine = engine
                , type_ = Vela.RepoSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        ]
    )


{-| loadAddSharedSecretPage : takes model engine org and team and loads the page for adding secrets
-}
loadAddSharedSecretPage : Model -> Engine -> Org -> Team -> ( Model, Cmd Msg )
loadAddSharedSecretPage model engine org team =
    -- Fetch secrets from Api
    let
        secretsModel =
            Pages.Secrets.Update.reinitializeSecretAdd model.secretsModel
    in
    ( { model
        | page = Pages.AddSharedSecret engine org team
        , secretsModel =
            { secretsModel
                | org = org
                , team = team
                , engine = engine
                , type_ = Vela.SharedSecret
                , form = secretsModel.form
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        ]
    )


{-| loadUpdateOrgSecretPage : takes model org and name and loads the page for updating a repo secret
-}
loadUpdateOrgSecretPage : Model -> Engine -> Org -> Name -> ( Model, Cmd Msg )
loadUpdateOrgSecretPage model engine org name =
    -- Fetch secrets from Api
    let
        secretsModel =
            model.secretsModel
    in
    ( { model
        | page = Pages.OrgSecret engine org name
        , secretsModel =
            { secretsModel
                | org = org
                , engine = engine
                , type_ = Vela.OrgSecret
                , deleteState = Pages.Secrets.Model.NotAsked_
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecret model engine "org" org "*" name
        ]
    )


{-| loadUpdateRepoSecretPage : takes model org, repo and name and loads the page for updating a repo secret
-}
loadUpdateRepoSecretPage : Model -> Engine -> Org -> Repo -> Name -> ( Model, Cmd Msg )
loadUpdateRepoSecretPage model engine org repo name =
    -- Fetch secrets from Api
    let
        secretsModel =
            model.secretsModel
    in
    ( { model
        | page = Pages.RepoSecret engine org repo name
        , secretsModel =
            { secretsModel
                | org = org
                , repo = repo
                , engine = engine
                , type_ = Vela.RepoSecret
                , deleteState = Pages.Secrets.Model.NotAsked_
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecret model engine "repo" org repo name
        ]
    )


{-| loadUpdateSharedSecretPage : takes model org, team and name and loads the page for updating a shared secret
-}
loadUpdateSharedSecretPage : Model -> Engine -> Org -> Team -> Name -> ( Model, Cmd Msg )
loadUpdateSharedSecretPage model engine org team name =
    -- Fetch secrets from Api
    let
        secretsModel =
            model.secretsModel
    in
    ( { model
        | page = Pages.SharedSecret engine org team name
        , secretsModel =
            { secretsModel
                | org = org
                , team = team
                , engine = engine
                , type_ = Vela.SharedSecret
                , deleteState = Pages.Secrets.Model.NotAsked_
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecret model engine "shared" org team name
        ]
    )


{-| loadBuildPage : takes model org, repo, and build number and loads the appropriate build.
-}
loadBuildPage : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Bool  ->( Model, Cmd Msg )
loadBuildPage model org repo buildNumber lineFocus soft   =
    let
        rm =
            model.repo

        modelBuilds =
            rm.builds

        build =
            rm.build

        pipeline =
            model.pipeline

        builds =
            if (not <| Util.isSuccess rm.builds.builds) && not soft then
                { modelBuilds | builds = Loading }

            else
                rm.builds
    in
    -- Fetch build from Api
    ( { model
        | page = Pages.Build org repo buildNumber lineFocus  
        , pipeline = { pipeline | focusFragment = Nothing }
        , repo =
            { rm
                | build =
                    { build
                        | build =
                            if soft then
                                build.build

                            else
                                Loading
                        , buildNumber = buildNumber
                        , steps = NotAsked
                        , logs = []
                        , followingStep = 0
                        , focusFragment =
                            case lineFocus of
                                Just l ->
                                    Just <| "#" ++ l

                                Nothing ->
                                    Nothing
                    }
                , builds = builds
            }
      }
    , Cmd.batch
        [ getBuilds model org repo Nothing Nothing Nothing
        , getBuild model org repo buildNumber
        , getAllBuildSteps model org repo buildNumber lineFocus False
        ]
    )



{-| loadBuildServicesPage : takes model org, repo, and build number and loads the appropriate build services.
-}
loadBuildServicesPage : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Bool  ->( Model, Cmd Msg )
loadBuildServicesPage model org repo buildNumber lineFocus soft   =
    let
        rm =
            model.repo

        modelBuilds =
            rm.builds

        build =
            rm.build

        pipeline =
            model.pipeline

        builds =
            if (not <| Util.isSuccess rm.builds.builds) && not soft then
                { modelBuilds | builds = Loading }

            else
                rm.builds
    in
    -- Fetch build from Api
    ( { model
        | page = Pages.BuildServices org repo buildNumber lineFocus  
        , pipeline = { pipeline | focusFragment = Nothing }
        , repo =
            { rm
                | build =
                    { build
                        | build =
                            if soft then
                                build.build

                            else
                                Loading
                        , buildNumber = buildNumber
                        , services = NotAsked
                        , logs = []
                        , followingService = 0
                        , focusFragment =
                            case lineFocus of
                                Just l ->
                                    Just <| "#" ++ l

                                Nothing ->
                                    Nothing
                    }
                , builds = builds
            }
      }
    , Cmd.batch
        [ getBuilds model org repo Nothing Nothing Nothing
        , getBuild model org repo buildNumber
        , getAllBuildServices model org repo buildNumber lineFocus False
        ]
    )


{-| loadBuildPipelinePage : takes model org, repo, and ref and loads the appropriate pipeline configuration resources.
-}
loadBuildPipelinePage : Model -> Org -> Repo ->   BuildNumber -> Maybe RefQuery -> Maybe ExpandTemplatesQuery -> Maybe Fragment -> Bool -> ( Model, Cmd Msg )
loadBuildPipelinePage model org repo buildNumber ref expand lineFocus refresh =
    let
        getPipelineConfigAction =
            case expand of
                Just e ->
                    if e == "true" then
                        expandPipelineConfig model org repo ref

                    else
                        getPipelineConfig model org repo ref

                Nothing ->
                    getPipelineConfig model org repo ref

        parsed =
            parseFocusFragment lineFocus

        rm =
            model.repo

        build =
            rm.build

        pipeline =
            model.pipeline
        templates =
            model.templates
    in
    ( { model
        |
         page =  Pages.BuildPipeline org repo buildNumber ref expand lineFocus
         ,  repo = { rm | build = { build | focusFragment = Nothing } }
        , pipeline =
            { config =
                if refresh then
                    pipeline.config

                else
                    ( Loading, "" )
            , expanded =   if refresh then
                    pipeline.expanded

                else
                    False
            , expanding = if refresh then
                    pipeline.expanding

                else
                    True
            , org = org
            , repo = repo
            , ref = ref
            , expand = expand
            , lineFocus = ( parsed.lineA, parsed.lineB )
            , focusFragment =
                case lineFocus of
                    Just l ->
                        Just <| "#" ++ l

                    Nothing ->
                        Nothing
            , buildNumber = Just buildNumber
            }
        , templates = if refresh then
                    templates

                else
                    ( Loading, "" )
      }
    , Cmd.batch
        [ 
                Cmd.batch [ getBuilds model org repo Nothing Nothing Nothing, getBuild model org repo buildNumber ]
 
        , getPipelineConfigAction
        , getPipelineTemplates model org repo ref
        ]
    )




{-| loadPipelinePage : takes model org, repo, and ref and loads the appropriate pipeline configuration resources.
-}
loadPipelinePage : Model -> Org -> Repo -> Maybe RefQuery -> Maybe ExpandTemplatesQuery -> Maybe Fragment -> Bool -> ( Model, Cmd Msg )
loadPipelinePage model org repo   ref expand lineFocus refresh =
    let
        getPipelineConfigAction =
            case expand of
                Just e ->
                    if e == "true" then
                        expandPipelineConfig model org repo ref

                    else
                        getPipelineConfig model org repo ref

                Nothing ->
                    getPipelineConfig model org repo ref

        parsed =
            parseFocusFragment lineFocus

        rm =
            model.repo

        build =
            rm.build

        pipeline =
            model.pipeline
    in
    ( { model
        |
         page =  Pages.Pipeline org repo   ref expand lineFocus
         ,  repo = { rm | build = { build | focusFragment = Nothing } }
        , pipeline =
            { config =
                if refresh then
                    pipeline.config

                else
                    ( Loading, "" )
            , expanded = False
            , expanding = True
            , org = org
            , repo = repo
            , ref = ref
            , expand = expand
            , lineFocus = ( parsed.lineA, parsed.lineB )
            , focusFragment =
                case lineFocus of
                    Just l ->
                        Just <| "#" ++ l

                    Nothing ->
                        Nothing
            , buildNumber = Nothing
            }
        , templates = ( Loading, "" )
      }
    , Cmd.batch
        [ getPipelineConfigAction
        , getPipelineTemplates model org repo ref
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
buildEnableRepositoryPayload : Repository -> EnableRepositoryPayload
buildEnableRepositoryPayload repo =
    { defaultEnableRepositoryPayload
        | org = repo.org
        , name = repo.name
        , full_name = repo.org ++ "/" ++ repo.name
        , link = repo.link
        , clone = repo.clone
    }


{-| addError : takes a detailed http error and produces a Cmd Msg that invokes an action in the Errors module
-}
addError : Http.Detailed.Error String -> Cmd Msg
addError error =
    Errors.addError error HandleError


{-| stepsIds : extracts Ids from list of steps and returns List Int
-}
stepsIds : Steps -> List Int
stepsIds steps =
    List.map (\step -> step.number) steps


{-| logIds : extracts Ids from list of logs and returns List Int
-}
logIds : Logs -> List Int
logIds logs =
    List.map (\log -> log.id) <| Util.successful logs


{-| updateStep : takes model and incoming step and updates the list of steps if necessary
-}
updateStep : Model -> Step -> Model
updateStep model incomingStep =
    let
        rm =
            model.repo

        steps =
            case rm.build.steps of
                Success s ->
                    s

                _ ->
                    []

        stepExists =
            List.member incomingStep.number <| stepsIds steps

        following =
            rm.build.followingStep /= 0
    in
    if stepExists then
        { model
            | repo =
                updateBuildSteps rm
                    (steps
                        |> updateIf (\step -> incomingStep.number == step.number)
                            (\step ->
                                let
                                    shouldView =
                                        following
                                            && (step.status /= Vela.Pending)
                                            && (step.number == getCurrentResource steps)
                                in
                                { incomingStep
                                    | viewing = step.viewing || shouldView
                                }
                            )
                        |> RemoteData.succeed
                    )
        }

    else
        { model | repo = updateBuildSteps rm <| RemoteData.succeed <| incomingStep :: steps }


{-| updateLogs : takes model and incoming log and updates the list of logs if necessary
-}
updateLogs : Model -> Log -> Model
updateLogs model incomingLog =
    let
        rm =
            model.repo

        build =
            rm.build

        logs =
            build.logs

        logExists =
            List.member incomingLog.id <| logIds logs
    in
    if logExists then
        { model | repo = updateBuildLogs rm <| updateLog incomingLog logs }

    else if incomingLog.id /= 0 then
        { model | repo = updateBuildLogs rm <| addLog incomingLog logs }

    else
        model


{-| updateLog : takes incoming log and logs and updates the appropriate log data
-}
updateLog : Log -> Logs -> Logs
updateLog incomingLog logs =
    updateIf
        (\log ->
            case log of
                Success log_ ->
                    incomingLog.id == log_.id && incomingLog.rawData /= log_.rawData

                _ ->
                    True
        )
        (\log -> RemoteData.succeed { incomingLog | decodedLogs = Util.base64Decode incomingLog.rawData })
        logs


receiveSecrets : Model -> Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ) -> SecretType -> ( Model, Cmd Msg )
receiveSecrets model response type_ =
    let
        secretsModel =
            model.secretsModel

        currentSecrets =
            case type_ of
                Vela.RepoSecret ->
                    secretsModel.repoSecrets

                Vela.OrgSecret ->
                    secretsModel.orgSecrets

                Vela.SharedSecret ->
                    secretsModel.sharedSecrets
    in
    case response of
        Ok ( meta, secrets ) ->
            let
                mergedSecrets =
                    RemoteData.succeed <|
                        List.reverse <|
                            List.sortBy .id <|
                                case currentSecrets of
                                    Success s ->
                                        Util.mergeListsById s secrets

                                    _ ->
                                        secrets

                pager =
                    Pagination.get meta.headers

                sm =
                    case type_ of
                        Vela.RepoSecret ->
                            { secretsModel
                                | repoSecrets = mergedSecrets
                                , repoSecretsPager = pager
                            }

                        Vela.OrgSecret ->
                            { secretsModel
                                | orgSecrets = mergedSecrets
                                , orgSecretsPager = pager
                            }

                        Vela.SharedSecret ->
                            { secretsModel
                                | sharedSecrets = mergedSecrets
                                , sharedSecretsPager = pager
                            }
            in
            ( { model
                | secretsModel =
                    sm
              }
            , Cmd.none
            )

        Err error ->
            let
                e =
                    toFailure error

                sm =
                    case type_ of
                        Vela.RepoSecret ->
                            { secretsModel | repoSecrets = e }

                        Vela.OrgSecret ->
                            { secretsModel | orgSecrets = e }

                        Vela.SharedSecret ->
                            { secretsModel | sharedSecrets = e }
            in
            ( { model | secretsModel = sm }, addError error )


{-| addLog : takes incoming log and logs and adds log when not present
-}
addLog : Log -> Logs -> Logs
addLog incomingLog logs =
    RemoteData.succeed { incomingLog | decodedLogs = Util.base64Decode incomingLog.rawData } :: logs


{-| homeMsgs : prepares the input record required for the Home page to route Msgs back to Main.elm
-}
homeMsgs : Pages.Home.Msgs Msg
homeMsgs =
    Pages.Home.Msgs ToggleFavorite SearchFavorites


{-| navMsgs : prepares the input record required for the nav component to route Msgs back to Main.elm
-}
navMsgs : Nav.Msgs Msg
navMsgs =
    Nav.Msgs FetchSourceRepositories ToggleFavorite RefreshSettings RefreshHooks RefreshSecrets RestartBuild


{-| sourceReposMsgs : prepares the input record required for the SourceRepos page to route Msgs back to Main.elm
-}
sourceReposMsgs : Pages.SourceRepos.Msgs Msg
sourceReposMsgs =
    Pages.SourceRepos.Msgs SearchSourceRepos EnableRepo EnableRepos ToggleFavorite


{-| repoSettingsMsgs : prepares the input record required for the Settings page to route Msgs back to Main.elm
-}
repoSettingsMsgs : Pages.RepoSettings.Msgs Msg
repoSettingsMsgs =
    Pages.RepoSettings.Msgs UpdateRepoEvent UpdateRepoAccess UpdateRepoTimeout ChangeRepoTimeout DisableRepo EnableRepo Copy ChownRepo RepairRepo


initSecretsModel : Pages.Secrets.Model.Model Msg
initSecretsModel =
    Pages.Secrets.Update.init SecretResponse RepoSecretsResponse OrgSecretsResponse SharedSecretsResponse AddSecretResponse UpdateSecretResponse DeleteSecretResponse



-- API HELPERS


getCurrentUser : Model -> Cmd Msg
getCurrentUser model =
    Api.try CurrentUserResponse <| Api.getCurrentUser model


getHooks : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getHooks model org repo maybePage maybePerPage =
    Api.try (HooksResponse org repo) <| Api.getHooks model maybePage maybePerPage org repo


getRepo : Model -> Org -> Repo -> Cmd Msg
getRepo model org repo =
    Api.try RepoResponse <| Api.getRepo model org repo


getBuilds : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Cmd Msg
getBuilds model org repo maybePage maybePerPage maybeEvent =
    Api.try (BuildsResponse org repo) <| Api.getBuilds model maybePage maybePerPage maybeEvent org repo


getBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.try (BuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getAllBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Bool -> Cmd Msg
getAllBuildSteps model org repo buildNumber logFocus refresh =
    Api.tryAll (StepsResponse org repo buildNumber logFocus refresh) <| Api.getAllSteps model org repo buildNumber


getBuildStepLogs : Model -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd Msg
getBuildStepLogs model org repo buildNumber stepNumber logFocus refresh =
    Api.try (StepLogResponse stepNumber logFocus refresh) <| Api.getStepLogs model org repo buildNumber stepNumber


getBuildStepsLogs : Model -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd Msg
getBuildStepsLogs model org repo buildNumber steps logFocus refresh =
    Cmd.batch <|
        List.map
            (\step ->
                if step.viewing then
                    getBuildStepLogs model org repo buildNumber (String.fromInt step.number) logFocus refresh

                else
                    Cmd.none
            )
            steps


getAllBuildServices : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Bool -> Cmd Msg
getAllBuildServices model org repo buildNumber logFocus refresh =
    Api.tryAll (ServicesResponse org repo buildNumber logFocus refresh) <| Api.getAllServices model org repo buildNumber

getBuildServiceLogs : Model -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd Msg
getBuildServiceLogs model org repo buildNumber stepNumber logFocus refresh =
    Api.try (ServiceLogResponse stepNumber logFocus refresh) <| Api.getServiceLogs model org repo buildNumber stepNumber

getBuildServicesLogs : Model -> Org -> Repo -> BuildNumber -> Services -> FocusFragment -> Bool -> Cmd Msg
getBuildServicesLogs model org repo buildNumber services logFocus refresh =
    Cmd.batch <|
        List.map
            (\service ->
                if service.viewing then
                    getBuildServiceLogs model org repo buildNumber (String.fromInt service.number) logFocus refresh

                else
                    Cmd.none
            )
            services

restartBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
restartBuild model org repo buildNumber =
    Api.try (RestartedBuildResponse org repo buildNumber) <| Api.restartBuild model org repo buildNumber


getRepoSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Repo
    -> Cmd Msg
getRepoSecrets model maybePage maybePerPage engine org repo =
    Api.try RepoSecretsResponse <| Api.getSecrets model maybePage maybePerPage engine "repo" org repo


getAllRepoSecrets :
    Model
    -> Engine
    -> Org
    -> Repo
    -> Cmd Msg
getAllRepoSecrets model engine org repo =
    Api.tryAll RepoSecretsResponse <| Api.getAllSecrets model engine "repo" org repo


getOrgSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Cmd Msg
getOrgSecrets model maybePage maybePerPage engine org =
    Api.try OrgSecretsResponse <| Api.getSecrets model maybePage maybePerPage engine "org" org "*"


getAllOrgSecrets :
    Model
    -> Engine
    -> Org
    -> Cmd Msg
getAllOrgSecrets model engine org =
    Api.tryAll OrgSecretsResponse <| Api.getAllSecrets model engine "org" org "*"


getSharedSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Team
    -> Cmd Msg
getSharedSecrets model maybePage maybePerPage engine org team =
    Api.try SharedSecretsResponse <| Api.getSecrets model maybePage maybePerPage engine "shared" org team


getSecret : Model -> Engine -> Type -> Org -> Key -> Name -> Cmd Msg
getSecret model engine type_ org key name =
    Api.try SecretResponse <| Api.getSecret model engine type_ org key name


{-| getPipelineConfig : takes model, org, repo and ref and fetches a pipeline configuration from the API.
-}
getPipelineConfig : Model -> Org -> Repo -> Maybe Ref -> Cmd Msg
getPipelineConfig model org repo ref =
    Api.tryString (GetPipelineConfigResponse org repo ref) <| Api.getPipelineConfig model org repo ref


{-| expandPipelineConfig : takes model, org, repo and ref and expands a pipeline configuration via the API.
-}
expandPipelineConfig : Model -> Org -> Repo -> Maybe Ref -> Cmd Msg
expandPipelineConfig model org repo ref =
    Api.tryString (ExpandPipelineConfigResponse org repo ref) <| Api.expandPipelineConfig model org repo ref


{-| getPipelineTemplates : takes model, org, repo and ref and fetches templates used in a pipeline configuration from the API.
-}
getPipelineTemplates : Model -> Org -> Repo -> Maybe Ref -> Cmd Msg
getPipelineTemplates model org repo ref =
    Api.try (GetPipelineTemplatesResponse org repo) <| Api.getPipelineTemplates model org repo ref



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
