{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Main exposing (main)

import Alerts exposing (Alert)
import Api
import Api.Endpoint
import Api.Pagination as Pagination
import Auth.Jwt exposing (JwtAccessToken, JwtAccessTokenClaims, extractJwtClaims)
import Auth.Session exposing (Session(..), SessionDetails, refreshAccessToken)
import Browser exposing (Document, UrlRequest)
import Browser.Dom as Dom
import Browser.Events exposing (Visibility(..))
import Browser.Navigation as Navigation
import Dict
import Errors exposing (Error, addErrorString, detailedErrorToString, toFailure)
import Favorites exposing (addFavorite, toFavorite, updateFavorites)
import FeatherIcons
import File.Download as Download
import Focus
    exposing
        ( ExpandTemplatesQuery
        , Fragment
        , focusFragmentToFocusId
        , lineRangeId
        , parseFocusFragment
        , resourceFocusFragment
        )
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
import Html.Lazy exposing (lazy, lazy2, lazy3, lazy5, lazy7, lazy8)
import Http
import Http.Detailed
import Interop
import Json.Decode as Decode
import Json.Encode as Encode
import Maybe
import Maybe.Extra exposing (unwrap)
import Nav exposing (viewUtil)
import Pager
import Pages exposing (Page)
import Pages.Build.Logs
    exposing
        ( addLog
        , bottomTrackerFocusId
        , clickResource
        , expandActive
        , focusAndClear
        , isViewing
        , setAllViews
        , updateLog
        )
import Pages.Build.Model
import Pages.Build.View
import Pages.Builds
import Pages.Deployments.Model
import Pages.Deployments.Update exposing (initializeFormFromDeployment)
import Pages.Deployments.View
import Pages.Home
import Pages.Hooks
import Pages.Organization
import Pages.Pipeline.Model
import Pages.Pipeline.View exposing (safeDecodePipelineData)
import Pages.RepoSettings exposing (enableUpdate)
import Pages.Secrets.Model
import Pages.Secrets.Update
import Pages.Secrets.View
import Pages.Settings
import Pages.SourceRepos
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import String.Extra
import SvgBuilder exposing (velaLogo)
import Task
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
import Util
import Vela exposing (AuthParams, Build, BuildModel, BuildNumber, Builds, CurrentUser, Deployment, DeploymentId, EnableRepositoryPayload, Engine, Event, Favicon, Field, FocusFragment, HookNumber, Hooks, Key, Log, Logs, Name, Org, PipelineConfig, PipelineModel, PipelineTemplates, Ref, Repo, RepoModel, RepoResourceIdentifier, RepoSearchFilters, Repositories, Repository, Schedules, Secret, SecretType, Secrets, ServiceNumber, Services, SourceRepositories, StepNumber, Steps, Team, Templates, Theme(..), Type, UpdateRepositoryPayload, UpdateUserPayload, buildUpdateFavoritesPayload, buildUpdateRepoBoolPayload, buildUpdateRepoIntPayload, buildUpdateRepoStringPayload, decodeTheme, defaultEnableRepositoryPayload, defaultFavicon, defaultPipeline, defaultPipelineTemplates, defaultRepoModel, encodeEnableRepository, encodeTheme, encodeUpdateRepository, encodeUpdateUser, isComplete, secretTypeToString, statusToFavicon, stringToTheme, updateBuild, updateBuildNumber, updateBuildPipelineConfig, updateBuildPipelineExpand, updateBuildPipelineFocusFragment, updateBuildPipelineLineFocus, updateBuildServices, updateBuildServicesFocusFragment, updateBuildServicesFollowing, updateBuildServicesLogs, updateBuildSteps, updateBuildStepsFocusFragment, updateBuildStepsFollowing, updateBuildStepsLogs, updateBuilds, updateBuildsEvent, updateBuildsPage, updateBuildsPager, updateBuildsPerPage, updateBuildsShowTimeStamp, updateDeployments, updateDeploymentsPage, updateDeploymentsPager, updateDeploymentsPerPage, updateHooks, updateHooksPage, updateHooksPager, updateHooksPerPage, updateOrgRepo, updateOrgReposPage, updateOrgReposPager, updateOrgReposPerPage, updateOrgRepositories, updateRepo, updateRepoCounter, updateRepoEnabling, updateRepoInitialized, updateRepoLimit, updateRepoTimeout)



-- TYPES


type alias Flags =
    { isDev : Bool
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaTheme : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    }


type alias Model =
    { page : Page
    , session : Session
    , user : WebData CurrentUser
    , toasties : Stack Alert
    , sourceRepos : WebData SourceRepositories
    , repo : RepoModel
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , navigationKey : Navigation.Key
    , zone : Zone
    , time : Posix
    , filters : RepoSearchFilters
    , favoritesFilter : String
    , entryURL : Url
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    , showHelp : Bool
    , showIdentity : Bool
    , favicon : Favicon
    , secretsModel : Pages.Secrets.Model.Model Msg
    , deploymentModel : Pages.Deployments.Model.Model Msg
    , pipeline : PipelineModel
    , templates : PipelineTemplates
    , buildMenuOpen : List Int
    }


type Interval
    = OneSecond
    | OneSecondHidden
    | FiveSecond
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
            , session = Unauthenticated
            , user = NotAsked
            , sourceRepos = NotAsked
            , velaAPI = flags.velaAPI
            , velaFeedbackURL = flags.velaFeedbackURL
            , velaDocsURL = flags.velaDocsURL
            , velaRedirect = flags.velaRedirect
            , velaLogBytesLimit = flags.velaLogBytesLimit
            , velaMaxBuildLimit = flags.velaMaxBuildLimit
            , navigationKey = navKey
            , toasties = Alerting.initialState
            , zone = utc
            , time = millisToPosix 0
            , filters = Dict.empty
            , favoritesFilter = ""
            , repo = defaultRepoModel
            , entryURL = url
            , theme = stringToTheme flags.velaTheme
            , shift = False
            , visibility = Visible
            , showHelp = False
            , showIdentity = False
            , buildMenuOpen = []
            , favicon = defaultFavicon
            , secretsModel = initSecretsModel
            , deploymentModel = initDeploymentsModel
            , pipeline = defaultPipeline
            , templates = defaultPipelineTemplates
            }

        ( newModel, newPage ) =
            setNewPage (Routes.match url) model

        setTimeZone : Cmd Msg
        setTimeZone =
            Task.perform AdjustTimeZone here

        setTime : Cmd Msg
        setTime =
            Task.perform AdjustTime Time.now

        fetchToken : Cmd Msg
        fetchToken =
            case String.length model.velaRedirect of
                0 ->
                    getToken model

                _ ->
                    Cmd.none
    in
    ( newModel
    , Cmd.batch
        [ fetchToken
        , newPage
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
    | ChangeRepoLimit String
    | ChangeRepoTimeout String
    | ChangeRepoCounter String
    | RefreshSettings Org Repo
    | RefreshHooks Org Repo
    | RefreshSecrets Engine SecretType Org Repo
    | FilterBuildEventBy (Maybe Event) Org Repo
    | ShowHideFullTimestamp
    | SetTheme Theme
    | GotoPage Pagination.Page
    | ShowHideHelp (Maybe Bool)
    | ShowHideBuildMenu (Maybe Int) (Maybe Bool)
    | ShowHideIdentity (Maybe Bool)
    | Copy String
    | DownloadFile String (String -> String) String String
    | ExpandAllSteps Org Repo BuildNumber
    | CollapseAllSteps
    | ExpandStep Org Repo BuildNumber StepNumber
    | FollowStep Int
    | ExpandAllServices Org Repo BuildNumber
    | CollapseAllServices
    | ExpandService Org Repo BuildNumber ServiceNumber
    | FollowService Int
    | ShowHideTemplates
    | FocusPipelineConfigLineNumber Int
      -- Outgoing HTTP requests
    | RefreshAccessToken
    | SignInRequested
    | FetchSourceRepositories
    | ToggleFavorite Org (Maybe Repo)
    | AddFavorite Org (Maybe Repo)
    | EnableRepos Repositories
    | EnableRepo Repository
    | DisableRepo Repository
    | ChownRepo Repository
    | RepairRepo Repository
    | UpdateRepoEvent Org Repo Field Bool
    | UpdateRepoAccess Org Repo Field String
    | UpdateRepoPipelineType Org Repo Field String
    | UpdateRepoLimit Org Repo Field Int
    | UpdateRepoTimeout Org Repo Field Int
    | UpdateRepoCounter Org Repo Field Int
    | RestartBuild Org Repo BuildNumber
    | CancelBuild Org Repo BuildNumber
    | RedeliverHook Org Repo HookNumber
    | GetPipelineConfig Org Repo BuildNumber Ref FocusFragment Bool
    | ExpandPipelineConfig Org Repo BuildNumber Ref FocusFragment Bool
      -- Inbound HTTP responses
    | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, JwtAccessToken ))
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | RepoFavoritedResponse String Bool (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | OrgRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Repository ))
    | RepoEnabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoDisabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoChownedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoRepairedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | CancelBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | OrgBuildsResponse Org (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | DeploymentsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, List Deployment ))
    | HooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | RedeliverHookResponse Org Repo HookNumber (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | BuildResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | SchedulesResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Schedules ))
    | BuildAndPipelineResponse Org Repo (Maybe ExpandTemplatesQuery) (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | DeploymentResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Deployment ))
    | StepsResponse Org Repo BuildNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepLogResponse StepNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
    | ServicesResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Services ))
    | ServiceLogResponse ServiceNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
    | GetPipelineConfigResponse FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, PipelineConfig ))
    | ExpandPipelineConfigResponse FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | GetPipelineTemplatesResponse FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Templates ))
    | SecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | AddDeploymentResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Deployment ))
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
    | SecretsUpdate Pages.Secrets.Model.Msg
    | AddDeploymentUpdate Pages.Deployments.Model.Msg
      -- Other
    | HandleError Error
    | AlertsUpdate (Alerting.Msg Alert)
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

        ChangeRepoLimit limit ->
            let
                newLimit =
                    Maybe.withDefault 0 <| String.toInt limit
            in
            ( { model | repo = updateRepoLimit (Just newLimit) rm }, Cmd.none )

        ChangeRepoTimeout timeout ->
            let
                newTimeout =
                    case String.toInt timeout of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | repo = updateRepoTimeout newTimeout rm }, Cmd.none )

        ChangeRepoCounter counter ->
            let
                newCounter =
                    case String.toInt counter of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | repo = updateRepoCounter newCounter rm }, Cmd.none )

        RefreshSettings org repo ->
            ( { model
                | repo =
                    rm
                        |> updateRepoLimit Nothing
                        |> updateRepoTimeout Nothing
                        |> updateRepoCounter Nothing
                        |> updateRepo Loading
              }
            , Api.try RepoResponse <| Api.getRepo model org repo
            )

        RefreshHooks org repo ->
            ( { model | repo = updateHooks Loading rm }, getHooks model org repo Nothing Nothing )

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

        FilterBuildEventBy maybeEvent org repo ->
            let
                route =
                    case repo of
                        "" ->
                            Routes.OrgBuilds org Nothing Nothing maybeEvent

                        _ ->
                            Routes.RepositoryBuilds org repo Nothing Nothing maybeEvent
            in
            ( { model
                | repo =
                    rm
                        |> updateBuilds Loading
                        |> updateBuildsPager []
              }
            , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| route
            )

        ShowHideFullTimestamp ->
            ( { model | repo = rm |> updateBuildsShowTimeStamp }, Cmd.none )

        SetTheme theme ->
            if theme == model.theme then
                ( model, Cmd.none )

            else
                ( { model | theme = theme }, Interop.setTheme <| encodeTheme theme )

        GotoPage pageNumber ->
            case model.page of
                Pages.OrgBuilds org _ maybePerPage maybeEvent ->
                    ( { model | repo = updateBuilds Loading rm }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.OrgBuilds org (Just pageNumber) maybePerPage maybeEvent
                    )

                Pages.OrgRepositories org _ maybePerPage ->
                    ( { model | repo = updateOrgRepositories Loading rm }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.OrgRepositories org (Just pageNumber) maybePerPage
                    )

                Pages.RepositoryBuilds org repo _ maybePerPage maybeEvent ->
                    ( { model | repo = updateBuilds Loading rm }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo (Just pageNumber) maybePerPage maybeEvent
                    )

                Pages.RepositoryDeployments org repo _ maybePerPage ->
                    ( { model | repo = updateDeployments Loading rm }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryDeployments org repo (Just pageNumber) maybePerPage
                    )

                Pages.Hooks org repo _ maybePerPage ->
                    ( { model | repo = updateHooks Loading rm }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Hooks org repo (Just pageNumber) maybePerPage
                    )

                Pages.RepoSecrets engine org repo _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | repoSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepoSecrets engine org repo (Just pageNumber) maybePerPage
                    )

                Pages.OrgSecrets engine org _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | orgSecrets = Loading, sharedSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.OrgSecrets engine org (Just pageNumber) maybePerPage
                    )

                Pages.SharedSecrets engine org team _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | sharedSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }
                    , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.SharedSecrets engine org team (Just pageNumber) maybePerPage
                    )

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

        ShowHideBuildMenu build show ->
            let
                buildsOpen =
                    model.buildMenuOpen

                replaceList : Int -> List Int -> List Int
                replaceList id buildList =
                    if List.member id buildList then
                        []

                    else
                        [ id ]

                updatedOpen : List Int
                updatedOpen =
                    unwrap []
                        (\b ->
                            unwrap
                                (replaceList b buildsOpen)
                                (\_ -> buildsOpen)
                                show
                        )
                        build
            in
            ( { model
                | buildMenuOpen = updatedOpen
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

        DownloadFile ext fn filename content ->
            ( model
            , Download.string filename ext <| fn content
            )

        -- steps
        ExpandAllSteps org repo buildNumber ->
            let
                build =
                    rm.build

                steps =
                    RemoteData.unwrap build.steps.steps
                        (\steps_ -> steps_ |> setAllViews True |> RemoteData.succeed)
                        build.steps.steps

                -- refresh logs for expanded steps
                action =
                    getBuildStepsLogs model org repo buildNumber (RemoteData.withDefault [] steps) Nothing True
            in
            ( { model | repo = updateBuildSteps steps rm }
            , action
            )

        CollapseAllSteps ->
            let
                build =
                    rm.build

                steps =
                    build.steps.steps
                        |> RemoteData.unwrap build.steps.steps
                            (\steps_ -> steps_ |> setAllViews False |> RemoteData.succeed)
            in
            ( { model | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing 0 }
            , Cmd.none
            )

        ExpandStep org repo buildNumber stepNumber ->
            let
                build =
                    rm.build

                ( steps, fetchStepLogs ) =
                    clickResource build.steps.steps stepNumber

                action =
                    if fetchStepLogs then
                        getBuildStepLogs model org repo buildNumber stepNumber Nothing True

                    else
                        Cmd.none

                stepOpened =
                    isViewing steps stepNumber

                -- step clicked is step being followed
                onFollowedStep =
                    build.steps.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                follow =
                    if onFollowedStep && not stepOpened then
                        -- stop following a step when collapsed
                        0

                    else
                        build.steps.followingStep
            in
            ( { model | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing follow }
            , Cmd.batch <|
                [ action
                , if stepOpened then
                    Navigation.pushUrl model.navigationKey <| resourceFocusFragment "step" stepNumber []

                  else
                    Cmd.none
                ]
            )

        FollowStep follow ->
            ( { model | repo = updateBuildStepsFollowing follow rm }
            , Cmd.none
            )

        -- services
        ExpandAllServices org repo buildNumber ->
            let
                build =
                    rm.build

                services =
                    RemoteData.unwrap build.services.services
                        (\services_ -> services_ |> setAllViews True |> RemoteData.succeed)
                        build.services.services

                -- refresh logs for expanded services
                action =
                    getBuildServicesLogs model org repo buildNumber (RemoteData.withDefault [] services) Nothing True
            in
            ( { model | repo = updateBuildServices services rm }
            , action
            )

        CollapseAllServices ->
            let
                build =
                    rm.build

                services =
                    build.services.services
                        |> RemoteData.unwrap build.services.services
                            (\services_ -> services_ |> setAllViews False |> RemoteData.succeed)
            in
            ( { model | repo = rm |> updateBuildServices services |> updateBuildServicesFollowing 0 }
            , Cmd.none
            )

        ExpandService org repo buildNumber serviceNumber ->
            let
                build =
                    rm.build

                ( services, fetchServiceLogs ) =
                    clickResource build.services.services serviceNumber

                action =
                    if fetchServiceLogs then
                        getBuildServiceLogs model org repo buildNumber serviceNumber Nothing True

                    else
                        Cmd.none

                serviceOpened =
                    isViewing services serviceNumber

                -- step clicked is service being followed
                onFollowedService =
                    build.services.followingService == (Maybe.withDefault -1 <| String.toInt serviceNumber)

                follow =
                    if onFollowedService && not serviceOpened then
                        -- stop following a service when collapsed
                        0

                    else
                        build.services.followingService
            in
            ( { model | repo = rm |> updateBuildServices services |> updateBuildServicesFollowing follow }
            , Cmd.batch <|
                [ action
                , if serviceOpened then
                    Navigation.pushUrl model.navigationKey <| resourceFocusFragment "service" serviceNumber []

                  else
                    Cmd.none
                ]
            )

        FollowService follow ->
            ( { model | repo = updateBuildServicesFollowing follow rm }
            , Cmd.none
            )

        ShowHideTemplates ->
            let
                templates =
                    model.templates
            in
            ( { model | templates = { templates | show = not templates.show } }, Cmd.none )

        FocusPipelineConfigLineNumber line ->
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

        -- Outgoing HTTP requests
        RefreshAccessToken ->
            ( model, getToken model )

        SignInRequested ->
            -- Login on server needs to accept redirect URL and pass it along to as part of 'state' encoded as base64
            -- so we can parse it when the source provider redirects back to the API
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

        AddFavorite org repo ->
            let
                favorite =
                    toFavorite org repo

                ( favorites, favorited ) =
                    addFavorite model.user favorite

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
            in
            ( { model
                | sourceRepos = enableUpdate repo Loading model.sourceRepos
                , repo = updateRepoEnabling Vela.Enabling rm
              }
            , Api.try (RepoEnabledResponse repo) <| Api.enableRepository model body
            )

        DisableRepo repo ->
            let
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
                | repo = updateRepoEnabling status rm
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

        UpdateRepoPipelineType org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoStringPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload

                cmd =
                    if Pages.RepoSettings.validPipelineTypeUpdate rm.repo payload then
                        Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)

                    else
                        Cmd.none
            in
            ( model
            , cmd
            )

        UpdateRepoLimit org repo field value ->
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

        UpdateRepoCounter org repo field value ->
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
            let
                newModel =
                    { model | buildMenuOpen = [] }
            in
            ( newModel
            , restartBuild model org repo buildNumber
            )

        CancelBuild org repo buildNumber ->
            let
                newModel =
                    { model | buildMenuOpen = [] }
            in
            ( newModel
            , cancelBuild model org repo buildNumber
            )

        RedeliverHook org repo hookNumber ->
            ( model
            , redeliverHook model org repo hookNumber
            )

        GetPipelineConfig org repo buildNumber ref lineFocus refresh ->
            ( { model
                | pipeline =
                    { pipeline
                        | expanding = True
                    }
              }
            , Cmd.batch
                [ getPipelineConfig model org repo ref lineFocus refresh
                , Navigation.replaceUrl model.navigationKey <| Routes.routeToUrl <| Routes.BuildPipeline org repo buildNumber Nothing lineFocus
                ]
            )

        ExpandPipelineConfig org repo buildNumber ref lineFocus refresh ->
            ( { model
                | pipeline =
                    { pipeline
                        | expanding = True
                    }
              }
            , Cmd.batch
                [ expandPipelineConfig model org repo ref lineFocus refresh
                , Navigation.replaceUrl model.navigationKey <| Routes.routeToUrl <| Routes.BuildPipeline org repo buildNumber (Just "true") lineFocus
                ]
            )

        -- Inbound HTTP responses
        LogoutResponse _ ->
            -- ignoring outcome of request and proceeding to logout
            ( { model | session = Unauthenticated }
            , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Login
            )

        TokenResponse response ->
            case response of
                Ok ( _, token ) ->
                    let
                        currentSession : Session
                        currentSession =
                            model.session

                        payload : JwtAccessTokenClaims
                        payload =
                            extractJwtClaims token

                        newSessionDetails : SessionDetails
                        newSessionDetails =
                            SessionDetails token payload.exp payload.sub

                        redirectTo : String
                        redirectTo =
                            case model.velaRedirect of
                                "" ->
                                    Url.toString model.entryURL

                                _ ->
                                    model.velaRedirect

                        actions : List (Cmd Msg)
                        actions =
                            case currentSession of
                                Unauthenticated ->
                                    [ Interop.setRedirect Encode.null
                                    , Navigation.pushUrl model.navigationKey redirectTo
                                    ]

                                Authenticated _ ->
                                    []
                    in
                    ( { model | session = Authenticated newSessionDetails }
                    , Cmd.batch <| actions ++ [ refreshAccessToken RefreshAccessToken newSessionDetails ]
                    )

                Err error ->
                    let
                        redirectPage : Cmd Msg
                        redirectPage =
                            case model.page of
                                Pages.Login ->
                                    Cmd.none

                                _ ->
                                    Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Login
                    in
                    case error of
                        Http.Detailed.BadStatus meta _ ->
                            case meta.statusCode of
                                401 ->
                                    let
                                        actions : List (Cmd Msg)
                                        actions =
                                            case model.session of
                                                Unauthenticated ->
                                                    [ redirectPage ]

                                                Authenticated _ ->
                                                    [ addErrorString "Your session has expired or you logged in somewhere else, please log in again." HandleError
                                                    , redirectPage
                                                    ]
                                    in
                                    ( { model | session = Unauthenticated }
                                    , Cmd.batch actions
                                    )

                                _ ->
                                    ( { model | session = Unauthenticated }
                                    , Cmd.batch
                                        [ addError error
                                        , redirectPage
                                        ]
                                    )

                        _ ->
                            ( { model | session = Unauthenticated }
                            , Cmd.batch
                                [ addError error
                                , redirectPage
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
                    ( { model | repo = updateRepo (RemoteData.succeed repoResponse) rm }, Cmd.none )

                Err error ->
                    ( { model | repo = updateRepo (toFailure error) rm }, addError error )

        OrgRepositoriesResponse response ->
            case response of
                Ok ( meta, repoResponse ) ->
                    ( { model
                        | repo =
                            rm
                                |> updateOrgRepositories (RemoteData.succeed repoResponse)
                                |> updateOrgReposPager (Pagination.get meta.headers)
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = updateOrgRepositories (toFailure error) rm }, addError error )

        RepoEnabledResponse repo response ->
            case response of
                Ok ( _, enabledRepo ) ->
                    ( { model
                        | sourceRepos = enableUpdate enabledRepo (RemoteData.succeed True) model.sourceRepos
                        , repo = updateRepoEnabling Vela.Enabled rm
                      }
                    , Util.dispatch <| AddFavorite repo.org <| Just repo.name
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (enabledRepo.full_name ++ " enabled.") Nothing)

                Err error ->
                    let
                        ( sourceRepos, action ) =
                            repoEnabledError model.sourceRepos repo error
                    in
                    ( { model | sourceRepos = sourceRepos }, action )

        RepoDisabledResponse repo response ->
            case response of
                Ok _ ->
                    ( { model
                        | repo = updateRepoEnabling Vela.Disabled rm
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
                    ( { model | repo = updateRepo (RemoteData.succeed updatedRepo) rm }, Cmd.none )
                        |> Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (Pages.RepoSettings.alert field updatedRepo) Nothing)

                Err error ->
                    ( model, addError error )

        RepoChownedResponse repo response ->
            case response of
                Ok _ ->
                    ( model, Cmd.none )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" ("You are now the owner of " ++ repo.full_name) Nothing)

                Err error ->
                    ( model, addError error )

        RepoRepairedResponse repo response ->
            case response of
                Ok _ ->
                    ( { model
                        | sourceRepos = enableUpdate repo (RemoteData.succeed True) model.sourceRepos
                        , repo = updateRepoEnabling Vela.Enabled rm
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

        CancelBuildResponse org repo buildNumber response ->
            case response of
                Ok ( _, build ) ->
                    let
                        canceledBuild =
                            "Build " ++ String.join "/" [ org, repo, buildNumber ]
                    in
                    ( { model
                        | repo =
                            -- update the build if necessary
                            case rm.build.build of
                                Success b ->
                                    if b.id == build.id then
                                        updateBuild (RemoteData.succeed build) rm

                                    else
                                        rm

                                _ ->
                                    rm
                      }
                    , Cmd.none
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (canceledBuild ++ " canceled.") Nothing)

                Err error ->
                    ( model, addError error )

        BuildsResponse org repo response ->
            case response of
                Ok ( meta, builds ) ->
                    ( { model
                        | repo =
                            rm
                                |> updateOrgRepo org repo
                                |> updateBuilds (RemoteData.succeed builds)
                                |> updateBuildsPager (Pagination.get meta.headers)
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = updateBuilds (toFailure error) rm }, addError error )

        OrgBuildsResponse org response ->
            case response of
                Ok ( meta, builds ) ->
                    ( { model
                        | repo =
                            rm
                                |> updateOrgRepo org ""
                                |> updateBuilds (RemoteData.succeed builds)
                                |> updateBuildsPager (Pagination.get meta.headers)
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = updateBuilds (toFailure error) rm }, addError error )

        DeploymentsResponse org repo response ->
            case response of
                Ok ( meta, deployments ) ->
                    ( { model
                        | repo =
                            rm
                                |> updateOrgRepo org repo
                                |> updateDeployments (RemoteData.succeed deployments)
                                |> updateDeploymentsPager (Pagination.get meta.headers)
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = updateDeployments (toFailure error) rm }, addError error )

        HooksResponse response ->
            case response of
                Ok ( meta, hooks ) ->
                    ( { model
                        | repo =
                            rm
                                |> updateHooks (RemoteData.succeed hooks)
                                |> updateHooksPager (Pagination.get meta.headers)
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | repo = updateHooks (toFailure error) rm }, addError error )

        RedeliverHookResponse org repo hookNumber response ->
            case response of
                Ok ( _, redeliverResponse ) ->
                    let
                        redeliveredHook =
                            "Hook " ++ String.join "/" [ org, repo, hookNumber ]
                    in
                    ( model
                    , getHooks model org repo Nothing Nothing
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (redeliveredHook ++ " redelivered.") Nothing)

                Err error ->
                    ( model, addError error )

        BuildResponse org repo response ->
            case response of
                Ok ( _, build ) ->
                    ( { model
                        | repo =
                            rm
                                |> updateOrgRepo org repo
                                |> updateBuild (RemoteData.succeed build)
                        , favicon = statusToFavicon build.status
                      }
                    , Interop.setFavicon <| Encode.string <| statusToFavicon build.status
                    )

                Err error ->
                    ( { model | repo = updateBuild (toFailure error) rm }, addError error )

        BuildAndPipelineResponse org repo expand response ->
            case response of
                Ok ( _, build ) ->
                    let
                        -- set pipeline fetch api call based on ?expand= query
                        getPipeline =
                            case expand of
                                Just e ->
                                    if e == "true" then
                                        expandPipelineConfig

                                    else
                                        getPipelineConfig

                                Nothing ->
                                    getPipelineConfig
                    in
                    ( { model
                        | repo =
                            rm
                                |> updateOrgRepo org repo
                                |> updateBuild (RemoteData.succeed build)
                        , favicon = statusToFavicon build.status
                      }
                    , Cmd.batch
                        [ Interop.setFavicon <| Encode.string <| statusToFavicon build.status
                        , getPipeline model org repo build.commit Nothing False
                        , getPipelineTemplates model org repo build.commit Nothing False
                        ]
                    )

                Err error ->
                    ( { model | repo = updateBuild (toFailure error) rm }, addError error )

        DeploymentResponse response ->
            case response of
                Ok ( _, deployment ) ->
                    let
                        dm =
                            model.deploymentModel

                        form =
                            initializeFormFromDeployment deployment.description deployment.payload deployment.ref deployment.target deployment.task

                        promoted =
                            { dm | form = form }
                    in
                    ( { model
                        | deploymentModel = promoted
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( model, addError error )

        StepsResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, steps ) ->
                    let
                        mergedSteps =
                            steps
                                |> List.sortBy .number
                                |> Pages.Build.Logs.merge logFocus refresh rm.build.steps.steps

                        updatedModel =
                            { model | repo = updateBuildSteps (RemoteData.succeed mergedSteps) rm }

                        cmd =
                            getBuildStepsLogs updatedModel org repo buildNumber mergedSteps logFocus refresh
                    in
                    ( updatedModel, cmd )

                Err error ->
                    ( model, addError error )

        StepLogResponse stepNumber logFocus refresh response ->
            case response of
                Ok ( _, incomingLog ) ->
                    let
                        following =
                            rm.build.steps.followingStep /= 0

                        onFollowedStep =
                            rm.build.steps.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                        ( steps, focusId ) =
                            if following && refresh && onFollowedStep then
                                ( rm.build.steps.steps
                                    |> RemoteData.unwrap rm.build.steps.steps
                                        (\s -> expandActive stepNumber s |> RemoteData.succeed)
                                , bottomTrackerFocusId "step" <| String.fromInt rm.build.steps.followingStep
                                )

                            else if not refresh then
                                ( rm.build.steps.steps, Util.extractFocusIdFromRange <| focusFragmentToFocusId "step" logFocus )

                            else
                                ( rm.build.steps.steps, "" )

                        cmd =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( updateStepLogs { model | repo = updateBuildSteps steps rm } incomingLog
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
                                |> Pages.Build.Logs.merge logFocus refresh rm.build.services.services

                        updatedModel =
                            { model | repo = updateBuildServices (RemoteData.succeed mergedServices) rm }

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
                            rm.build.services.followingService /= 0

                        onFollowedService =
                            rm.build.services.followingService == (Maybe.withDefault -1 <| String.toInt serviceNumber)

                        ( services, focusId ) =
                            if following && refresh && onFollowedService then
                                ( rm.build.services.services
                                    |> RemoteData.unwrap rm.build.services.services
                                        (\s -> expandActive serviceNumber s |> RemoteData.succeed)
                                , bottomTrackerFocusId "service" <| String.fromInt rm.build.services.followingService
                                )

                            else if not refresh then
                                ( rm.build.services.services, Util.extractFocusIdFromRange <| focusFragmentToFocusId "service" logFocus )

                            else
                                ( rm.build.services.services, "" )

                        cmd =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( updateServiceLogs { model | repo = updateBuildServices services rm } incomingLog
                    , cmd
                    )

                Err error ->
                    ( model, addError error )

        GetPipelineConfigResponse lineFocus refresh response ->
            case response of
                Ok ( _, config ) ->
                    let
                        focusId =
                            Util.extractFocusIdFromRange <| focusFragmentToFocusId "config" lineFocus

                        cmd =
                            if not refresh then
                                if not <| String.isEmpty focusId then
                                    Util.dispatch <| FocusOn <| focusId

                                else
                                    Cmd.none

                            else
                                Cmd.none
                    in
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed <| safeDecodePipelineData config pipeline.config, "" )
                                , expanded = False
                                , expanding = False
                            }
                      }
                    , cmd
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

        ExpandPipelineConfigResponse lineFocus refresh response ->
            case response of
                Ok ( _, config ) ->
                    let
                        focusId =
                            Util.extractFocusIdFromRange <| focusFragmentToFocusId "config" lineFocus

                        cmd =
                            if not refresh then
                                if not <| String.isEmpty focusId then
                                    Util.dispatch <| FocusOn <| focusId

                                else
                                    Cmd.none

                            else
                                Cmd.none
                    in
                    ( { model
                        | pipeline =
                            { pipeline
                                | config = ( RemoteData.succeed { rawData = config, decodedData = config }, "" )
                                , expanded = True
                                , expanding = False
                            }
                      }
                    , cmd
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

        GetPipelineTemplatesResponse lineFocus refresh response ->
            case response of
                Ok ( _, templates ) ->
                    ( { model
                        | templates = { data = RemoteData.succeed templates, error = "", show = model.templates.show }
                      }
                    , if not refresh then
                        Util.dispatch <| FocusOn <| Util.extractFocusIdFromRange <| focusFragmentToFocusId "config" lineFocus

                      else
                        Cmd.none
                    )

                Err error ->
                    ( { model | templates = { data = toFailure error, error = detailedErrorToString error, show = model.templates.show } }, addError error )

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

        AddDeploymentResponse response ->
            case response of
                Ok ( _, deployment ) ->
                    let
                        deploymentModel =
                            model.deploymentModel

                        updatedDeploymentModel =
                            Pages.Deployments.Update.reinitializeDeployment deploymentModel
                    in
                    ( { model | deploymentModel = updatedDeploymentModel }
                    , Cmd.none
                    )
                        |> addDeploymentResponseAlert deployment

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
                Ok _ ->
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

                FiveSecond ->
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
        SecretsUpdate m ->
            let
                ( newModel, action ) =
                    Pages.Secrets.Update.update model m
            in
            ( newModel
            , action
            )

        AddDeploymentUpdate m ->
            let
                ( newModel, action ) =
                    Pages.Deployments.Update.update model m
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

        FocusOn id ->
            ( model, Dom.focus id |> Task.attempt FocusResult )

        FocusResult result ->
            -- handle success or failure here
            case result of
                Err (Dom.NotFound _) ->
                    -- unable to find dom 'id'
                    ( model, Cmd.none )

                Ok _ ->
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

        SchedulesResponse org repo result ->
            ( model, Cmd.none )


{-| addDeploymentResponseAlert : takes deployment and produces Toasty alert for when adding a deployment
-}
addDeploymentResponseAlert :
    Deployment
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
    -> ( { m | toasties : Stack Alert }, Cmd Msg )
addDeploymentResponseAlert deployment =
    let
        msg =
            deployment.description ++ " submitted."
    in
    Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" msg Nothing)


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
        [ Interop.onThemeChange decodeOnThemeChange
        , onMouseDown "contextual-help" model ShowHideHelp
        , onMouseDown "identity" model ShowHideIdentity
        , onMouseDown "build-actions" model (ShowHideBuildMenu Nothing)
        , Browser.Events.onKeyDown (Decode.map OnKeyDown keyDecoder)
        , Browser.Events.onKeyUp (Decode.map OnKeyUp keyDecoder)
        , Browser.Events.onVisibilityChange VisibilityChanged
        , refreshSubscriptions model
        ]


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
                , every Util.fiveSecondsMillis <| Tick FiveSecond
                ]

            Hidden ->
                [ every Util.oneSecondMillis <| Tick OneSecondHidden
                , every Util.fiveSecondsMillis <| Tick (FiveSecondHidden <| refreshData model)
                ]


{-| refreshFavicon : takes page and restores the favicon to the default when not viewing the build page
-}
refreshFavicon : Page -> Favicon -> WebData Build -> ( Favicon, Cmd Msg )
refreshFavicon page currentFavicon build =
    let
        onBuild =
            case page of
                Pages.Build _ _ _ _ ->
                    True

                Pages.BuildServices _ _ _ _ ->
                    True

                Pages.BuildPipeline _ _ _ _ _ ->
                    True

                _ ->
                    False
    in
    if onBuild then
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

    else if currentFavicon /= defaultFavicon then
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
        Pages.OrgBuilds org maybePage maybePerPage maybeEvent ->
            getOrgBuilds model org maybePage maybePerPage maybeEvent

        Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            getBuilds model org repo maybePage maybePerPage maybeEvent

        Pages.RepositoryDeployments org repo maybePage maybePerPage ->
            getDeployments model org repo maybePage maybePerPage

        Pages.Build org repo buildNumber focusFragment ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildSteps model org repo buildNumber focusFragment
                , refreshStepLogs model org repo buildNumber model.repo.build.steps.steps Nothing
                ]

        Pages.BuildServices org repo buildNumber focusFragment ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildServices model org repo buildNumber focusFragment
                , refreshServiceLogs model org repo buildNumber model.repo.build.services.services Nothing
                ]

        Pages.BuildPipeline org repo buildNumber _ _ ->
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
                , getSharedSecrets model maybePage maybePerPage engine org "*"
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
        Pages.Build org repo buildNumber _ ->
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
    if shouldRefresh model.repo.build then
        refresh

    else
        Cmd.none


{-| refreshBuildSteps : takes model org repo and build number and refreshes the build steps based on step status
-}
refreshBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildSteps model org repo buildNumber focusFragment =
    if shouldRefresh model.repo.build then
        getAllBuildSteps model org repo buildNumber focusFragment True

    else
        Cmd.none


{-| refreshBuildServices : takes model org repo and build number and refreshes the build services based on service status
-}
refreshBuildServices : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildServices model org repo buildNumber focusFragment =
    if shouldRefresh model.repo.build then
        getAllBuildServices model org repo buildNumber focusFragment True

    else
        Cmd.none


{-| shouldRefresh : takes build and returns true if a refresh is required
-}
shouldRefresh : BuildModel -> Bool
shouldRefresh build =
    case build.build of
        Success bld ->
            -- build is incomplete
            (not <| isComplete bld.status)
                -- any steps or services are incomplete
                || (case build.steps.steps of
                        Success steps ->
                            List.any (\s -> not <| isComplete s.status) steps

                        NotAsked ->
                            True

                        -- do not refresh Failed or Loading steps
                        Failure _ ->
                            False

                        Loading ->
                            False
                   )
                || (case build.services.services of
                        Success services ->
                            List.any (\s -> not <| isComplete s.status) services

                        NotAsked ->
                            True

                        -- do not refresh Failed or Loading services
                        Failure _ ->
                            False

                        Loading ->
                            False
                   )

        NotAsked ->
            True

        -- do not refresh a Failed or Loading build
        Failure _ ->
            False

        Loading ->
            False


{-| refreshStepLogs : takes model org repo and build number and steps and refreshes the build step logs depending on their status
-}
refreshStepLogs : Model -> Org -> Repo -> BuildNumber -> WebData Steps -> FocusFragment -> Cmd Msg
refreshStepLogs model org repo buildNumber inSteps focusFragment =
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
    if shouldRefresh model.repo.build then
        refresh

    else
        Cmd.none


{-| refreshServiceLogs : takes model org repo and build number and services and refreshes the build service logs depending on their status
-}
refreshServiceLogs : Model -> Org -> Repo -> BuildNumber -> WebData Services -> FocusFragment -> Cmd Msg
refreshServiceLogs model org repo buildNumber inServices focusFragment =
    let
        servicesToRefresh =
            case inServices of
                Success s ->
                    -- Do not refresh logs for a service in success or failure state
                    List.filter (\service -> service.status /= Vela.Success && service.status /= Vela.Failure) s

                _ ->
                    []

        refresh =
            getBuildServicesLogs model org repo buildNumber servicesToRefresh focusFragment True
    in
    if shouldRefresh model.repo.build then
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

    else if List.length model.buildMenuOpen > 0 then
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
    { title = title ++ " - Vela"
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

        Pages.OrgRepositories org maybePage _ ->
            ( org ++ Util.pageToString maybePage
            , div []
                [ Pager.view model.repo.orgRepos.pager Pager.prevNextLabels GotoPage
                , lazy2 Pages.Organization.viewOrgRepos org model.repo.orgRepos
                , Pager.view model.repo.orgRepos.pager Pager.prevNextLabels GotoPage
                ]
            )

        Pages.Hooks org repo maybePage _ ->
            ( String.join "/" [ org, repo ] ++ " hooks" ++ Util.pageToString maybePage
            , div []
                [ Pager.view model.repo.hooks.pager Pager.defaultLabels GotoPage
                , lazy2 Pages.Hooks.view
                    { hooks = model.repo.hooks
                    , time = model.time
                    , org = model.repo.org
                    , repo = model.repo.name
                    }
                    RedeliverHook
                , Pager.view model.repo.hooks.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepoSettings org repo ->
            ( String.join "/" [ org, repo ] ++ " settings"
            , lazy5 Pages.RepoSettings.view model.repo.repo repoSettingsMsgs model.velaAPI (Url.toString model.entryURL) model.velaMaxBuildLimit
            )

        Pages.RepoSecrets engine org repo _ _ ->
            ( String.join "/" [ org, repo ] ++ " " ++ engine ++ " repo secrets"
            , div []
                [ Html.map SecretsUpdate <| lazy Pages.Secrets.View.viewRepoSecrets model
                , Html.map SecretsUpdate <| lazy3 Pages.Secrets.View.viewOrgSecrets model True False
                ]
            )

        Pages.OrgSecrets engine org maybePage _ ->
            ( String.join "/" [ org ] ++ " " ++ engine ++ " org secrets" ++ Util.pageToString maybePage
            , div []
                [ Html.map SecretsUpdate <| lazy3 Pages.Secrets.View.viewOrgSecrets model False True
                , Pager.view model.secretsModel.orgSecretsPager Pager.prevNextLabels GotoPage
                , Html.map SecretsUpdate <| lazy3 Pages.Secrets.View.viewSharedSecrets model True False
                ]
            )

        Pages.SharedSecrets engine org team _ _ ->
            ( String.join "/" [ org, team ] ++ " " ++ engine ++ " shared secrets"
            , div []
                [ Html.map SecretsUpdate <| lazy3 Pages.Secrets.View.viewSharedSecrets model False False
                , Pager.view model.secretsModel.sharedSecretsPager Pager.prevNextLabels GotoPage
                ]
            )

        Pages.AddOrgSecret engine _ ->
            ( "add " ++ engine ++ " org secret"
            , Html.map SecretsUpdate <| lazy Pages.Secrets.View.addSecret model
            )

        Pages.AddRepoSecret engine _ _ ->
            ( "add " ++ engine ++ " repo secret"
            , Html.map SecretsUpdate <| lazy Pages.Secrets.View.addSecret model
            )

        Pages.AddSharedSecret engine _ _ ->
            ( "add " ++ engine ++ " shared secret"
            , Html.map SecretsUpdate <| lazy Pages.Secrets.View.addSecret model
            )

        Pages.OrgSecret engine org name ->
            ( String.join "/" [ org, name ] ++ " update " ++ engine ++ " org secret"
            , Html.map SecretsUpdate <| lazy Pages.Secrets.View.editSecret model
            )

        Pages.RepoSecret engine org repo name ->
            ( String.join "/" [ org, repo, name ] ++ " update " ++ engine ++ " repo secret"
            , Html.map SecretsUpdate <| lazy Pages.Secrets.View.editSecret model
            )

        Pages.SharedSecret engine org team name ->
            ( String.join "/" [ org, team, name ] ++ " update " ++ engine ++ " shared secret"
            , Html.map SecretsUpdate <| lazy Pages.Secrets.View.editSecret model
            )

        Pages.AddDeployment org repo ->
            ( String.join "/" [ org, repo ] ++ " add deployment"
            , Html.map AddDeploymentUpdate <| lazy Pages.Deployments.View.addDeployment model
            )

        Pages.PromoteDeployment org repo buildNumber ->
            ( String.join "/" [ org, repo, buildNumber ] ++ " promote deployment"
            , Html.map AddDeploymentUpdate <| lazy Pages.Deployments.View.promoteDeployment model
            )

        Pages.RepositoryDeployments org repo maybePage _ ->
            ( String.join "/" [ org, repo ] ++ " deployments" ++ Util.pageToString maybePage
            , div []
                [ lazy3 Pages.Deployments.View.viewDeployments model.repo.deployments org repo
                , Pager.view model.repo.deployments.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.OrgBuilds org maybePage _ maybeEvent ->
            let
                repo =
                    ""

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
            ( org ++ " builds" ++ Util.pageToString maybePage
            , div []
                [ div [ class "build-bar" ]
                    [ viewBuildsFilter shouldRenderFilter org repo maybeEvent
                    , viewTimeToggle shouldRenderFilter model.repo.builds.showTimestamp
                    ]
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy7 Pages.Organization.viewBuilds model.repo.builds buildMsgs model.buildMenuOpen model.time model.zone org maybeEvent
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepositoryBuilds org repo maybePage _ maybeEvent ->
            let
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
            ( String.join "/" [ org, repo ] ++ " builds" ++ Util.pageToString maybePage
            , div []
                [ div [ class "build-bar" ]
                    [ viewBuildsFilter shouldRenderFilter org repo maybeEvent
                    , viewTimeToggle shouldRenderFilter model.repo.builds.showTimestamp
                    ]
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy8 Pages.Builds.view model.repo.builds buildMsgs model.buildMenuOpen model.time model.zone org repo maybeEvent
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepositoryBuildsPulls org repo maybePage _ ->
            let
                shouldRenderFilter : Bool
                shouldRenderFilter =
                    case ( model.repo.builds.builds, Just "pull_request" ) of
                        ( Success result, Nothing ) ->
                            not <| List.length result == 0

                        ( Success _, _ ) ->
                            True

                        ( Loading, _ ) ->
                            True

                        _ ->
                            False
            in
            ( String.join "/" [ org, repo ] ++ " builds" ++ Util.pageToString maybePage
            , div []
                [ div [ class "build-bar" ]
                    [ viewBuildsFilter shouldRenderFilter org repo (Just "pull_request")
                    , viewTimeToggle shouldRenderFilter model.repo.builds.showTimestamp
                    ]
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy8 Pages.Builds.view model.repo.builds buildMsgs model.buildMenuOpen model.time model.zone org repo (Just "pull_request")
                , Pager.view model.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.Build org repo buildNumber _ ->
            ( "Build #" ++ buildNumber ++ " - " ++ String.join "/" [ org, repo ]
            , Pages.Build.View.viewBuild
                model
                buildMsgs
                org
                repo
                buildNumber
            )

        Pages.BuildServices org repo buildNumber _ ->
            ( "Build #" ++ buildNumber ++ " - " ++ String.join "/" [ org, repo ]
            , Pages.Build.View.viewBuildServices
                model
                buildMsgs
                org
                repo
                buildNumber
            )

        Pages.BuildPipeline org repo buildNumber _ _ ->
            ( "Pipeline " ++ String.join "/" [ org, repo ]
            , Pages.Pipeline.View.viewPipeline
                model
                pipelineMsgs
                |> Pages.Build.View.wrapWithBuildPreview
                    model
                    buildMsgs
                    org
                    repo
                    buildNumber
            )

        Pages.Settings ->
            ( "Settings"
            , Pages.Settings.view model.session model.time (Pages.Settings.Msgs Copy)
            )

        Pages.Login ->
            ( "Login"
            , viewLogin
            )

        Pages.NotFound ->
            ( "404"
            , h1 [] [ text "Not Found" ]
            )

        Pages.Schedule org repo scheduleID ->
            ( "404"
            , h1 [] [ text "Not Found" ]
            )

        Pages.Schedules org repo _ _ ->
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


viewTimeToggle : Bool -> Bool -> Html Msg
viewTimeToggle shouldRender showTimestamp =
    if shouldRender then
        div [ class "form-controls", class "-stack", class "time-toggle" ]
            [ div [ class "form-control" ]
                [ input [ type_ "checkbox", checked showTimestamp, onClick ShowHideFullTimestamp, id "checkbox-time-toggle", Util.testAttribute "time-toggle" ] []
                , label [ class "form-label", for "checkbox-time-toggle" ] [ text "show full timestamps" ]
                ]
            ]

    else
        text ""


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
        , p [] [ text "You will be taken to GitHub to authenticate." ]
        ]


viewHeader : Session -> { feedbackLink : String, docsLink : String, theme : Theme, help : Help.Commands.Model Msg, showId : Bool } -> Html Msg
viewHeader session { feedbackLink, docsLink, theme, help, showId } =
    let
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
            , case session of
                Authenticated auth ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (ShowHideIdentity Nothing), Util.testAttribute "identity-summary" ]
                            [ text auth.userName
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , ul [ class "identity-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                            [ li [ class "identity-menu-item" ]
                                [ a [ Routes.href Routes.Settings, Util.testAttribute "settings-link", attribute "role" "menuitem" ] [ text "Settings" ] ]
                            , li [ class "identity-menu-item" ]
                                [ a [ Routes.href Routes.Logout, Util.testAttribute "logout-link", attribute "role" "menuitem" ] [ text "Logout" ] ]
                            ]
                        ]

                Unauthenticated ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (ShowHideIdentity Nothing), Util.testAttribute "identity-summary" ] [ text "Vela" ] ]
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
    , orgRepos = helpArg model.repo.orgRepos.orgRepos
    , builds = helpArg model.repo.builds.builds
    , deployments = helpArg model.repo.deployments.deployments
    , build = helpArg model.repo.build.build
    , repo = helpArg model.repo.repo
    , hooks = helpArg model.repo.hooks.hooks
    , secrets = helpArg model.secretsModel.repoSecrets
    , show = model.showHelp
    , toggle = ShowHideHelp
    , copy = Copy
    , noOp = NoOp
    , page = model.page

    -- TODO: use env flag velaDocsURL
    -- , velaDocsURL = model.velaDocsURL
    , velaDocsURL = "https://go-vela.github.io/docs"
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


setNewPage : Routes.Route -> Model -> ( Model, Cmd Msg )
setNewPage route model =
    case ( route, model.session ) of
        -- Logged in and on auth flow pages - what are you doing here?
        ( Routes.Login, Authenticated _ ) ->
            ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Overview )

        ( Routes.Authenticate _, Authenticated _ ) ->
            ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Overview )

        -- "Not logged in" (yet) and on auth flow pages, continue on..
        ( Routes.Authenticate { code, state }, Unauthenticated ) ->
            ( { model | page = Pages.Login }
            , Api.try TokenResponse <| Api.getInitialToken model <| AuthParams code state
            )

        -- On the login page but not logged in.. good place to be
        ( Routes.Login, Unauthenticated ) ->
            ( { model | page = Pages.Login }, Cmd.none )

        -- "Normal" page handling below
        ( Routes.Overview, Authenticated _ ) ->
            loadOverviewPage model

        ( Routes.SourceRepositories, Authenticated _ ) ->
            loadSourceReposPage model

        ( Routes.OrgRepositories org maybePage maybePerPage, Authenticated _ ) ->
            loadOrgReposPage model org maybePage maybePerPage

        ( Routes.Hooks org repo maybePage maybePerPage, Authenticated _ ) ->
            loadHooksPage model org repo maybePage maybePerPage

        ( Routes.RepoSettings org repo, Authenticated _ ) ->
            loadRepoSettingsPage model org repo

        ( Routes.OrgSecrets engine org maybePage maybePerPage, Authenticated _ ) ->
            loadOrgSecretsPage model maybePage maybePerPage engine org

        ( Routes.RepoSecrets engine org repo maybePage maybePerPage, Authenticated _ ) ->
            loadRepoSecretsPage model maybePage maybePerPage engine org repo

        ( Routes.SharedSecrets engine org team maybePage maybePerPage, Authenticated _ ) ->
            loadSharedSecretsPage model maybePage maybePerPage engine org team

        ( Routes.AddOrgSecret engine org, Authenticated _ ) ->
            loadAddOrgSecretPage model engine org

        ( Routes.AddRepoSecret engine org repo, Authenticated _ ) ->
            loadAddRepoSecretPage model engine org repo

        ( Routes.AddSharedSecret engine org team, Authenticated _ ) ->
            loadAddSharedSecretPage model engine org team

        ( Routes.OrgSecret engine org name, Authenticated _ ) ->
            loadUpdateOrgSecretPage model engine org name

        ( Routes.RepoSecret engine org repo name, Authenticated _ ) ->
            loadUpdateRepoSecretPage model engine org repo name

        ( Routes.SharedSecret engine org team name, Authenticated _ ) ->
            loadUpdateSharedSecretPage model engine org team name

        ( Routes.OrgBuilds org maybePage maybePerPage maybeEvent, Authenticated _ ) ->
            loadOrgBuildsPage model org maybePage maybePerPage maybeEvent

        ( Routes.RepositoryBuilds org repo maybePage maybePerPage maybeEvent, Authenticated _ ) ->
            loadRepoBuildsPage model org repo maybePage maybePerPage maybeEvent

        ( Routes.RepositoryBuildsPulls org repo maybePage maybePerPage, Authenticated _ ) ->
            loadRepoBuildsPullsPage model org repo maybePage maybePerPage

        ( Routes.RepositoryDeployments org repo maybePage maybePerPage, Authenticated _ ) ->
            loadRepoDeploymentsPage model org repo maybePage maybePerPage

        ( Routes.Build org repo buildNumber lineFocus, Authenticated _ ) ->
            loadBuildPage model org repo buildNumber lineFocus

        ( Routes.AddDeploymentRoute org repo, Authenticated _ ) ->
            loadAddDeploymentPage model org repo

        ( Routes.PromoteDeployment org repo deploymentNumber, Authenticated _ ) ->
            loadPromoteDeploymentPage model org repo deploymentNumber

        ( Routes.BuildServices org repo buildNumber lineFocus, Authenticated _ ) ->
            loadBuildServicesPage model org repo buildNumber lineFocus

        ( Routes.BuildPipeline org repo buildNumber expand lineFocus, Authenticated _ ) ->
            loadBuildPipelinePage model org repo buildNumber expand lineFocus

        ( Routes.AddSchedule _ _, Authenticated _ ) ->
            ( { model | page = Pages.NotFound }, Cmd.none )

        ( Routes.Schedules org repo maybePage maybePerPage, Authenticated _ ) ->
            loadRepoSchedulesPage model org repo maybePage maybePerPage

        ( Routes.Schedule _ _ _, Authenticated _ ) ->
            ( { model | page = Pages.NotFound }, Cmd.none )


        ( Routes.Settings, Authenticated _ ) ->
            ( { model | page = Pages.Settings, showIdentity = False }, Cmd.none )

        ( Routes.Logout, Authenticated _ ) ->
            ( model, getLogout model )

        -- Not found page handling
        ( Routes.NotFound, Authenticated _ ) ->
            ( { model | page = Pages.NotFound }, Cmd.none )

        {--Hitting any page and not being logged in will load the login page content

           Note: we're not using .pushUrl to retain ability for user to use
           browser's back button
        --}
        ( _, Unauthenticated ) ->
            ( { model | page = Pages.Login }
            , Interop.setRedirect <| Encode.string <| Url.toString model.entryURL
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


loadOrgReposPage : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadOrgReposPage model org maybePage maybePerPage =
    case model.repo.orgRepos.orgRepos of
        NotAsked ->
            ( { model | page = Pages.OrgRepositories org maybePage maybePerPage }
            , Api.try OrgRepositoriesResponse <| Api.getOrgRepositories model maybePage maybePerPage org
            )

        Failure _ ->
            ( { model | page = Pages.OrgRepositories org maybePage maybePerPage }
            , Api.try OrgRepositoriesResponse <| Api.getOrgRepositories model maybePage maybePerPage org
            )

        _ ->
            ( { model | page = Pages.OrgRepositories org maybePage maybePerPage }
            , Cmd.batch
                [ getCurrentUser model
                , Api.try OrgRepositoriesResponse <| Api.getOrgRepositories model maybePage maybePerPage org
                ]
            )


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


{-| loadOrgSubPage : takes model org and page destination

    updates the model based on app initialization state and loads org page resources

-}
loadOrgSubPage : Model -> Org -> Page -> ( Model, Cmd Msg )
loadOrgSubPage model org toPage =
    let
        rm =
            model.repo

        builds =
            rm.builds

        secretsModel =
            model.secretsModel

        fetchSecrets : Org -> Cmd Msg
        fetchSecrets o =
            Cmd.batch [ getAllOrgSecrets model "native" o ]

        -- update model and dispatch cmds depending on initialization state and destination
        ( loadModel, loadCmd ) =
            -- repo data has not been initialized or org/repo has changed
            if not rm.initialized || resourceChanged ( rm.org, rm.name, "" ) ( org, "", "" ) then
                ( { model
                    | secretsModel =
                        { secretsModel
                            | repoSecrets = Loading
                            , orgSecrets = Loading
                            , sharedSecrets = Loading
                            , org = org
                            , repo = ""
                            , engine = "native"
                            , type_ = Vela.RepoSecret
                        }
                    , repo =
                        rm
                            |> updateOrgRepo org ""
                            |> updateRepoInitialized True
                            |> updateRepo Loading
                            |> updateBuilds Loading
                            |> updateBuildSteps NotAsked
                            -- update builds pagination
                            |> (\rm_ ->
                                    case toPage of
                                        Pages.OrgRepositories _ maybePage maybePerPage ->
                                            rm_
                                                |> updateOrgReposPage maybePage
                                                |> updateOrgReposPerPage maybePerPage

                                        Pages.OrgBuilds _ maybePage maybePerPage maybeEvent ->
                                            rm_
                                                |> updateBuildsPage maybePage
                                                |> updateBuildsPerPage maybePerPage
                                                |> updateBuildsEvent maybeEvent

                                        _ ->
                                            rm_
                                                |> updateBuildsPage Nothing
                                                |> updateBuildsPerPage Nothing
                                                |> updateBuildsEvent Nothing
                                                |> updateOrgReposPage Nothing
                                                |> updateOrgReposPerPage Nothing
                               )
                  }
                , Cmd.batch
                    [ getCurrentUser model
                    , case toPage of
                        Pages.OrgRepositories o maybePage maybePerPage ->
                            getOrgRepos model o maybePage maybePerPage

                        Pages.OrgBuilds o maybePage maybePerPage maybeEvent ->
                            getOrgBuilds model o maybePage maybePerPage maybeEvent

                        _ ->
                            getOrgBuilds model org Nothing Nothing Nothing
                    ]
                )

            else
                -- repo data has already been initialized and org/repo has not changed, aka tab switch
                case toPage of
                    Pages.OrgBuilds o maybePage maybePerPage maybeEvent ->
                        ( { model
                            | repo =
                                { rm
                                    | builds =
                                        { builds | maybePage = maybePage, maybePerPage = maybePerPage, maybeEvent = maybeEvent }
                                }
                          }
                        , getOrgBuilds model o maybePage maybePerPage maybeEvent
                        )

                    Pages.OrgSecrets _ o _ _ ->
                        ( model, fetchSecrets o )

                    _ ->
                        ( model, Cmd.none )
    in
    ( { loadModel | page = toPage }, loadCmd )


{-| loadRepoSubPage : takes model org repo and page destination

    updates the model based on app initialization state and loads repo page resources

-}
loadRepoSubPage : Model -> Org -> Repo -> Page -> ( Model, Cmd Msg )
loadRepoSubPage model org repo toPage =
    let
        rm =
            model.repo

        builds =
            rm.builds

        secretsModel =
            model.secretsModel

        dm =
            model.deploymentModel

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
                            , sharedSecrets = Loading
                            , org = org
                            , repo = repo
                            , engine = "native"
                            , type_ = Vela.RepoSecret
                        }
                    , deploymentModel =
                        let
                            form =
                                case toPage of
                                    Pages.AddDeployment _ _ ->
                                        Pages.Deployments.Update.initializeFormFromDeployment "" Nothing "" "" ""

                                    _ ->
                                        dm.form
                        in
                        { dm
                            | org = org
                            , repo = repo
                            , repo_settings = rm.repo
                            , form = form
                        }
                    , repo =
                        rm
                            |> updateOrgRepo org repo
                            |> updateRepoInitialized True
                            |> updateRepo Loading
                            |> updateBuilds Loading
                            |> updateBuildSteps NotAsked
                            |> updateDeployments Loading
                            -- update builds pagination
                            |> (\rm_ ->
                                    case toPage of
                                        Pages.RepositoryBuilds _ _ maybePage maybePerPage maybeEvent ->
                                            rm_
                                                |> updateBuildsPage maybePage
                                                |> updateBuildsPerPage maybePerPage
                                                |> updateBuildsEvent maybeEvent

                                        _ ->
                                            rm_
                                                |> updateBuildsPage Nothing
                                                |> updateBuildsPerPage Nothing
                                                |> updateBuildsEvent Nothing
                               )
                            -- update deployments pagination
                            |> (\rm_ ->
                                    case toPage of
                                        Pages.RepositoryDeployments _ _ maybePage maybePerPage ->
                                            rm_
                                                |> updateDeploymentsPage maybePage
                                                |> updateDeploymentsPerPage maybePerPage

                                        _ ->
                                            rm_
                                                |> updateDeploymentsPage Nothing
                                                |> updateDeploymentsPerPage Nothing
                               )
                            -- update hooks pagination
                            |> (\rm_ ->
                                    case toPage of
                                        Pages.Hooks _ _ maybePage maybePerPage ->
                                            rm_
                                                |> updateHooksPage maybePage
                                                |> updateHooksPerPage maybePerPage

                                        _ ->
                                            rm_
                                                |> updateHooksPage Nothing
                                                |> updateHooksPerPage Nothing
                               )
                  }
                , Cmd.batch
                    [ getCurrentUser model
                    , getRepo model org repo
                    , case toPage of
                        Pages.RepositoryBuilds o r maybePage maybePerPage maybeEvent ->
                            getBuilds model o r maybePage maybePerPage maybeEvent

                        Pages.RepositoryBuildsPulls o r maybePage maybePerPage ->
                            getBuilds model o r maybePage maybePerPage (Just "pull_request")

                        _ ->
                            getBuilds model org repo Nothing Nothing Nothing
                    , case toPage of
                        Pages.RepositoryDeployments o r maybePage maybePerPage ->
                            getDeployments model o r maybePage maybePerPage

                        _ ->
                            Cmd.none
                    , case toPage of
                        Pages.Hooks o r maybePage maybePerPage ->
                            getHooks model o r maybePage maybePerPage

                        _ ->
                            getHooks model org repo Nothing Nothing
                    , case toPage of
                        Pages.RepoSecrets _ o r _ _ ->
                            fetchSecrets o r

                        _ ->
                            Cmd.none
                    , case toPage of
                        Pages.Schedules o r _ _ ->
                            fetchSecrets o r

                        _ ->
                            Cmd.none
                    , case toPage of
                        Pages.PromoteDeployment _ _ deploymentNumber ->
                            getDeployment model org repo deploymentNumber

                        _ ->
                            Cmd.none
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

                    Pages.RepoSecrets _ o r _ _ ->
                        ( model, fetchSecrets o r )

                    Pages.Hooks o r maybePage maybePerPage ->
                        ( { model
                            | repo =
                                rm
                                    |> updateHooksPage maybePage
                                    |> updateHooksPerPage maybePerPage
                          }
                        , getHooks model o r maybePage maybePerPage
                        )

                    Pages.RepoSettings o r ->
                        ( model, getRepo model o r )

                    Pages.PromoteDeployment o r deploymentNumber ->
                        ( model, getDeployment model o r deploymentNumber )

                    -- page is not a repo subpage
                    _ ->
                        ( model, Cmd.none )
    in
    ( { loadModel | page = toPage }, loadCmd )


{-| loadOrgBuildsPage : takes model org and repo and loads the appropriate builds.

    loadOrgBuildsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadOrgBuildsPage : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> ( Model, Cmd Msg )
loadOrgBuildsPage model org maybePage maybePerPage maybeEvent =
    loadOrgSubPage model org <| Pages.OrgBuilds org maybePage maybePerPage maybeEvent


{-| loadRepoBuildsPage : takes model org and repo and loads the appropriate builds.

    loadRepoBuildsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadRepoBuildsPage : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> ( Model, Cmd Msg )
loadRepoBuildsPage model org repo maybePage maybePerPage maybeEvent =
    loadRepoSubPage model org repo <| Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent


{-| loadRepoBuildsPullsPage : takes model org and repo and loads the appropriate builds for the pull\_request event only.

    loadRepoBuildsPullsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadRepoBuildsPullsPage : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadRepoBuildsPullsPage model org repo maybePage maybePerPage =
    loadRepoSubPage model org repo <| Pages.RepositoryBuildsPulls org repo maybePage maybePerPage


loadRepoDeploymentsPage : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadRepoDeploymentsPage model org repo maybePage maybePerPage =
    loadRepoSubPage model org repo <| Pages.RepositoryDeployments org repo maybePage maybePerPage


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

{-| loadRepoSchedulesPage : takes model org and repo and loads the page for managing repo secrets
-}
loadRepoSchedulesPage :
    Model
    -> Org
    -> Repo
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> ( Model, Cmd Msg )
loadRepoSchedulesPage model org repo maybePage maybePerPage =
    loadRepoSubPage model org repo <| Pages.Schedules org repo maybePage maybePerPage


{-| loadAddDeploymentPage : takes model org and repo and loads the page for managing deployments
-}
loadAddDeploymentPage :
    Model
    -> Org
    -> Repo
    -> ( Model, Cmd Msg )
loadAddDeploymentPage model org repo =
    loadRepoSubPage model org repo <| Pages.AddDeployment org repo


{-| loadPromoteDeploymentPage : takes model org and repo and loads the page for managing deployments
-}
loadPromoteDeploymentPage :
    Model
    -> Org
    -> Repo
    -> BuildNumber
    -> ( Model, Cmd Msg )
loadPromoteDeploymentPage model org repo buildNumber =
    loadRepoSubPage model org repo <| Pages.PromoteDeployment org repo buildNumber


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
                | sharedSecrets = Loading
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
loadBuildPage : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> ( Model, Cmd Msg )
loadBuildPage model org repo buildNumber lineFocus =
    let
        -- get resource transition information
        sameBuild =
            isSameBuild ( org, repo, buildNumber ) model.page

        sameResource =
            case model.page of
                Pages.Build _ _ _ _ ->
                    True

                _ ->
                    False

        -- if build has changed, set build fields in the model
        m =
            if not sameBuild then
                setBuild org repo buildNumber sameResource model

            else
                model

        rm =
            m.repo
    in
    -- load page depending on build change
    ( { m
        | page = Pages.Build org repo buildNumber lineFocus

        -- set repo fields
        , repo =
            rm
                -- update steps using line focus
                |> updateBuildSteps
                    (RemoteData.unwrap Loading
                        (\steps_ ->
                            RemoteData.succeed <| focusAndClear steps_ lineFocus
                        )
                        rm.build.steps.steps
                    )
                -- update line focus in the model
                |> updateBuildStepsFocusFragment (Maybe.map (\l -> "#" ++ l) lineFocus)
                -- reset following service
                |> updateBuildServicesFollowing 0
      }
      -- do not load resources if transition is auto refresh, line focus, etc
    , if sameBuild && sameResource then
        Cmd.none

      else
        Cmd.batch <|
            [ getBuilds model org repo Nothing Nothing Nothing
            , getBuild model org repo buildNumber
            , getAllBuildSteps model org repo buildNumber lineFocus sameBuild
            ]
    )


{-| loadBuildServicesPage : takes model org, repo, and build number and loads the appropriate build services.
-}
loadBuildServicesPage : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> ( Model, Cmd Msg )
loadBuildServicesPage model org repo buildNumber lineFocus =
    let
        -- get resource transition information
        sameBuild =
            isSameBuild ( org, repo, buildNumber ) model.page

        sameResource =
            case model.page of
                Pages.BuildServices _ _ _ _ ->
                    True

                _ ->
                    False

        -- if build has changed, set build fields in the model
        m =
            if not sameBuild then
                setBuild org repo buildNumber sameResource model

            else
                model

        rm =
            m.repo
    in
    ( { m
        | page = Pages.BuildServices org repo buildNumber lineFocus

        -- set repo fields
        , repo =
            rm
                -- update services using line focus
                |> updateBuildServices
                    (RemoteData.unwrap Loading
                        (\services ->
                            RemoteData.succeed <| focusAndClear services lineFocus
                        )
                        rm.build.services.services
                    )
                -- update line focus in the model
                |> updateBuildServicesFocusFragment (Maybe.map (\l -> "#" ++ l) lineFocus)
                -- reset following step
                |> updateBuildStepsFollowing 0
      }
      -- do not load resources if transition is auto refresh, line focus, etc
    , if sameBuild && sameResource then
        Cmd.none

      else
        Cmd.batch <|
            [ getBuilds model org repo Nothing Nothing Nothing
            , getBuild model org repo buildNumber
            , getAllBuildServices model org repo buildNumber lineFocus sameBuild
            ]
    )


{-| loadBuildPipelinePage : takes model org, repo, and ref and loads the appropriate pipeline configuration resources.
-}
loadBuildPipelinePage : Model -> Org -> Repo -> BuildNumber -> Maybe ExpandTemplatesQuery -> Maybe Fragment -> ( Model, Cmd Msg )
loadBuildPipelinePage model org repo buildNumber expand lineFocus =
    let
        -- get resource transition information
        sameBuild =
            isSameBuild ( org, repo, buildNumber ) model.page

        sameResource =
            case model.page of
                Pages.BuildPipeline _ _ _ _ _ ->
                    True

                _ ->
                    False

        -- if build has changed, set build fields in the model
        m =
            if not sameBuild then
                setBuild org repo buildNumber sameResource model

            else
                model

        -- set pipeline fetch api call based on ?expand= query
        getPipeline =
            case expand of
                Just e ->
                    if e == "true" then
                        expandPipelineConfig

                    else
                        getPipelineConfig

                Nothing ->
                    getPipelineConfig

        -- parse line range from line focus
        parsed =
            parseFocusFragment lineFocus

        pipeline =
            model.pipeline
    in
    ( { m
        | page = Pages.BuildPipeline org repo buildNumber expand lineFocus
        , pipeline =
            pipeline
                |> updateBuildPipelineConfig
                    (if sameBuild then
                        case pipeline.config of
                            ( Success _, _ ) ->
                                pipeline.config

                            _ ->
                                ( Loading, "" )

                     else
                        ( Loading, "" )
                    )
                |> updateBuildPipelineExpand expand
                |> updateBuildPipelineLineFocus ( parsed.lineA, parsed.lineB )
                |> updateBuildPipelineFocusFragment (Maybe.map (\l -> "#" ++ l) lineFocus)

        -- reset templates if build has changed
        , templates =
            if sameBuild then
                model.templates

            else
                { data = Loading, error = "", show = True }
      }
    , Cmd.batch <|
        -- do not load resources if transition is auto refresh, line focus, etc
        if sameBuild && sameResource then
            []

        else if sameBuild then
            -- same build, most likely a tab switch
            case model.repo.build.build of
                Success build ->
                    -- build exists, chained request not needed
                    [ getBuilds model org repo Nothing Nothing Nothing
                    , getBuild model org repo buildNumber
                    , getPipeline model org repo build.commit lineFocus False
                    , getPipelineTemplates model org repo build.commit lineFocus False
                    ]

                _ ->
                    -- no build present, use chained request
                    [ getBuilds model org repo Nothing Nothing Nothing
                    , getBuildAndPipeline model org repo buildNumber expand
                    ]

        else
            -- different build, use chained request
            [ getBuilds model org repo Nothing Nothing Nothing
            , getBuildAndPipeline model org repo buildNumber expand
            ]
    )


{-| isSameBuild : takes build identifier and current page and returns true if the build has not changed
-}
isSameBuild : RepoResourceIdentifier -> Page -> Bool
isSameBuild id currentPage =
    case currentPage of
        Pages.Build o r b _ ->
            not <| resourceChanged id ( o, r, b )

        Pages.BuildServices o r b _ ->
            not <| resourceChanged id ( o, r, b )

        Pages.BuildPipeline o r b _ _ ->
            not <| resourceChanged id ( o, r, b )

        _ ->
            False


{-| setBuild : takes new build information and sets the appropriate model state
-}
setBuild : Org -> Repo -> BuildNumber -> Bool -> Model -> Model
setBuild org repo buildNumber soft model =
    let
        rm =
            model.repo

        pipeline =
            model.pipeline
    in
    { model
        | pipeline =
            { pipeline
                | focusFragment = Nothing
                , config = ( NotAsked, "" )
                , expand = Nothing
                , expanding = False
                , expanded = False
            }
        , templates = { data = NotAsked, error = "", show = True }
        , repo =
            rm
                |> updateBuild
                    (if soft then
                        model.repo.build.build

                     else
                        Loading
                    )
                |> updateOrgRepo org repo
                |> updateBuildNumber buildNumber
                |> updateBuildSteps NotAsked
                |> updateBuildStepsFollowing 0
                |> updateBuildStepsLogs []
                |> updateBuildStepsFocusFragment Nothing
                |> updateBuildServices NotAsked
                |> updateBuildServicesFollowing 0
                |> updateBuildServicesLogs []
                |> updateBuildServicesFocusFragment Nothing
    }


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


{-| logIds : extracts Ids from list of logs and returns List Int
-}
logIds : Logs -> List Int
logIds logs =
    List.map (\log -> log.id) <| Util.successful logs


{-| updateStepLogs : takes model and incoming log and updates the list of step logs if necessary
-}
updateStepLogs : Model -> Log -> Model
updateStepLogs model incomingLog =
    let
        rm =
            model.repo

        build =
            rm.build

        logs =
            build.steps.logs

        logExists =
            List.member incomingLog.id <| logIds logs
    in
    if logExists then
        { model | repo = updateBuildStepsLogs (updateLog incomingLog logs model.velaLogBytesLimit) rm }

    else if incomingLog.id /= 0 then
        { model | repo = updateBuildStepsLogs (addLog incomingLog logs model.velaLogBytesLimit) rm }

    else
        model


{-| updateServiceLogs : takes model and incoming log and updates the list of service logs if necessary
-}
updateServiceLogs : Model -> Log -> Model
updateServiceLogs model incomingLog =
    let
        rm =
            model.repo

        build =
            rm.build

        logs =
            build.services.logs

        logExists =
            List.member incomingLog.id <| logIds logs
    in
    if logExists then
        { model | repo = updateBuildServicesLogs (updateLog incomingLog logs model.velaLogBytesLimit) rm }

    else if incomingLog.id /= 0 then
        { model | repo = updateBuildServicesLogs (addLog incomingLog logs model.velaLogBytesLimit) rm }

    else
        model


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

                -- only show error toasty for 500 error
                showError =
                    case error of
                        Http.Detailed.BadStatus meta _ ->
                            case meta.statusCode of
                                500 ->
                                    addError error

                                _ ->
                                    Cmd.none

                        _ ->
                            Cmd.none

                sm =
                    case type_ of
                        Vela.RepoSecret ->
                            { secretsModel | repoSecrets = e }

                        Vela.OrgSecret ->
                            { secretsModel | orgSecrets = e }

                        Vela.SharedSecret ->
                            { secretsModel | sharedSecrets = e }
            in
            ( { model | secretsModel = sm }, showError )


{-| homeMsgs : prepares the input record required for the Home page to route Msgs back to Main.elm
-}
homeMsgs : Pages.Home.Msgs Msg
homeMsgs =
    Pages.Home.Msgs ToggleFavorite SearchFavorites


{-| navMsgs : prepares the input record required for the nav component to route Msgs back to Main.elm
-}
navMsgs : Nav.Msgs Msg
navMsgs =
    Nav.Msgs FetchSourceRepositories ToggleFavorite RefreshSettings RefreshHooks RefreshSecrets RestartBuild CancelBuild


{-| sourceReposMsgs : prepares the input record required for the SourceRepos page to route Msgs back to Main.elm
-}
sourceReposMsgs : Pages.SourceRepos.Msgs Msg
sourceReposMsgs =
    Pages.SourceRepos.Msgs SearchSourceRepos EnableRepo EnableRepos ToggleFavorite


{-| repoSettingsMsgs : prepares the input record required for the Settings page to route Msgs back to Main.elm
-}
repoSettingsMsgs : Pages.RepoSettings.Msgs Msg
repoSettingsMsgs =
    Pages.RepoSettings.Msgs UpdateRepoEvent UpdateRepoAccess UpdateRepoLimit ChangeRepoLimit UpdateRepoTimeout ChangeRepoTimeout UpdateRepoCounter ChangeRepoCounter DisableRepo EnableRepo Copy ChownRepo RepairRepo UpdateRepoPipelineType


{-| buildMsgs : prepares the input record required for the Build pages to route Msgs back to Main.elm
-}
buildMsgs : Pages.Build.Model.Msgs Msg
buildMsgs =
    { collapseAllSteps = CollapseAllSteps
    , expandAllSteps = ExpandAllSteps
    , expandStep = ExpandStep
    , collapseAllServices = CollapseAllServices
    , expandAllServices = ExpandAllServices
    , expandService = ExpandService
    , restartBuild = RestartBuild
    , cancelBuild = CancelBuild
    , toggle = ShowHideBuildMenu
    , logsMsgs =
        { focusLine = PushUrl
        , download = DownloadFile "text" Util.base64Decode
        , focusOn = FocusOn
        , followStep = FollowStep
        , followService = FollowService
        }
    }


{-| pipelineMsgs : prepares the input record required for the Pipeline pages to route Msgs back to Main.elm
-}
pipelineMsgs : Pages.Pipeline.Model.Msgs Msg
pipelineMsgs =
    { get = GetPipelineConfig
    , expand = ExpandPipelineConfig
    , focusLineNumber = FocusPipelineConfigLineNumber
    , showHideTemplates = ShowHideTemplates
    , download = DownloadFile "text" identity
    }


initSecretsModel : Pages.Secrets.Model.Model Msg
initSecretsModel =
    Pages.Secrets.Update.init Copy SecretResponse RepoSecretsResponse OrgSecretsResponse SharedSecretsResponse AddSecretResponse UpdateSecretResponse DeleteSecretResponse


initDeploymentsModel : Pages.Deployments.Model.Model Msg
initDeploymentsModel =
    Pages.Deployments.Update.init AddDeploymentResponse



-- API HELPERS


{-| getToken attempts to retrieve a new access token
-}
getToken : Model -> Cmd Msg
getToken model =
    Api.try TokenResponse <| Api.getToken model


getLogout : Model -> Cmd Msg
getLogout model =
    Api.try LogoutResponse <| Api.getLogout model


getCurrentUser : Model -> Cmd Msg
getCurrentUser model =
    case model.user of
        NotAsked ->
            Api.try CurrentUserResponse <| Api.getCurrentUser model

        _ ->
            Cmd.none


getHooks : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getHooks model org repo maybePage maybePerPage =
    Api.try HooksResponse <| Api.getHooks model maybePage maybePerPage org repo


redeliverHook : Model -> Org -> Repo -> HookNumber -> Cmd Msg
redeliverHook model org repo hookNumber =
    Api.try (RedeliverHookResponse org repo hookNumber) <| Api.redeliverHook model org repo hookNumber


getRepo : Model -> Org -> Repo -> Cmd Msg
getRepo model org repo =
    Api.try RepoResponse <| Api.getRepo model org repo


getOrgRepos : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getOrgRepos model org maybePage maybePerPage =
    Api.try OrgRepositoriesResponse <| Api.getOrgRepositories model maybePage maybePerPage org


getOrgBuilds : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Cmd Msg
getOrgBuilds model org maybePage maybePerPage maybeEvent =
    Api.try (OrgBuildsResponse org) <| Api.getOrgBuilds model maybePage maybePerPage maybeEvent org


getBuilds : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Cmd Msg
getBuilds model org repo maybePage maybePerPage maybeEvent =
    Api.try (BuildsResponse org repo) <| Api.getBuilds model maybePage maybePerPage maybeEvent org repo

getSchedules : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Cmd Msg
getSchedules model org repo maybePage maybePerPage maybeEvent =
    Api.try (SchedulesResponse org repo) <| Api.getSchedules model maybePage maybePerPage maybeEvent org repo

getBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.try (BuildResponse org repo) <| Api.getBuild model org repo buildNumber


getBuildAndPipeline : Model -> Org -> Repo -> BuildNumber -> Maybe ExpandTemplatesQuery -> Cmd Msg
getBuildAndPipeline model org repo buildNumber expand =
    Api.try (BuildAndPipelineResponse org repo expand) <| Api.getBuild model org repo buildNumber


getDeployment : Model -> Org -> Repo -> DeploymentId -> Cmd Msg
getDeployment model org repo deploymentNumber =
    Api.try DeploymentResponse <| Api.getDeployment model org repo <| Just deploymentNumber


getDeployments : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getDeployments model org repo maybePage maybePerPage =
    Api.try (DeploymentsResponse org repo) <| Api.getDeployments model maybePage maybePerPage org repo


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


getBuildServiceLogs : Model -> Org -> Repo -> BuildNumber -> ServiceNumber -> FocusFragment -> Bool -> Cmd Msg
getBuildServiceLogs model org repo buildNumber serviceNumber logFocus refresh =
    Api.try (ServiceLogResponse serviceNumber logFocus refresh) <| Api.getServiceLogs model org repo buildNumber serviceNumber


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


cancelBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
cancelBuild model org repo buildNumber =
    Api.try (CancelBuildResponse org repo buildNumber) <| Api.cancelBuild model org repo buildNumber


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
getPipelineConfig : Model -> Org -> Repo -> Ref -> FocusFragment -> Bool -> Cmd Msg
getPipelineConfig model org repo ref lineFocus refresh =
    Api.try (GetPipelineConfigResponse lineFocus refresh) <| Api.getPipelineConfig model org repo ref


{-| expandPipelineConfig : takes model, org, repo and ref and expands a pipeline configuration via the API.
-}
expandPipelineConfig : Model -> Org -> Repo -> Ref -> FocusFragment -> Bool -> Cmd Msg
expandPipelineConfig model org repo ref lineFocus refresh =
    Api.tryString (ExpandPipelineConfigResponse lineFocus refresh) <| Api.expandPipelineConfig model org repo ref


{-| getPipelineTemplates : takes model, org, repo and ref and fetches templates used in a pipeline configuration from the API.
-}
getPipelineTemplates : Model -> Org -> Repo -> Ref -> FocusFragment -> Bool -> Cmd Msg
getPipelineTemplates model org repo ref lineFocus refresh =
    Api.try (GetPipelineTemplatesResponse lineFocus refresh) <| Api.getPipelineTemplates model org repo ref



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
