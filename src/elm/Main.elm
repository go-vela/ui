{--
SPDX-License-Identifier: Apache-2.0
--}


module Main exposing (fromSharedEffect, main)

import Alerts exposing (Alert)
import Api.Api
import Api.Endpoint
import Api.Operations
import Api.Operations_
import Api.Pagination as Pagination
import Auth
import Auth.Action
import Auth.Jwt exposing (JwtAccessToken, JwtAccessTokenClaims, extractJwtClaims)
import Auth.Session exposing (Session(..), SessionDetails, refreshAccessToken)
import Browser exposing (Document, UrlRequest)
import Browser.Dom as Dom
import Browser.Events exposing (Visibility(..))
import Browser.Navigation
import Dict
import Effect exposing (Effect)
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
import Interval exposing (Interval(..), RefreshData)
import Json.Decode
import Json.Encode
import Layout
import Layouts exposing (Layout)
import Layouts.Default
import Main.Layouts.Model
import Main.Layouts.Msg
import Main.Pages.Model
import Main.Pages.Msg
import Maybe
import Maybe.Extra exposing (unwrap)
import Nav exposing (viewUtil)
import Page
import Pager
import Pages exposing (Page)
import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Build.Graph.Interop exposing (renderBuildGraph)
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
import Pages.Deployments_
import Pages.Home_
import Pages.Hooks
import Pages.NotFound_
import Pages.Organization
import Pages.Pipeline.Model
import Pages.Pipeline.View exposing (safeDecodePipelineData)
import Pages.RepoSettings exposing (enableUpdate)
import Pages.Schedules.Model
import Pages.Schedules.Update
import Pages.Schedules.View
import Pages.Secrets.Model
import Pages.Secrets.Update
import Pages.Secrets.View
import Pages.Settings
import Pages.SourceRepos
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Routes
import Shared
import String.Extra
import SvgBuilder exposing (velaLogo)
import Task
import Time
    exposing
        ( Posix
        , Zone
        , every
        , here
        )
import Toasty as Alerting exposing (Stack)
import Url exposing (Url)
import Util
import Vela
    exposing
        ( AuthParams
        , Build
        , BuildGraph
        , BuildModel
        , BuildNumber
        , Builds
        , CurrentUser
        , Deployment
        , DeploymentId
        , EnableRepositoryPayload
        , Engine
        , Event
        , Favicon
        , Field
        , FocusFragment
        , GraphInteraction
        , HookNumber
        , Hooks
        , Key
        , Log
        , Logs
        , Name
        , Org
        , PipelineConfig
        , Ref
        , Repo
        , RepoResourceIdentifier
        , Repositories
        , Repository
        , Schedule
        , ScheduleName
        , Schedules
        , Secret
        , SecretType
        , Secrets
        , ServiceNumber
        , Services
        , SourceRepositories
        , StepNumber
        , Steps
        , Team
        , Templates
        , Theme(..)
        , Type
        , UpdateRepositoryPayload
        , UpdateUserPayload
        , buildUpdateFavoritesPayload
        , buildUpdateRepoBoolPayload
        , buildUpdateRepoIntPayload
        , buildUpdateRepoStringPayload
        , decodeGraphInteraction
        , decodeTheme
        , defaultEnableRepositoryPayload
        , defaultFavicon
        , encodeEnableRepository
        , encodeTheme
        , encodeUpdateRepository
        , encodeUpdateUser
        , isComplete
        , secretTypeToString
        , statusToFavicon
        , stringToStatus
        , updateBuild
        , updateBuildGraph
        , updateBuildGraphFilter
        , updateBuildGraphShowServices
        , updateBuildGraphShowSteps
        , updateBuildNumber
        , updateBuildPipelineConfig
        , updateBuildPipelineExpand
        , updateBuildPipelineFocusFragment
        , updateBuildPipelineLineFocus
        , updateBuildServices
        , updateBuildServicesFocusFragment
        , updateBuildServicesFollowing
        , updateBuildServicesLogs
        , updateBuildSteps
        , updateBuildStepsFocusFragment
        , updateBuildStepsFollowing
        , updateBuildStepsLogs
        , updateBuilds
        , updateBuildsEvent
        , updateBuildsPage
        , updateBuildsPager
        , updateBuildsPerPage
        , updateBuildsShowTimeStamp
        , updateDeployments
        , updateDeploymentsPage
        , updateDeploymentsPager
        , updateDeploymentsPerPage
        , updateHooks
        , updateHooksPage
        , updateHooksPager
        , updateHooksPerPage
        , updateOrgRepo
        , updateOrgReposPage
        , updateOrgReposPager
        , updateOrgReposPerPage
        , updateOrgRepositories
        , updateRepo
        , updateRepoCounter
        , updateRepoEnabling
        , updateRepoInitialized
        , updateRepoLimit
        , updateRepoModels
        , updateRepoTimeout
        )
import View exposing (View)
import Visualization.DOT as DOT


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }



-- INIT


type alias Model =
    { key : Browser.Navigation.Key
    , url : Url
    , page : Main.Pages.Model.Model
    , shared : Shared.Model
    , layout : Maybe Main.Layouts.Model.Model

    -- todo: these need to be refactored
    , legacyPage : Page
    , schedulesModel : Pages.Schedules.Model.Model Msg
    , secretsModel : Pages.Secrets.Model.Model Msg
    , deploymentModel : Pages.Deployments.Model.Model Msg
    }


init : Json.Decode.Value -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init json url key =
    let
        flagsResult : Result Json.Decode.Error Shared.Flags
        flagsResult =
            Json.Decode.decodeValue Shared.decoder json

        ( sharedModel, sharedEffect ) =
            Shared.init flagsResult (Route.fromUrl () url)

        fetchTokenCmd =
            if String.length sharedModel.velaRedirect == 0 then
                Api.Api.try TokenResponse <| Api.Operations_.getToken sharedModel.velaAPI

            else
                Cmd.none

        { page, layout } =
            initPageAndLayout { key = key, url = url, shared = sharedModel, layout = Nothing }

        setTimeZone : Cmd Msg
        setTimeZone =
            Task.perform AdjustTimeZone here

        setTime : Cmd Msg
        setTime =
            Task.perform AdjustTime Time.now
    in
    ( { url = url
      , key = key
      , page = Tuple.first page
      , layout = layout |> Maybe.map Tuple.first
      , shared = sharedModel

      -- todo: remove legacy stuff
      , legacyPage = Pages.Overview
      , schedulesModel = Pages.Schedules.Update.init ScheduleResponse AddScheduleResponse UpdateScheduleResponse DeleteScheduleResponse
      , secretsModel = Pages.Secrets.Update.init Copy SecretResponse RepoSecretsResponse OrgSecretsResponse SharedSecretsResponse AddSecretResponse UpdateSecretResponse DeleteSecretResponse
      , deploymentModel = Pages.Deployments.Update.init AddDeploymentResponse
      }
    , Cmd.batch
        [ Tuple.second page
        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
        , fromSharedEffect { key = key, url = url, shared = sharedModel } sharedEffect

        -- custom initialization effects
        , fetchTokenCmd
        , Interop.setTheme <| encodeTheme sharedModel.theme
        , setTimeZone
        , setTime
        ]
    )


initLayout : { key : Browser.Navigation.Key, url : Url, shared : Shared.Model, layout : Maybe Main.Layouts.Model.Model } -> Layouts.Layout Msg -> ( Main.Layouts.Model.Model, Cmd Msg )
initLayout model layout =
    case ( layout, model.layout ) of
        ( Layouts.Default props, Just (Main.Layouts.Model.Default existing) ) ->
            ( Main.Layouts.Model.Default existing
            , Cmd.none
            )

        ( Layouts.Default props, _ ) ->
            let
                route : Route ()
                route =
                    Route.fromUrl () model.url

                defaultLayout =
                    Layouts.Default.layout props model.shared route

                ( defaultLayoutModel, defaultLayoutEffect ) =
                    Layout.init defaultLayout ()
            in
            ( Main.Layouts.Model.Default { default = defaultLayoutModel }
            , fromLayoutEffect model (Effect.map Main.Layouts.Msg.Default defaultLayoutEffect)
            )


initPageAndLayout :
    { key : Browser.Navigation.Key
    , url : Url
    , shared : Shared.Model
    , layout : Maybe Main.Layouts.Model.Model
    }
    ->
        { page : ( Main.Pages.Model.Model, Cmd Msg )
        , layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg )
        }
initPageAndLayout model =
    case Route.Path.fromUrl model.url of
        Route.Path.Login_ ->
            let
                page : Page.Page Pages.Account.Login_.Model Pages.Account.Login_.Msg
                page =
                    Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.Login_
                    (Effect.map Main.Pages.Msg.Login_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout =
                Page.layout pageModel page
                    |> Maybe.map (Layouts.map (Main.Pages.Msg.Login_ >> Page))
                    |> Maybe.map (initLayout model)
            }

        Route.Path.AccountSettings_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Account.Settings_.Model Pages.Account.Settings_.Msg
                        page =
                            Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.AccountSettings_
                            (Effect.map Main.Pages.Msg.AccountSettings_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Logout_ ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Effect.logout {} |> Effect.toCmd { key = model.key, url = model.url, shared = model.shared, fromSharedMsg = Shared, batch = Batch, toCmd = Task.succeed >> Task.perform identity }
                )
            , layout = Nothing
            }

        Route.Path.Authenticate_ ->
            let
                route =
                    Route.fromUrl () model.url

                code =
                    Dict.get "code" route.query

                state =
                    Dict.get "state" route.query
            in
            { page =
                ( Main.Pages.Model.Redirecting_
                , Cmd.batch
                    [ Api.Api.try TokenResponse <|
                        Api.Operations_.finishAuthentication model.shared.velaAPI <|
                            AuthParams code state
                    ]
                )
            , layout = Nothing
            }

        Route.Path.Home_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Home_.Model Pages.Home_.Msg
                        page =
                            Pages.Home_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Home_
                            (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.Deployments_ ->
            runWhenAuthenticatedWithLayout
                model
                (\user ->
                    let
                        page : Page.Page Pages.Deployments_.Model Pages.Deployments_.Msg
                        page =
                            Pages.Deployments_.page user model.shared (Route.fromUrl () model.url)

                        ( pageModel, pageEffect ) =
                            Page.init page ()
                    in
                    { page =
                        Tuple.mapBoth
                            Main.Pages.Model.Deployments_
                            (Effect.map Main.Pages.Msg.Deployments_ >> fromPageEffect model)
                            ( pageModel, pageEffect )
                    , layout =
                        Page.layout pageModel page
                            |> Maybe.map (Layouts.map (Main.Pages.Msg.Deployments_ >> Page))
                            |> Maybe.map (initLayout model)
                    }
                )

        Route.Path.NotFound_ ->
            let
                page : Page.Page Pages.NotFound_.Model Pages.NotFound_.Msg
                page =
                    Pages.NotFound_.page model.shared (Route.fromUrl () model.url)

                ( pageModel, pageEffect ) =
                    Page.init page ()
            in
            { page =
                Tuple.mapBoth
                    Main.Pages.Model.NotFound_
                    (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                    ( pageModel, pageEffect )
            , layout = Nothing
            }


runWhenAuthenticated : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> ( Main.Pages.Model.Model, Cmd Msg )) -> ( Main.Pages.Model.Model, Cmd Msg )
runWhenAuthenticated model toTuple =
    let
        record =
            runWhenAuthenticatedWithLayout model (\user -> { page = toTuple user, layout = Nothing })
    in
    record.page


runWhenAuthenticatedWithLayout : { model | shared : Shared.Model, url : Url, key : Browser.Navigation.Key } -> (Auth.User -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }) -> { page : ( Main.Pages.Model.Model, Cmd Msg ), layout : Maybe ( Main.Layouts.Model.Model, Cmd Msg ) }
runWhenAuthenticatedWithLayout model toRecord =
    let
        authAction : Auth.Action.Action Auth.User
        authAction =
            Auth.onPageLoad model.shared (Route.fromUrl () model.url)

        toCmd : Effect Msg -> Cmd Msg
        toCmd =
            Effect.toCmd
                { key = model.key
                , url = model.url
                , shared = model.shared
                , fromSharedMsg = Shared
                , batch = Batch
                , toCmd = Task.succeed >> Task.perform identity
                }
    in
    case authAction of
        Auth.Action.LoadPageWithUser user ->
            toRecord user

        Auth.Action.ShowLoadingPage loadingView ->
            { page =
                ( Main.Pages.Model.Loading_
                , Cmd.none
                )
            , layout = Nothing
            }

        Auth.Action.ReplaceRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , toCmd (Effect.replaceRoute options)
                )
            , layout = Nothing
            }

        Auth.Action.PushRoute options ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Cmd.batch
                    [ toCmd (Effect.pushRoute options)
                    , unwrap Cmd.none (\from -> Interop.setRedirect <| Json.Encode.string from) (Dict.get "from" options.query)
                    ]
                )
            , layout = Nothing
            }

        Auth.Action.LoadExternalUrl externalUrl ->
            { page =
                ( Main.Pages.Model.Redirecting_
                , Browser.Navigation.load externalUrl
                )
            , layout = Nothing
            }



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Page Main.Pages.Msg.Msg
    | Layout Main.Layouts.Msg.Msg
    | Shared Shared.Msg
    | Batch (List Msg)
      -- END NEW WORLD
      -- todo: determine if this should, and if it can, be moved to Shared.Msg
    | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, JwtAccessToken ))
      --
      --
      --
      --
      --
      --
      -- todo: move everything below this into Shared.Msg or completely remove it
      -- | NewRoute Routes.Route
      -- | ClickedLink UrlRequest
    | SearchSourceRepos Org String
      -- | SearchFavorites String
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
    | BuildGraphShowServices Bool
    | BuildGraphShowSteps Bool
    | BuildGraphRefresh Org Repo BuildNumber
    | BuildGraphRotate
    | BuildGraphUpdateFilter String
    | OnBuildGraphInteraction GraphInteraction
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
    | UpdateRepoForkPolicy Org Repo Field String
    | UpdateRepoPipelineType Org Repo Field String
    | UpdateRepoLimit Org Repo Field Int
    | UpdateRepoTimeout Org Repo Field Int
    | UpdateRepoCounter Org Repo Field Int
    | ApproveBuild Org Repo BuildNumber
    | RestartBuild Org Repo BuildNumber
    | CancelBuild Org Repo BuildNumber
    | RedeliverHook Org Repo HookNumber
    | GetPipelineConfig Org Repo BuildNumber Ref FocusFragment Bool
    | ExpandPipelineConfig Org Repo BuildNumber Ref FocusFragment Bool
      -- Inbound HTTP responses
    | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
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
    | ApprovedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | CancelBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | OrgBuildsResponse Org (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | DeploymentsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, List Deployment ))
    | HooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | RedeliverHookResponse Org Repo HookNumber (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | BuildResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
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
      -- Schedules
    | SchedulesResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Schedules ))
    | ScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ))
    | AddScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ))
    | UpdateScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ))
    | DeleteScheduleResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- Graph
    | BuildGraphResponse Org Repo BuildNumber Bool (Result (Http.Detailed.Error String) ( Http.Metadata, BuildGraph ))
      -- Time
    | AdjustTimeZone Zone
    | AdjustTime Posix
    | Tick Interval Posix
      -- Components
      -- todo: move these into Shared.Msg somehow
    | AddScheduleUpdate Pages.Schedules.Model.Msg
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
    | NoOp -- todo: remove NoOp from Main


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        shared =
            model.shared

        rm =
            shared.repo

        bm =
            rm.build

        gm =
            shared.repo.build.graph

        sm =
            model.schedulesModel

        pipeline =
            shared.pipeline
    in
    case msg of
        UrlRequested (Browser.Internal url) ->
            ( model
            , Browser.Navigation.pushUrl model.key (Url.toString url)
            )

        UrlRequested (Browser.External url) ->
            ( model
            , Browser.Navigation.load url
            )

        UrlChanged url ->
            if Route.Path.fromUrl url == Route.Path.fromUrl model.url && not (Route.hasAuthRedirect (Route.fromUrl () url)) then
                let
                    newModel : Model
                    newModel =
                        { model | url = url }
                in
                ( newModel
                , Cmd.batch
                    [ toPageUrlHookCmd newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    , toLayoutUrlHookCmd model
                        newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    ]
                )

            else
                let
                    { page, layout } =
                        initPageAndLayout { key = model.key, shared = model.shared, layout = model.layout, url = url }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        case layout of
                            Just ( layoutModel_, layoutCmd_ ) ->
                                ( Just layoutModel_, layoutCmd_ )

                            Nothing ->
                                ( Nothing, Cmd.none )

                    newModel =
                        { model | url = url, page = pageModel, layout = layoutModel }
                in
                ( newModel
                , Cmd.batch
                    [ pageCmd
                    , layoutCmd
                    , toLayoutUrlHookCmd model
                        newModel
                        { from = Route.fromUrl () model.url
                        , to = Route.fromUrl () newModel.url
                        }
                    ]
                )

        Page pageMsg ->
            let
                ( pageModel, pageCmd ) =
                    updateFromPage pageMsg model
            in
            ( { model | page = pageModel }
            , pageCmd
            )

        Layout layoutMsg ->
            let
                ( layoutModel, layoutCmd ) =
                    updateFromLayout layoutMsg model
            in
            ( { model | layout = layoutModel }
            , layoutCmd
            )

        Shared sharedMsg ->
            let
                ( sharedModel, sharedEffect ) =
                    Shared.update (Route.fromUrl () model.url) sharedMsg model.shared

                ( oldAction, newAction ) =
                    ( Auth.onPageLoad model.shared (Route.fromUrl () model.url)
                    , Auth.onPageLoad sharedModel (Route.fromUrl () model.url)
                    )
            in
            if isAuthProtected (Route.fromUrl () model.url).path && hasActionTypeChanged oldAction newAction then
                let
                    { layout, page } =
                        initPageAndLayout { key = model.key, shared = sharedModel, url = model.url, layout = model.layout }

                    ( pageModel, pageCmd ) =
                        page

                    ( layoutModel, layoutCmd ) =
                        ( layout |> Maybe.map Tuple.first
                        , layout |> Maybe.map Tuple.second |> Maybe.withDefault Cmd.none
                        )
                in
                ( { model | shared = sharedModel, page = pageModel, layout = layoutModel }
                , Cmd.batch
                    [ pageCmd
                    , layoutCmd
                    , fromSharedEffect { model | shared = sharedModel } sharedEffect
                    ]
                )

            else
                ( { model | shared = sharedModel }
                , fromSharedEffect { model | shared = sharedModel } sharedEffect
                )

        Batch messages ->
            ( model
            , messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
            )

        TokenResponse response ->
            case response of
                Ok ( _, token ) ->
                    let
                        currentSession : Session
                        currentSession =
                            model.shared.session

                        payload : JwtAccessTokenClaims
                        payload =
                            extractJwtClaims token

                        newSessionDetails : SessionDetails
                        newSessionDetails =
                            SessionDetails token payload.exp payload.sub

                        actions : List (Cmd Msg)
                        actions =
                            case currentSession of
                                Unauthenticated ->
                                    let
                                        route =
                                            Route.fromUrl () model.url

                                        from =
                                            case shared.velaRedirect of
                                                "" ->
                                                    case Dict.get "from" route.query of
                                                        Just f ->
                                                            f

                                                        Nothing ->
                                                            "/"

                                                _ ->
                                                    shared.velaRedirect
                                    in
                                    [ Browser.Navigation.pushUrl model.key <| Route.addAuthRedirect from
                                    ]

                                Authenticated _ ->
                                    []
                    in
                    ( { model
                        | shared =
                            { shared
                                | session = Authenticated newSessionDetails
                                , fetchingToken = False
                                , token = Just token
                            }
                      }
                    , Cmd.batch <|
                        actions
                            ++ [ Interop.setRedirect Json.Encode.null
                               , refreshAccessToken RefreshAccessToken newSessionDetails
                               ]
                    )

                Err error ->
                    let
                        redirectPage : Cmd Msg
                        redirectPage =
                            case model.page of
                                Main.Pages.Model.Login_ _ ->
                                    Cmd.none

                                _ ->
                                    Browser.Navigation.pushUrl model.key <| Route.addAuthRedirect <| Route.Path.toString Route.Path.Login_
                    in
                    case error of
                        Http.Detailed.BadStatus meta _ ->
                            case meta.statusCode of
                                401 ->
                                    let
                                        actions : List (Cmd Msg)
                                        actions =
                                            case model.shared.session of
                                                Unauthenticated ->
                                                    [ redirectPage ]

                                                Authenticated _ ->
                                                    [ addErrorString "Your session has expired or you logged in somewhere else, please log in again." HandleError
                                                    , redirectPage
                                                    ]
                                    in
                                    ( { model
                                        | shared =
                                            { shared
                                                | session =
                                                    Unauthenticated
                                                , fetchingToken = False
                                            }
                                      }
                                    , Cmd.batch actions
                                    )

                                _ ->
                                    ( { model
                                        | shared =
                                            { shared
                                                | session = Unauthenticated
                                                , fetchingToken = False
                                            }
                                      }
                                    , Cmd.batch
                                        [ Errors.addError HandleError error
                                        , redirectPage
                                        ]
                                    )

                        _ ->
                            ( { model
                                | shared =
                                    { shared
                                        | session = Unauthenticated
                                        , fetchingToken = False
                                    }
                              }
                            , Cmd.batch
                                [ Errors.addError HandleError error
                                , redirectPage
                                ]
                            )

        -- END NEW WORLD
        -- User events
        -- NewRoute route ->
        --     setNewPage route model
        -- ClickedLink urlRequest ->
        --     case urlRequest of
        --         Browser.Internal url ->
        --             ( model, Browser.Navigation.pushUrl model.key <| Url.toString url )
        --         Browser.External url ->
        --             ( model, Browser.Navigation.load url )
        LogoutResponse _ ->
            ( { model | shared = { shared | session = Unauthenticated } }
            , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl Routes.Login
            )

        CurrentUserResponse response ->
            case response of
                Ok ( _, user ) ->
                    ( { model | shared = { shared | user = RemoteData.succeed user } }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | user = toFailure error } }, Errors.addError HandleError error )

        SearchSourceRepos org searchBy ->
            let
                filters =
                    Dict.update org (\_ -> Just searchBy) model.shared.filters
            in
            ( { model | shared = { shared | filters = filters } }, Cmd.none )

        ChangeRepoLimit limit ->
            let
                newLimit =
                    Maybe.withDefault 0 <| String.toInt limit
            in
            ( { model | shared = { shared | repo = updateRepoLimit (Just newLimit) rm } }, Cmd.none )

        ChangeRepoTimeout timeout ->
            let
                newTimeout =
                    case String.toInt timeout of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | shared = { shared | repo = updateRepoTimeout newTimeout rm } }, Cmd.none )

        ChangeRepoCounter counter ->
            let
                newCounter =
                    case String.toInt counter of
                        Just t ->
                            Just t

                        Nothing ->
                            Just 0
            in
            ( { model | shared = { shared | repo = updateRepoCounter newCounter rm } }, Cmd.none )

        RefreshSettings org repo ->
            ( { model
                | shared =
                    { shared
                        | repo =
                            rm
                                |> updateRepoLimit Nothing
                                |> updateRepoTimeout Nothing
                                |> updateRepoCounter Nothing
                                |> updateRepo Loading
                    }
              }
            , Api.Api.try RepoResponse <| Api.Operations.getRepo model org repo
            )

        RefreshHooks org repo ->
            ( { model | shared = { shared | repo = updateHooks Loading rm } }, getHooks model org repo Nothing Nothing )

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
                | shared =
                    { shared
                        | repo =
                            rm
                                |> updateBuilds Loading
                                |> updateBuildsPager []
                    }
              }
            , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| route
            )

        ShowHideFullTimestamp ->
            ( { model | shared = { shared | repo = rm |> updateBuildsShowTimeStamp } }, Cmd.none )

        SetTheme theme ->
            if theme == model.shared.theme then
                ( model, Cmd.none )

            else
                ( { model | shared = { shared | theme = theme } }, Interop.setTheme <| encodeTheme theme )

        GotoPage pageNumber ->
            case model.legacyPage of
                Pages.OrgBuilds org _ maybePerPage maybeEvent ->
                    ( { model | shared = { shared | repo = updateBuilds Loading rm } }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.OrgBuilds org (Just pageNumber) maybePerPage maybeEvent
                    )

                Pages.OrgRepositories org _ maybePerPage ->
                    ( { model | shared = { shared | repo = updateOrgRepositories Loading rm } }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.OrgRepositories org (Just pageNumber) maybePerPage
                    )

                Pages.RepositoryBuilds org repo _ maybePerPage maybeEvent ->
                    ( { model | shared = { shared | repo = updateBuilds Loading rm } }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo (Just pageNumber) maybePerPage maybeEvent
                    )

                Pages.RepositoryDeployments org repo _ maybePerPage ->
                    ( { model | shared = { shared | repo = updateDeployments Loading rm } }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.RepositoryDeployments org repo (Just pageNumber) maybePerPage
                    )

                Pages.Hooks org repo _ maybePerPage ->
                    ( { model | shared = { shared | repo = updateHooks Loading rm } }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.Hooks org repo (Just pageNumber) maybePerPage
                    )

                Pages.RepoSecrets engine org repo _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | repoSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.RepoSecrets engine org repo (Just pageNumber) maybePerPage
                    )

                Pages.OrgSecrets engine org _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | orgSecrets = Loading, sharedSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.OrgSecrets engine org (Just pageNumber) maybePerPage
                    )

                Pages.SharedSecrets engine org team _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | sharedSecrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.SharedSecrets engine org team (Just pageNumber) maybePerPage
                    )

                Pages.Schedules org repo _ maybePerPage ->
                    ( { model | schedulesModel = { sm | schedules = Loading } }
                    , Browser.Navigation.pushUrl model.key <| Routes.routeToUrl <| Routes.Schedules org repo (Just pageNumber) maybePerPage
                    )

                _ ->
                    ( model, Cmd.none )

        ShowHideHelp show ->
            ( { model
                | shared =
                    { shared
                        | showHelp =
                            case show of
                                Just s ->
                                    s

                                Nothing ->
                                    not model.shared.showHelp
                    }
              }
            , Cmd.none
            )

        ShowHideBuildMenu build show ->
            let
                buildsOpen =
                    model.shared.buildMenuOpen

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
                | shared = { shared | buildMenuOpen = updatedOpen }
              }
            , Cmd.none
            )

        ShowHideIdentity show ->
            ( { model
                | shared =
                    { shared
                        | showIdentity =
                            case show of
                                Just s ->
                                    s

                                Nothing ->
                                    not model.shared.showIdentity
                    }
              }
            , Cmd.none
            )

        Copy content ->
            let
                ( sharedWithAlert, cmd ) =
                    Alerting.addToast Alerts.successConfig
                        AlertsUpdate
                        (Alerts.Success ""
                            ("Copied " ++ wrapAlertMessage content ++ "to your clipboard.")
                            Nothing
                        )
                        ( model.shared, Cmd.none )
            in
            ( { model | shared = sharedWithAlert }, cmd )

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
            ( { model | shared = { shared | repo = updateBuildSteps steps rm } }
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
            ( { model | shared = { shared | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing 0 } }
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
            ( { model | shared = { shared | repo = rm |> updateBuildSteps steps |> updateBuildStepsFollowing follow } }
            , Cmd.batch <|
                [ action
                , if stepOpened then
                    Browser.Navigation.pushUrl model.key <| resourceFocusFragment "step" stepNumber []

                  else
                    Cmd.none
                ]
            )

        FollowStep follow ->
            ( { model | shared = { shared | repo = updateBuildStepsFollowing follow rm } }
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
            ( { model | shared = { shared | repo = updateBuildServices services rm } }
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
            ( { model | shared = { shared | repo = rm |> updateBuildServices services |> updateBuildServicesFollowing 0 } }
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
            ( { model | shared = { shared | repo = rm |> updateBuildServices services |> updateBuildServicesFollowing follow } }
            , Cmd.batch <|
                [ action
                , if serviceOpened then
                    Browser.Navigation.pushUrl model.key <| resourceFocusFragment "service" serviceNumber []

                  else
                    Cmd.none
                ]
            )

        FollowService follow ->
            ( { model | shared = { shared | repo = updateBuildServicesFollowing follow rm } }
            , Cmd.none
            )

        ShowHideTemplates ->
            let
                templates =
                    shared.templates
            in
            ( { model | shared = { shared | templates = { templates | show = not templates.show } } }, Cmd.none )

        FocusPipelineConfigLineNumber line ->
            let
                url =
                    lineRangeId "config" "0" line pipeline.lineFocus model.shared.shift
            in
            ( { model | shared = { shared | pipeline = pipeline } }
            , Browser.Navigation.pushUrl model.key <| url
            )

        BuildGraphRefresh org repo buildNumber ->
            let
                ugm =
                    { gm
                        | graph = Loading
                    }

                usm =
                    updateRepoModels model.shared rm bm ugm

                um =
                    { model | shared = usm }
            in
            ( um
            , getBuildGraph um org repo buildNumber True
            )

        BuildGraphRotate ->
            let
                rankdir =
                    case gm.rankdir of
                        DOT.LR ->
                            DOT.TB

                        _ ->
                            DOT.LR

                ugm =
                    { gm
                        | rankdir = rankdir
                    }

                usm =
                    updateRepoModels model.shared rm bm ugm

                um =
                    { model | shared = usm }
            in
            ( um
            , renderBuildGraph um False
            )

        BuildGraphUpdateFilter filter ->
            let
                ugm =
                    { gm
                        | filter = String.toLower filter
                    }

                usm =
                    updateRepoModels model.shared rm bm ugm

                um =
                    { model | shared = usm }
            in
            ( um
            , renderBuildGraph um False
            )

        BuildGraphShowServices show ->
            let
                ugm =
                    { gm
                        | showServices = show
                    }

                usm =
                    updateRepoModels model.shared rm bm ugm

                um =
                    { model | shared = usm }
            in
            ( um
            , renderBuildGraph um False
            )

        BuildGraphShowSteps show ->
            let
                ugm =
                    { gm
                        | showSteps = show
                    }

                usm =
                    updateRepoModels model.shared rm bm ugm

                um =
                    { model | shared = usm }
            in
            ( um
            , renderBuildGraph um False
            )

        OnBuildGraphInteraction interaction ->
            let
                ( ugm_, cmd ) =
                    case interaction.eventType of
                        "href" ->
                            ( model.shared.repo.build.graph
                            , Cmd.batch
                                [ Util.dispatch <| FocusOn (focusFragmentToFocusId "step" (Just <| String.Extra.rightOf "#" interaction.href))
                                , Browser.Navigation.pushUrl model.key interaction.href
                                ]
                            )

                        "backdrop_click" ->
                            let
                                ugm =
                                    { gm | focusedNode = -1 }

                                usm =
                                    updateRepoModels shared rm bm ugm

                                um =
                                    { model | shared = usm }
                            in
                            ( ugm, renderBuildGraph um False )

                        "node_click" ->
                            let
                                ugm =
                                    { gm | focusedNode = Maybe.withDefault -1 <| String.toInt interaction.nodeID }

                                usm =
                                    updateRepoModels shared rm bm ugm

                                um =
                                    { model | shared = usm }
                            in
                            ( ugm, renderBuildGraph um False )

                        _ ->
                            ( model.shared.repo.build.graph, Cmd.none )
            in
            ( { model | shared = updateRepoModels shared rm bm ugm_ }
            , cmd
            )

        -- Outgoing HTTP requests
        RefreshAccessToken ->
            ( model, getToken model )

        SignInRequested ->
            -- Login on server needs to accept redirect URL and pass it along to as part of 'state' encoded as base64
            -- so we can parse it when the source provider redirects back to the API
            ( model, Browser.Navigation.load <| Api.Endpoint.toUrl model.shared.velaAPI Api.Endpoint.Login )

        FetchSourceRepositories ->
            ( { model | shared = { shared | sourceRepos = Loading } }, Api.Api.try SourceRepositoriesResponse <| Api.Operations.getSourceRepositories model )

        ToggleFavorite org repo ->
            let
                favorite =
                    toFavorite org repo

                ( favorites, favorited ) =
                    updateFavorites model.shared.user favorite

                payload : UpdateUserPayload
                payload =
                    buildUpdateFavoritesPayload favorites

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateUser payload
            in
            ( model
            , Api.Api.try (RepoFavoritedResponse favorite favorited) (Api.Operations.updateCurrentUser model body)
            )

        AddFavorite org repo ->
            let
                favorite =
                    toFavorite org repo

                ( favorites, favorited ) =
                    addFavorite model.shared.user favorite

                payload : UpdateUserPayload
                payload =
                    buildUpdateFavoritesPayload favorites

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateUser payload
            in
            ( model
            , Api.Api.try (RepoFavoritedResponse favorite favorited) (Api.Operations.updateCurrentUser model body)
            )

        EnableRepos repos ->
            ( model
            , Cmd.batch <| List.map (Util.dispatch << EnableRepo) repos
            )

        EnableRepo repo ->
            let
                payload : EnableRepositoryPayload
                payload =
                    Vela.buildEnableRepositoryPayload repo

                body : Http.Body
                body =
                    Http.jsonBody <| encodeEnableRepository payload
            in
            ( { model
                | shared =
                    { shared
                        | sourceRepos = enableUpdate repo Loading model.shared.sourceRepos
                        , repo = updateRepoEnabling Vela.Enabling rm
                    }
              }
            , Api.Api.try (RepoEnabledResponse repo) <| Api.Operations.enableRepository model body
            )

        DisableRepo repo ->
            let
                ( status, action ) =
                    case repo.enabling of
                        Vela.Enabled ->
                            ( Vela.ConfirmDisable, Cmd.none )

                        Vela.ConfirmDisable ->
                            ( Vela.Disabling, Api.Api.try (RepoDisabledResponse repo) <| Api.Operations.deleteRepo model repo )

                        _ ->
                            ( repo.enabling, Cmd.none )
            in
            ( { model
                | shared = { shared | repo = updateRepoEnabling status rm }
              }
            , action
            )

        ChownRepo repo ->
            ( model, Api.Api.try (RepoChownedResponse repo) <| Api.Operations.chownRepo model repo )

        RepairRepo repo ->
            ( model, Api.Api.try (RepoRepairedResponse repo) <| Api.Operations.repairRepo model repo )

        UpdateRepoEvent org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoBoolPayload field value

                cmd =
                    if Pages.RepoSettings.validEventsUpdate rm.repo payload then
                        let
                            body : Http.Body
                            body =
                                Http.jsonBody <| encodeUpdateRepository payload
                        in
                        Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)

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

                cmd =
                    if Pages.RepoSettings.validAccessUpdate rm.repo payload then
                        let
                            body : Http.Body
                            body =
                                Http.jsonBody <| encodeUpdateRepository payload
                        in
                        Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)

                    else
                        Cmd.none
            in
            ( model
            , cmd
            )

        UpdateRepoForkPolicy org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoStringPayload field value

                cmd =
                    if Pages.RepoSettings.validForkPolicyUpdate rm.repo payload then
                        let
                            body : Http.Body
                            body =
                                Http.jsonBody <| encodeUpdateRepository payload
                        in
                        Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)

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

                cmd =
                    if Pages.RepoSettings.validPipelineTypeUpdate rm.repo payload then
                        let
                            body : Http.Body
                            body =
                                Http.jsonBody <| encodeUpdateRepository payload
                        in
                        Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)

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
            , Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)
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
            , Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)
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
            , Api.Api.try (RepoUpdatedResponse field) (Api.Operations.updateRepository model org repo body)
            )

        ApproveBuild org repo buildNumber ->
            let
                newModel =
                    { model | shared = { shared | buildMenuOpen = [] } }
            in
            ( newModel
            , approveBuild model org repo buildNumber
            )

        RestartBuild org repo buildNumber ->
            let
                newModel =
                    { model | shared = { shared | buildMenuOpen = [] } }
            in
            ( newModel
            , restartBuild model org repo buildNumber
            )

        CancelBuild org repo buildNumber ->
            let
                newModel =
                    { model | shared = { shared | buildMenuOpen = [] } }
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
                | shared =
                    { shared
                        | pipeline =
                            { pipeline
                                | expanding = True
                            }
                    }
              }
            , Cmd.batch
                [ getPipelineConfig model org repo ref lineFocus refresh
                , Browser.Navigation.replaceUrl model.key <| Routes.routeToUrl <| Routes.BuildPipeline org repo buildNumber Nothing lineFocus
                ]
            )

        ExpandPipelineConfig org repo buildNumber ref lineFocus refresh ->
            ( { model
                | shared =
                    { shared
                        | pipeline =
                            { pipeline
                                | expanding = True
                            }
                    }
              }
            , Cmd.batch
                [ expandPipelineConfig model org repo ref lineFocus refresh
                , Browser.Navigation.replaceUrl model.key <| Routes.routeToUrl <| Routes.BuildPipeline org repo buildNumber (Just "true") lineFocus
                ]
            )

        -- Inbound HTTP responses
        SchedulesResponse org repo result ->
            case result of
                Ok ( meta, schedules ) ->
                    ( { model
                        | schedulesModel =
                            { sm
                                | org = org
                                , repo = repo
                                , schedules = RemoteData.succeed schedules
                                , pager = Pagination.get meta.headers
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | schedulesModel = { sm | schedules = toFailure error } }, Errors.addError HandleError error )

        ScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    let
                        updatedSchedulesModel =
                            Pages.Schedules.Update.reinitializeScheduleUpdate sm schedule
                    in
                    ( { model | schedulesModel = updatedSchedulesModel }
                    , Cmd.none
                    )

                Err error ->
                    ( model, Errors.addError HandleError error )

        AddScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    let
                        um =
                            { model | schedulesModel = Pages.Schedules.Update.reinitializeScheduleAdd sm }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (schedule.name ++ " added to repo schedules.") Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        UpdateScheduleResponse response ->
            case response of
                Ok ( _, schedule ) ->
                    let
                        um =
                            { model | schedulesModel = Pages.Schedules.Update.reinitializeScheduleUpdate sm schedule }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" ("Repo schedule " ++ schedule.name ++ " updated.") Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        DeleteScheduleResponse response ->
            case response of
                Ok _ ->
                    let
                        alertMessage =
                            sm.form.name ++ " removed from repo schedules."

                        redirectTo =
                            Routes.routeToUrl (Routes.Schedules sm.org sm.repo Nothing Nothing)

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" alertMessage Nothing) ( model.shared, Browser.Navigation.pushUrl model.key redirectTo )
                    in
                    ( { model | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        SourceRepositoriesResponse response ->
            case response of
                Ok ( _, repositories ) ->
                    ( { model | shared = { shared | sourceRepos = RemoteData.succeed repositories } }, Util.dispatch <| FocusOn "global-search-input" )

                Err error ->
                    ( { model | shared = { shared | sourceRepos = toFailure error } }, Errors.addError HandleError error )

        RepoFavoritedResponse favorite favorited response ->
            case response of
                Ok ( _, user ) ->
                    let
                        um =
                            { model | shared = { shared | user = RemoteData.succeed user } }

                        ( sharedWithAlert, cmd ) =
                            if favorited then
                                Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (favorite ++ " added to favorites.") Nothing) ( um.shared, Cmd.none )

                            else
                                Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (favorite ++ " removed from favorites.") Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( { model | shared = { shared | user = toFailure error } }, Errors.addError HandleError error )

        RepoResponse response ->
            case response of
                Ok ( _, repoResponse ) ->
                    let
                        dm =
                            model.deploymentModel
                    in
                    ( { model | shared = { shared | repo = updateRepo (RemoteData.succeed repoResponse) rm }, deploymentModel = { dm | repo_settings = RemoteData.succeed repoResponse } }, Cmd.none )

                Err error ->
                    ( { model | shared = { shared | repo = updateRepo (toFailure error) rm } }, Errors.addError HandleError error )

        OrgRepositoriesResponse response ->
            case response of
                Ok ( meta, repoResponse ) ->
                    ( { model
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateOrgRepositories (RemoteData.succeed repoResponse)
                                        |> updateOrgReposPager (Pagination.get meta.headers)
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateOrgRepositories (toFailure error) rm } }, Errors.addError HandleError error )

        RepoEnabledResponse repo response ->
            case response of
                Ok ( _, enabledRepo ) ->
                    let
                        um =
                            { model
                                | shared =
                                    { shared
                                        | sourceRepos = enableUpdate enabledRepo (RemoteData.succeed True) model.shared.sourceRepos
                                        , repo = updateRepoEnabling Vela.Enabled rm
                                    }
                            }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (enabledRepo.full_name ++ " enabled.") Nothing) ( um.shared, Util.dispatch <| AddFavorite repo.org <| Just repo.name )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    let
                        ( sourceRepos, action ) =
                            repoEnabledError model.shared.sourceRepos repo error
                    in
                    ( { model | shared = { shared | sourceRepos = sourceRepos } }, action )

        RepoDisabledResponse repo response ->
            case response of
                Ok _ ->
                    let
                        um =
                            { model
                                | shared =
                                    { shared
                                        | sourceRepos = enableUpdate repo NotAsked model.shared.sourceRepos
                                        , repo = updateRepoEnabling Vela.Disabled rm
                                    }
                            }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " disabled.") Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        RepoUpdatedResponse field response ->
            case response of
                Ok ( _, updatedRepo ) ->
                    let
                        um =
                            { model | shared = { shared | repo = updateRepo (RemoteData.succeed updatedRepo) rm } }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (Pages.RepoSettings.alert field updatedRepo) Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        RepoChownedResponse repo response ->
            case response of
                Ok _ ->
                    let
                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" ("You are now the owner of " ++ repo.full_name) Nothing) ( model.shared, Cmd.none )
                    in
                    ( { model | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        RepoRepairedResponse repo response ->
            case response of
                Ok _ ->
                    let
                        um =
                            { model
                                | shared =
                                    { shared
                                        | sourceRepos = enableUpdate repo (RemoteData.succeed True) model.shared.sourceRepos
                                        , repo = updateRepoEnabling Vela.Enabled rm
                                    }
                            }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " has been repaired.") Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        ApprovedBuildResponse org repo buildNumber response ->
            case response of
                Ok _ ->
                    let
                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" ("Build approved to run " ++ String.join "/" [ org, repo, buildNumber ]) Nothing) ( model.shared, Cmd.none )
                    in
                    ( { model | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

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

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (restartedBuild ++ " restarted.") (Just ( "View Build #" ++ newBuildNumber, newBuild ))) ( model.shared, getBuilds model org repo Nothing Nothing Nothing )
                    in
                    ( { model | shared = sharedWithAlert }
                    , cmd
                    )

                Err error ->
                    ( model, Errors.addError HandleError error )

        CancelBuildResponse org repo buildNumber response ->
            case response of
                Ok ( _, build ) ->
                    let
                        canceledBuild =
                            "Build " ++ String.join "/" [ org, repo, buildNumber ]

                        um =
                            { model
                                | shared =
                                    { shared
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
                            }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (canceledBuild ++ " canceled.") Nothing) ( um.shared, Cmd.none )
                    in
                    ( { um | shared = sharedWithAlert }
                    , cmd
                    )

                Err error ->
                    ( model, Errors.addError HandleError error )

        BuildsResponse org repo response ->
            case response of
                Ok ( meta, builds ) ->
                    ( { model
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateOrgRepo org repo
                                        |> updateBuilds (RemoteData.succeed builds)
                                        |> updateBuildsPager (Pagination.get meta.headers)
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateBuilds (toFailure error) rm } }, Errors.addError HandleError error )

        OrgBuildsResponse org response ->
            case response of
                Ok ( meta, builds ) ->
                    ( { model
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateOrgRepo org ""
                                        |> updateBuilds (RemoteData.succeed builds)
                                        |> updateBuildsPager (Pagination.get meta.headers)
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateBuilds (toFailure error) rm } }, Errors.addError HandleError error )

        DeploymentsResponse org repo response ->
            case response of
                Ok ( meta, deployments ) ->
                    ( { model
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateOrgRepo org repo
                                        |> updateDeployments (RemoteData.succeed deployments)
                                        |> updateDeploymentsPager (Pagination.get meta.headers)
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateDeployments (toFailure error) rm } }, Errors.addError HandleError error )

        HooksResponse response ->
            case response of
                Ok ( meta, hooks ) ->
                    ( { model
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateHooks (RemoteData.succeed hooks)
                                        |> updateHooksPager (Pagination.get meta.headers)
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateHooks (toFailure error) rm } }, Errors.addError HandleError error )

        RedeliverHookResponse org repo hookNumber response ->
            case response of
                Ok ( _, redeliverResponse ) ->
                    let
                        redeliveredHook =
                            "Hook " ++ String.join "/" [ org, repo, hookNumber ]

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (redeliveredHook ++ " redelivered.") Nothing) ( model.shared, getHooks model org repo Nothing Nothing )
                    in
                    ( { model | shared = sharedWithAlert }
                    , cmd
                    )

                Err error ->
                    ( model, Errors.addError HandleError error )

        BuildResponse org repo response ->
            case response of
                Ok ( _, build ) ->
                    ( { model
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateOrgRepo org repo
                                        |> updateBuild (RemoteData.succeed build)
                                , favicon = statusToFavicon build.status
                            }
                      }
                    , Interop.setFavicon <| Json.Encode.string <| statusToFavicon build.status
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateBuild (toFailure error) rm } }, Errors.addError HandleError error )

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
                        | shared =
                            { shared
                                | repo =
                                    rm
                                        |> updateOrgRepo org repo
                                        |> updateBuild (RemoteData.succeed build)
                                , favicon = statusToFavicon build.status
                            }
                      }
                    , Cmd.batch
                        [ Interop.setFavicon <| Json.Encode.string <| statusToFavicon build.status
                        , getPipeline model org repo build.commit Nothing False
                        , getPipelineTemplates model org repo build.commit Nothing False
                        ]
                    )

                Err error ->
                    ( { model | shared = { shared | repo = updateBuild (toFailure error) rm } }, Errors.addError HandleError error )

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
                    ( model, Errors.addError HandleError error )

        StepsResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, steps ) ->
                    let
                        mergedSteps =
                            steps
                                |> List.sortBy .number
                                |> Pages.Build.Logs.merge logFocus refresh rm.build.steps.steps

                        updatedModel =
                            { model | shared = { shared | repo = updateBuildSteps (RemoteData.succeed mergedSteps) rm } }

                        cmd =
                            getBuildStepsLogs updatedModel org repo buildNumber mergedSteps logFocus refresh
                    in
                    ( updatedModel, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

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
                    ( updateStepLogs { model | shared = { shared | repo = updateBuildSteps steps rm } } incomingLog
                    , cmd
                    )

                Err error ->
                    ( model, Errors.addError HandleError error )

        ServicesResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, services ) ->
                    let
                        mergedServices =
                            services
                                |> List.sortBy .number
                                |> Pages.Build.Logs.merge logFocus refresh rm.build.services.services

                        updatedModel =
                            { model | shared = { shared | repo = updateBuildServices (RemoteData.succeed mergedServices) rm } }

                        cmd =
                            getBuildServicesLogs updatedModel org repo buildNumber mergedServices logFocus refresh
                    in
                    ( updatedModel, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

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
                    ( updateServiceLogs { model | shared = { shared | repo = updateBuildServices services rm } } incomingLog
                    , cmd
                    )

                Err error ->
                    ( model, Errors.addError HandleError error )

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
                        | shared =
                            { shared
                                | pipeline =
                                    { pipeline
                                        | config = ( RemoteData.succeed <| safeDecodePipelineData config pipeline.config, "" )
                                        , expanded = False
                                        , expanding = False
                                    }
                            }
                      }
                    , cmd
                    )

                Err error ->
                    ( { model
                        | shared =
                            { shared
                                | pipeline =
                                    { pipeline
                                        | config = ( toFailure error, detailedErrorToString error )
                                    }
                            }
                      }
                    , Errors.addError HandleError error
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
                        | shared =
                            { shared
                                | pipeline =
                                    { pipeline
                                        | config = ( RemoteData.succeed { rawData = config, decodedData = config }, "" )
                                        , expanded = True
                                        , expanding = False
                                    }
                            }
                      }
                    , cmd
                    )

                Err error ->
                    ( { model
                        | shared =
                            { shared
                                | pipeline =
                                    { pipeline
                                        | config = ( Errors.toFailure error, detailedErrorToString error )
                                        , expanding = False
                                        , expanded = True
                                    }
                            }
                      }
                    , Errors.addError HandleError error
                    )

        GetPipelineTemplatesResponse lineFocus refresh response ->
            case response of
                Ok ( _, templates ) ->
                    ( { model
                        | shared = { shared | templates = { data = RemoteData.succeed templates, error = "", show = shared.templates.show } }
                      }
                    , if not refresh then
                        Util.dispatch <| FocusOn <| Util.extractFocusIdFromRange <| focusFragmentToFocusId "config" lineFocus

                      else
                        Cmd.none
                    )

                Err error ->
                    ( { model | shared = { shared | templates = { data = toFailure error, error = detailedErrorToString error, show = shared.templates.show } } }, Errors.addError HandleError error )

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
                    ( model, Errors.addError HandleError error )

        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    let
                        secretsModel =
                            model.secretsModel

                        um =
                            { model | secretsModel = Pages.Secrets.Update.reinitializeSecretAdd secretsModel }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig
                                AlertsUpdate
                                (Alerts.Success "Success" (secret.name ++ " added to " ++ secretTypeToString secret.type_ ++ " secrets.") Nothing)
                                ( um.shared
                                , Cmd.none
                                )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        AddDeploymentResponse response ->
            case response of
                Ok ( _, deployment ) ->
                    let
                        deploymentModel =
                            model.deploymentModel

                        um =
                            { model | deploymentModel = Pages.Deployments.Update.reinitializeDeployment deploymentModel }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig
                                AlertsUpdate
                                (Alerts.Success "Success" (deployment.description ++ " submitted.") Nothing)
                                ( um.shared
                                , Cmd.none
                                )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        UpdateSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    let
                        secretsModel =
                            model.secretsModel

                        um =
                            { model | secretsModel = Pages.Secrets.Update.reinitializeSecretUpdate secretsModel secret }

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToast Alerts.successConfig
                                AlertsUpdate
                                (Alerts.Success "Success" (String.Extra.toSentenceCase <| secretTypeToString secret.type_ ++ " secret " ++ secret.name ++ " updated.") Nothing)
                                ( um.shared
                                , Cmd.none
                                )
                    in
                    ( { um | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

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

                        ( sharedWithAlert, cmd ) =
                            Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" alertMessage Nothing) ( model.shared, Browser.Navigation.pushUrl model.key redirectTo )
                    in
                    ( { model | shared = sharedWithAlert }, cmd )

                Err error ->
                    ( model, Errors.addError HandleError error )

        BuildGraphResponse _ _ buildNumber isRefresh response ->
            case response of
                Ok ( _, g ) ->
                    case model.legacyPage of
                        Pages.BuildGraph _ _ _ ->
                            let
                                ugm =
                                    { gm | buildNumber = buildNumber, graph = RemoteData.succeed g }

                                ubm =
                                    { bm | buildNumber = buildNumber }

                                um =
                                    { model
                                        | shared =
                                            updateRepoModels shared rm ubm ugm
                                    }
                            in
                            ( um
                            , renderBuildGraph um <| not isRefresh
                            )

                        _ ->
                            ( model
                            , Cmd.none
                            )

                Err error ->
                    ( { model | shared = { shared | repo = { rm | build = { bm | graph = { gm | graph = toFailure error } } } } }
                    , Errors.addError HandleError error
                    )

        -- Time
        AdjustTimeZone newZone ->
            ( { model | shared = { shared | zone = newZone } }
            , Cmd.none
            )

        AdjustTime newTime ->
            ( { model | shared = { shared | time = newTime } }
            , Cmd.none
            )

        Tick interval time ->
            case interval of
                OneSecond ->
                    let
                        ( favicon, updateFavicon ) =
                            refreshFavicon model.legacyPage model.shared.favicon rm.build.build
                    in
                    ( { model | shared = { shared | time = time, favicon = favicon } }
                    , Cmd.batch
                        [ updateFavicon
                        , refreshRenderBuildGraph model
                        ]
                    )

                FiveSecond ->
                    ( model, refreshPage model )

                OneSecondHidden ->
                    let
                        ( favicon, cmd ) =
                            refreshFavicon model.legacyPage model.shared.favicon rm.build.build
                    in
                    ( { model | shared = { shared | time = time, favicon = favicon } }, cmd )

                FiveSecondHidden data ->
                    ( model, refreshPageHidden model data )

        -- Components
        SecretsUpdate m ->
            Pages.Secrets.Update.update model m

        AddDeploymentUpdate m ->
            Pages.Deployments.Update.update model m

        AddScheduleUpdate m ->
            Pages.Schedules.Update.update model m

        -- Other
        HandleError error ->
            let
                ( sharedWithAlert, cmd ) =
                    Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error) ( model.shared, Cmd.none )
            in
            ( { model | shared = sharedWithAlert }, cmd )

        AlertsUpdate subMsg ->
            let
                ( sharedWithAlert, cmd ) =
                    Alerting.update Alerts.successConfig AlertsUpdate subMsg model.shared
            in
            ( { model | shared = sharedWithAlert }, cmd )

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
                        { model | shared = { shared | shift = True } }

                    else
                        model
            in
            ( m, Cmd.none )

        OnKeyUp key ->
            let
                m =
                    if key == "Shift" then
                        { model | shared = { shared | shift = False } }

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
            ( { model | shared = { shared | visibility = visibility, shift = False } }, cmd )

        PushUrl url ->
            ( model
            , Browser.Navigation.pushUrl model.key url
            )

        -- NoOp
        NoOp ->
            ( model, Cmd.none )


updateFromPage : Main.Pages.Msg.Msg -> Model -> ( Main.Pages.Model.Model, Cmd Msg )
updateFromPage msg model =
    case ( msg, model.page ) of
        ( Main.Pages.Msg.Login_ pageMsg, Main.Pages.Model.Login_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.Login_
                (Effect.map Main.Pages.Msg.Login_ >> fromPageEffect model)
                (Page.update (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        ( Main.Pages.Msg.AccountSettings_ pageMsg, Main.Pages.Model.AccountSettings_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.AccountSettings_
                        (Effect.map Main.Pages.Msg.AccountSettings_ >> fromPageEffect model)
                        (Page.update (Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Home_ pageMsg, Main.Pages.Model.Home_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Home_
                        (Effect.map Main.Pages.Msg.Home_ >> fromPageEffect model)
                        (Page.update (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.Deployments_ pageMsg, Main.Pages.Model.Deployments_ pageModel ) ->
            runWhenAuthenticated
                model
                (\user ->
                    Tuple.mapBoth
                        Main.Pages.Model.Deployments_
                        (Effect.map Main.Pages.Msg.Deployments_ >> fromPageEffect model)
                        (Page.update (Pages.Deployments_.page user model.shared (Route.fromUrl () model.url)) pageMsg pageModel)
                )

        ( Main.Pages.Msg.NotFound_ pageMsg, Main.Pages.Model.NotFound_ pageModel ) ->
            Tuple.mapBoth
                Main.Pages.Model.NotFound_
                (Effect.map Main.Pages.Msg.NotFound_ >> fromPageEffect model)
                (Page.update (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageMsg pageModel)

        -- when you add a new page, remember to fill in this case
        _ ->
            ( model.page
            , Cmd.none
            )


updateFromLayout : Main.Layouts.Msg.Msg -> Model -> ( Maybe Main.Layouts.Model.Model, Cmd Msg )
updateFromLayout msg model =
    let
        route : Route ()
        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout, msg ) of
        _ ->
            ( model.layout
            , Cmd.none
            )


toLayoutFromPage : Model -> Maybe (Layouts.Layout Msg)
toLayoutFromPage model =
    case model.page of
        Main.Pages.Model.Login_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.Account.Login_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Login_ >> Page))

        Main.Pages.Model.AccountSettings_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Account.Settings_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.AccountSettings_ >> Page))

        Main.Pages.Model.Home_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Home_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Home_ >> Page))

        Main.Pages.Model.Deployments_ pageModel ->
            Route.fromUrl () model.url
                |> toAuthProtectedPage model Pages.Deployments_.page
                |> Maybe.andThen (Page.layout pageModel)
                |> Maybe.map (Layouts.map (Main.Pages.Msg.Deployments_ >> Page))

        Main.Pages.Model.NotFound_ pageModel ->
            Route.fromUrl () model.url
                |> Pages.NotFound_.page model.shared
                |> Page.layout pageModel
                |> Maybe.map (Layouts.map (Main.Pages.Msg.NotFound_ >> Page))

        Main.Pages.Model.Redirecting_ ->
            Nothing

        Main.Pages.Model.Loading_ ->
            Nothing


toAuthProtectedPage : Model -> (Auth.User -> Shared.Model -> Route params -> Page.Page model msg) -> Route params -> Maybe (Page.Page model msg)
toAuthProtectedPage model toPage route =
    case Auth.onPageLoad model.shared (Route.fromUrl () model.url) of
        Auth.Action.LoadPageWithUser user ->
            Just (toPage user model.shared route)

        _ ->
            Nothing


hasActionTypeChanged : Auth.Action.Action user -> Auth.Action.Action user -> Bool
hasActionTypeChanged oldAction newAction =
    case ( newAction, oldAction ) of
        ( Auth.Action.LoadPageWithUser _, Auth.Action.LoadPageWithUser _ ) ->
            False

        ( Auth.Action.ShowLoadingPage _, Auth.Action.ShowLoadingPage _ ) ->
            False

        ( Auth.Action.ReplaceRoute _, Auth.Action.ReplaceRoute _ ) ->
            False

        ( Auth.Action.PushRoute _, Auth.Action.PushRoute _ ) ->
            False

        ( Auth.Action.LoadExternalUrl _, Auth.Action.LoadExternalUrl _ ) ->
            False

        ( _, _ ) ->
            True


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch <|
        [ Interop.onThemeChange decodeOnThemeChange
        , Interop.onGraphInteraction decodeOnGraphInteraction
        , onMouseDown "contextual-help" model ShowHideHelp
        , onMouseDown "identity" model ShowHideIdentity
        , onMouseDown "build-actions" model (ShowHideBuildMenu Nothing)
        , Browser.Events.onKeyDown (Json.Decode.map OnKeyDown (Json.Decode.field "key" Json.Decode.string))
        , Browser.Events.onKeyUp (Json.Decode.map OnKeyUp (Json.Decode.field "key" Json.Decode.string))
        , Browser.Events.onVisibilityChange VisibilityChanged

        -- , refreshSubscriptions model
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        view_ : View Msg
        view_ =
            toView model
                |> legacyLayout model
    in
    View.toBrowserDocument
        { shared = model.shared
        , route = Route.fromUrl () model.url
        , view = view_
        }


toView : Model -> View Msg
toView model =
    viewPage model


viewPage : Model -> View Msg
viewPage model =
    case model.page of
        Main.Pages.Model.Login_ pageModel ->
            Page.view (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.Login_
                |> View.map Page

        Main.Pages.Model.AccountSettings_ pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.AccountSettings_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home_ pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Home_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Home_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Deployments_ pageModel ->
            Auth.Action.view
                (\user ->
                    Page.view (Pages.Deployments_.page user model.shared (Route.fromUrl () model.url)) pageModel
                        |> View.map Main.Pages.Msg.Deployments_
                        |> View.map Page
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.view (Pages.NotFound_.page model.shared (Route.fromUrl () model.url)) pageModel
                |> View.map Main.Pages.Msg.NotFound_
                |> View.map Page

        Main.Pages.Model.Redirecting_ ->
            View.none

        Main.Pages.Model.Loading_ ->
            Auth.viewLoadingPage model.shared (Route.fromUrl () model.url)
                |> View.map never


legacyLayout model v =
    -- todo: move this into a site-wide Layout
    { v
        | body =
            [ lazy2 viewHeader
                model.shared.session
                { feedbackLink = model.shared.velaFeedbackURL
                , docsLink = model.shared.velaDocsURL
                , theme = model.shared.theme
                , help = helpArgs model
                , showId = model.shared.showIdentity
                }
            , lazy2 Nav.viewNav model navMsgs
            , main_ [ class "content-wrap" ]
                (viewUtil model
                    :: v.body
                )
            , footer [] [ lazy viewAlerts model.shared.toasties ]
            ]
    }



-- INTERNALS


fromPageEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Pages.Msg.Msg -> Cmd Msg
fromPageEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Page effect)


fromLayoutEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Main.Layouts.Msg.Msg -> Cmd Msg
fromLayoutEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Layout effect)


fromSharedEffect : { model | key : Browser.Navigation.Key, url : Url, shared : Shared.Model } -> Effect Shared.Msg -> Cmd Msg
fromSharedEffect model effect =
    Effect.toCmd
        { key = model.key
        , url = model.url
        , shared = model.shared
        , fromSharedMsg = Shared
        , batch = Batch
        , toCmd = Task.succeed >> Task.perform identity
        }
        (Effect.map Shared effect)



-- URL HOOKS FOR PAGES


toPageUrlHookCmd : Model -> { from : Route (), to : Route () } -> Cmd Msg
toPageUrlHookCmd model routes =
    let
        toCommands messages =
            messages
                |> List.map (Task.succeed >> Task.perform identity)
                |> Cmd.batch
    in
    case model.page of
        Main.Pages.Model.Login_ pageModel ->
            Page.toUrlMessages routes (Pages.Account.Login_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.Login_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.AccountSettings_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Account.Settings_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.AccountSettings_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Home_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Home_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Home_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.Deployments_ pageModel ->
            Auth.Action.command
                (\user ->
                    Page.toUrlMessages routes (Pages.Deployments_.page user model.shared (Route.fromUrl () model.url))
                        |> List.map Main.Pages.Msg.Deployments_
                        |> List.map Page
                        |> toCommands
                )
                (Auth.onPageLoad model.shared (Route.fromUrl () model.url))

        Main.Pages.Model.NotFound_ pageModel ->
            Page.toUrlMessages routes (Pages.NotFound_.page model.shared (Route.fromUrl () model.url))
                |> List.map Main.Pages.Msg.NotFound_
                |> List.map Page
                |> toCommands

        Main.Pages.Model.Redirecting_ ->
            Cmd.none

        Main.Pages.Model.Loading_ ->
            Cmd.none


toLayoutUrlHookCmd : Model -> Model -> { from : Route (), to : Route () } -> Cmd Msg
toLayoutUrlHookCmd oldModel model routes =
    let
        toCommands messages =
            if shouldFireUrlChangedEvents then
                messages
                    |> List.map (Task.succeed >> Task.perform identity)
                    |> Cmd.batch

            else
                Cmd.none

        shouldFireUrlChangedEvents =
            hasNavigatedWithinNewLayout
                { from = toLayoutFromPage oldModel
                , to = toLayoutFromPage model
                }

        route =
            Route.fromUrl () model.url
    in
    case ( toLayoutFromPage model, model.layout ) of
        ( Just (Layouts.Default props), Just (Main.Layouts.Model.Default layoutModel) ) ->
            Layout.toUrlMessages routes (Layouts.Default.layout props model.shared route)
                |> List.map Main.Layouts.Msg.Default
                |> List.map Layout
                |> toCommands

        _ ->
            Cmd.none


hasNavigatedWithinNewLayout : { from : Maybe (Layouts.Layout msg), to : Maybe (Layouts.Layout msg) } -> Bool
hasNavigatedWithinNewLayout { from, to } =
    let
        isRelated maybePair =
            case maybePair of
                _ ->
                    False
    in
    List.any isRelated
        [ Maybe.map2 Tuple.pair from to
        , Maybe.map2 Tuple.pair to from
        ]


isAuthProtected : Route.Path.Path -> Bool
isAuthProtected routePath =
    case routePath of
        Route.Path.Login_ ->
            False

        Route.Path.AccountSettings_ ->
            True

        Route.Path.Logout_ ->
            True

        Route.Path.Authenticate_ ->
            False

        Route.Path.Home_ ->
            True

        Route.Path.Deployments_ ->
            True

        Route.Path.NotFound_ ->
            False



-- LEGACY HELPERS (SUBSCRIPTIONS)


{-| decodeOnThemeChange : takes interaction in json and decodes it into a SetTheme Msg
-}
decodeOnThemeChange : Json.Decode.Value -> Msg
decodeOnThemeChange inTheme =
    case Json.Decode.decodeValue decodeTheme inTheme of
        Ok theme ->
            SetTheme theme

        Err _ ->
            SetTheme Dark


{-| decodeOnGraphInteraction : takes interaction in json and decodes it into a OnBuildGraphInteraction Msg
-}
decodeOnGraphInteraction : Json.Decode.Value -> Msg
decodeOnGraphInteraction interaction =
    case Json.Decode.decodeValue decodeGraphInteraction interaction of
        Ok interaction_ ->
            OnBuildGraphInteraction interaction_

        Err _ ->
            NoOp


{-| onMouseDown : takes model and returns subscriptions for handling onMouseDown events at the browser level
-}
onMouseDown : String -> Model -> (Maybe Bool -> Msg) -> Sub Msg
onMouseDown targetId model triggerMsg =
    if model.shared.showHelp then
        Browser.Events.onMouseDown (outsideTarget targetId <| triggerMsg <| Just False)

    else if model.shared.showIdentity then
        Browser.Events.onMouseDown (outsideTarget targetId <| triggerMsg <| Just False)

    else if List.length model.shared.buildMenuOpen > 0 then
        Browser.Events.onMouseDown (outsideTarget targetId <| triggerMsg <| Just False)

    else
        Sub.none


{-| outsideTarget : returns decoder for handling clicks that occur from outside the currently focused/open dropdown
-}
outsideTarget : String -> Msg -> Json.Decode.Decoder Msg
outsideTarget targetId msg =
    Json.Decode.field "target" (isOutsideTarget targetId)
        |> Json.Decode.andThen
            (\isOutside ->
                if isOutside then
                    Json.Decode.succeed msg

                else
                    Json.Decode.fail "inside dropdown"
            )


{-| isOutsideTarget : returns decoder for determining if click target occurred from within a specified element
-}
isOutsideTarget : String -> Json.Decode.Decoder Bool
isOutsideTarget targetId =
    Json.Decode.oneOf
        [ Json.Decode.field "id" Json.Decode.string
            |> Json.Decode.andThen
                (\id ->
                    if targetId == id then
                        -- found match by id
                        Json.Decode.succeed False

                    else
                        -- try next decoder
                        Json.Decode.fail "continue"
                )
        , Json.Decode.lazy (\_ -> isOutsideTarget targetId |> Json.Decode.field "parentNode")

        -- fallback if all previous decoders failed
        , Json.Decode.succeed True
        ]



-- LEGACY HELPERS (PAGE INIT+LOADING)


{-| loadSourceReposPage : takes model

    updates the model based on app initialization state and loads source repos page resources

-}
loadSourceReposPage : Model -> ( Model, Cmd Msg )
loadSourceReposPage model =
    let
        shared =
            model.shared
    in
    case model.shared.sourceRepos of
        NotAsked ->
            ( { model | legacyPage = Pages.SourceRepositories, shared = { shared | sourceRepos = Loading } }
            , Cmd.batch
                [ Api.Api.try SourceRepositoriesResponse <| Api.Operations.getSourceRepositories model
                , getCurrentUser model
                ]
            )

        Failure _ ->
            ( { model | legacyPage = Pages.SourceRepositories, shared = { shared | sourceRepos = Loading } }
            , Cmd.batch
                [ Api.Api.try SourceRepositoriesResponse <| Api.Operations.getSourceRepositories model
                , getCurrentUser model
                ]
            )

        _ ->
            ( { model | legacyPage = Pages.SourceRepositories }, getCurrentUser model )


{-| loadOrgReposPage : takes model

    updates the model based on app initialization state and loads org repos page resources

-}
loadOrgReposPage : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadOrgReposPage model org maybePage maybePerPage =
    case model.shared.repo.orgRepos.orgRepos of
        NotAsked ->
            ( { model | legacyPage = Pages.OrgRepositories org maybePage maybePerPage }
            , Api.Api.try OrgRepositoriesResponse <| Api.Operations.getOrgRepositories model maybePage maybePerPage org
            )

        Failure _ ->
            ( { model | legacyPage = Pages.OrgRepositories org maybePage maybePerPage }
            , Api.Api.try OrgRepositoriesResponse <| Api.Operations.getOrgRepositories model maybePage maybePerPage org
            )

        _ ->
            ( { model | legacyPage = Pages.OrgRepositories org maybePage maybePerPage }
            , Cmd.batch
                [ getCurrentUser model
                , Api.Api.try OrgRepositoriesResponse <| Api.Operations.getOrgRepositories model maybePage maybePerPage org
                ]
            )


{-| loadOverviewPage : takes model

    updates the model based on app initialization state and loads overview page resources

-}
loadOverviewPage : Model -> ( Model, Cmd Msg )
loadOverviewPage model =
    ( { model
        | legacyPage = Pages.Overview
      }
    , Cmd.batch
        [ getCurrentUser model
        ]
    )


{-| loadOrgSubPage : takes model org and page destination

    updates the model based on app initialization state and loads org page resources

-}
loadOrgSubPage : Model -> Org -> Page -> ( Model, Cmd Msg )
loadOrgSubPage model org toPage =
    let
        sm =
            model.shared

        rm =
            sm.repo

        builds =
            rm.builds

        secretsModel =
            model.secretsModel

        fetchSecrets : Org -> Cmd Msg
        fetchSecrets o =
            getAllOrgSecrets model "native" o

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
                    , shared =
                        { sm
                            | repo =
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
                            | shared =
                                { sm
                                    | repo =
                                        { rm
                                            | builds =
                                                { builds | maybePage = maybePage, maybePerPage = maybePerPage, maybeEvent = maybeEvent }
                                        }
                                }
                          }
                        , getOrgBuilds model o maybePage maybePerPage maybeEvent
                        )

                    Pages.OrgSecrets _ o _ _ ->
                        ( model, fetchSecrets o )

                    _ ->
                        ( model, Cmd.none )
    in
    ( { loadModel | legacyPage = toPage }, loadCmd )


{-| loadRepoSubPage : takes model org repo and page destination

    updates the model based on app initialization state and loads repo page resources

-}
loadRepoSubPage : Model -> Org -> Repo -> Page -> ( Model, Cmd Msg )
loadRepoSubPage model org repo toPage =
    let
        sm =
            model.shared

        rm =
            sm.repo

        builds =
            rm.builds

        secretsModel =
            model.secretsModel

        schedulesModel =
            model.schedulesModel

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
                    , schedulesModel =
                        let
                            -- update schedules pagination
                            ( maybePage, maybePerPage ) =
                                case toPage of
                                    Pages.Schedules _ _ maybePage_ maybePerPage_ ->
                                        ( maybePage_, maybePerPage_ )

                                    _ ->
                                        ( Nothing, Nothing )
                        in
                        { schedulesModel
                            | schedules = Loading
                            , schedule = Loading
                            , org = org
                            , repo = repo
                            , maybePage = maybePage
                            , maybePerPage = maybePerPage
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
                            , repo_settings = model.shared.repo.repo
                            , form = form
                        }
                    , shared =
                        { sm
                            | repo =
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
                  }
                , Cmd.batch
                    [ getCurrentUser model
                    , getRepo model org repo
                    , case toPage of
                        Pages.RepositoryBuilds o r maybePage maybePerPage maybeEvent ->
                            getBuilds model o r maybePage maybePerPage maybeEvent

                        Pages.RepositoryBuildsPulls o r maybePage maybePerPage ->
                            getBuilds model o r maybePage maybePerPage (Just "pull_request")

                        Pages.RepositoryBuildsTags o r maybePage maybePerPage ->
                            getBuilds model o r maybePage maybePerPage (Just "tag")

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
                        Pages.Schedules o r maybePage maybePerPage ->
                            if Util.checkScheduleAllowlist o r model.shared.velaScheduleAllowlist then
                                getSchedules model o r maybePage maybePerPage

                            else
                                Cmd.none

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
                            | shared =
                                { sm
                                    | repo =
                                        { rm
                                            | builds =
                                                { builds | maybePage = maybePage, maybePerPage = maybePerPage, maybeEvent = maybeEvent }
                                        }
                                }
                          }
                        , getBuilds model o r maybePage maybePerPage maybeEvent
                        )

                    Pages.RepoSecrets _ o r _ _ ->
                        ( model, fetchSecrets o r )

                    Pages.Schedules o r maybePage maybePerPage ->
                        ( { model
                            | schedulesModel =
                                { schedulesModel
                                    | maybePage = maybePage
                                    , maybePerPage = maybePerPage
                                }
                          }
                        , if Util.checkScheduleAllowlist o r model.shared.velaScheduleAllowlist then
                            getSchedules model o r maybePage maybePerPage

                          else
                            Cmd.none
                        )

                    Pages.Hooks o r maybePage maybePerPage ->
                        ( { model
                            | shared =
                                { sm
                                    | repo =
                                        rm
                                            |> updateHooksPage maybePage
                                            |> updateHooksPerPage maybePerPage
                                }
                          }
                        , getHooks model o r maybePage maybePerPage
                        )

                    Pages.RepoSettings o r ->
                        ( model, getRepo model o r )

                    Pages.PromoteDeployment o r deploymentNumber ->
                        ( model, getDeployment model o r deploymentNumber )

                    Pages.AddDeployment o r ->
                        ( model, getRepo model o r )

                    -- page is not a repo subpage
                    _ ->
                        ( model, Cmd.none )
    in
    ( { loadModel
        | legacyPage = toPage
      }
    , loadCmd
    )


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


{-| loadRepoBuildsTagsPage : takes model org and repo and loads the appropriate builds for the tag event only.
loadRepoBuildsTagsPage Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.
-}
loadRepoBuildsTagsPage : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> ( Model, Cmd Msg )
loadRepoBuildsTagsPage model org repo maybePage maybePerPage =
    loadRepoSubPage model org repo <| Pages.RepositoryBuildsTags org repo maybePage maybePerPage


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


{-| loadRepoSchedulesPage : takes model org and repo and loads the page for managing repo schedules
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
        | legacyPage =
            Pages.OrgSecrets engine org maybePage maybePerPage
        , secretsModel =
            { secretsModel
                | orgSecrets = Loading
                , org = org
                , repo = ""
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
        | legacyPage =
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
        | legacyPage = Pages.AddOrgSecret engine org
        , secretsModel =
            { secretsModel
                | sharedSecrets = Loading
                , org = org
                , engine = engine
                , type_ = Vela.OrgSecret
            }
      }
    , getCurrentUser model
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
        | legacyPage = Pages.AddRepoSecret engine org repo
        , secretsModel =
            { secretsModel
                | org = org
                , repo = repo
                , engine = engine
                , type_ = Vela.RepoSecret
            }
      }
    , getCurrentUser model
    )


{-| loadAddSchedulePage : takes model org and repo and loads the page for adding schedules
-}
loadAddSchedulePage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadAddSchedulePage model org repo =
    -- Fetch secrets from Api
    let
        scheduleModel =
            Pages.Schedules.Update.reinitializeScheduleAdd model.schedulesModel
    in
    ( { model
        | legacyPage = Pages.AddSchedule org repo
        , schedulesModel =
            { scheduleModel
                | org = org
                , repo = repo
                , deleteState = Pages.Schedules.Model.NotAsked_
            }
      }
    , getCurrentUser model
    )


{-| loadEditSchedulePage : takes model org and repo and loads the page for editing schedules
-}
loadEditSchedulePage : Model -> Org -> ScheduleName -> Repo -> ( Model, Cmd Msg )
loadEditSchedulePage model org repo id =
    -- Fetch schedules from Api
    let
        scheduleModel =
            model.schedulesModel
    in
    ( { model
        | legacyPage = Pages.Schedule org repo id
        , schedulesModel =
            { scheduleModel
                | org = org
                , repo = repo
                , deleteState = Pages.Schedules.Model.NotAsked_
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , if Util.checkScheduleAllowlist org repo model.shared.velaScheduleAllowlist then
            getSchedule model org repo id

          else
            Cmd.none
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
        | legacyPage = Pages.AddSharedSecret engine org team
        , secretsModel =
            { secretsModel
                | org = org
                , team = team
                , engine = engine
                , type_ = Vela.SharedSecret
                , form = secretsModel.form
            }
      }
    , getCurrentUser model
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
        | legacyPage = Pages.OrgSecret engine org name
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
        | legacyPage = Pages.RepoSecret engine org repo name
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
        | legacyPage = Pages.SharedSecret engine org team name
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
            isSameBuild ( org, repo, buildNumber ) model.legacyPage

        sameResource =
            case model.legacyPage of
                Pages.Build _ _ _ _ ->
                    True

                _ ->
                    False

        -- if build has changed, set build fields in the model
        um =
            if not sameBuild then
                setBuild org repo buildNumber sameResource model

            else
                model

        sm =
            um.shared

        rm =
            sm.repo
    in
    -- load page depending on build change
    ( { um
        | legacyPage = Pages.Build org repo buildNumber lineFocus

        -- set repo fields
        , shared =
            { sm
                | repo =
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


{-| loadBuildGraphPage : takes model org, repo, and build number and loads the appropriate build graph resources.
-}
loadBuildGraphPage : Model -> Org -> Repo -> BuildNumber -> ( Model, Cmd Msg )
loadBuildGraphPage model org repo buildNumber =
    let
        -- get resource transition information
        sameBuild =
            isSameBuild ( org, repo, buildNumber ) model.legacyPage

        sameResource =
            case model.legacyPage of
                Pages.BuildGraph _ _ _ ->
                    True

                _ ->
                    False

        -- if build has changed, set build fields in the model
        mm =
            if not sameBuild then
                setBuild org repo buildNumber sameResource model

            else
                model

        usm =
            model.shared

        urm =
            usm.repo

        ubm =
            urm.build

        gm =
            ubm.graph

        graph =
            if sameBuild then
                RemoteData.unwrap RemoteData.Loading (\g_ -> RemoteData.succeed g_) gm.graph

            else
                RemoteData.Loading

        focusedNode =
            if sameBuild then
                gm.focusedNode

            else
                -1

        um =
            { mm
                | legacyPage = Pages.BuildGraph org repo buildNumber
                , shared =
                    { usm
                        | repo = { urm | build = { ubm | graph = { gm | graph = graph, focusedNode = focusedNode } } }
                    }
            }
    in
    ( um
      -- do not load resources if transition is auto refresh, line focus, etc
      -- MUST render graph here, or clicking on nodes won't cause an immediate change
    , if sameBuild && sameResource then
        renderBuildGraph um True

      else
        Cmd.batch
            [ getBuilds um org repo Nothing Nothing Nothing
            , getBuild um org repo buildNumber
            , getAllBuildSteps um org repo buildNumber Nothing False
            , getBuildGraph um org repo buildNumber False
            , renderBuildGraph um <| not sameResource
            ]
    )


{-| loadBuildServicesPage : takes model org, repo, and build number and loads the appropriate build services.
-}
loadBuildServicesPage : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> ( Model, Cmd Msg )
loadBuildServicesPage model org repo buildNumber lineFocus =
    let
        -- get resource transition information
        sameBuild =
            isSameBuild ( org, repo, buildNumber ) model.legacyPage

        sameResource =
            case model.legacyPage of
                Pages.BuildServices _ _ _ _ ->
                    True

                _ ->
                    False

        -- if build has changed, set build fields in the model
        um =
            if not sameBuild then
                setBuild org repo buildNumber sameResource model

            else
                model

        usm =
            um.shared

        urm =
            usm.repo
    in
    ( { um
        | legacyPage = Pages.BuildServices org repo buildNumber lineFocus

        -- set repo fields
        , shared =
            { usm
                | repo =
                    urm
                        -- update services using line focus
                        |> updateBuildServices
                            (RemoteData.unwrap Loading
                                (\services ->
                                    RemoteData.succeed <| focusAndClear services lineFocus
                                )
                                urm.build.services.services
                            )
                        -- update line focus in the model
                        |> updateBuildServicesFocusFragment (Maybe.map (\l -> "#" ++ l) lineFocus)
                        -- reset following step
                        |> updateBuildStepsFollowing 0
            }
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
        sm =
            model.shared

        -- get resource transition information
        sameBuild =
            isSameBuild ( org, repo, buildNumber ) model.legacyPage

        sameResource =
            case model.legacyPage of
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
            sm.pipeline
    in
    ( { m
        | legacyPage = Pages.BuildPipeline org repo buildNumber expand lineFocus
        , shared =
            { sm
                | pipeline =
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
                        sm.templates

                    else
                        { data = Loading, error = "", show = True }
            }
      }
    , Cmd.batch <|
        -- do not load resources if transition is auto refresh, line focus, etc
        if sameBuild && sameResource then
            []

        else if sameBuild then
            -- same build, most likely a tab switch
            case model.shared.repo.build.build of
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



-- LEGACY HELPERS (PAGE MSGS)
--todo: these shouldnt be needed with Shared.Msg


{-| navMsgs : prepares the input record required for the nav component to route Msgs back to Main.elm
-}
navMsgs : Nav.Msgs Msg
navMsgs =
    Nav.Msgs FetchSourceRepositories ToggleFavorite RefreshSettings RefreshHooks RefreshSecrets ApproveBuild RestartBuild CancelBuild


{-| sourceReposMsgs : prepares the input record required for the SourceRepos page to route Msgs back to Main.elm
-}
sourceReposMsgs : Pages.SourceRepos.Msgs Msg
sourceReposMsgs =
    Pages.SourceRepos.Msgs SearchSourceRepos EnableRepo EnableRepos ToggleFavorite


{-| repoSettingsMsgs : prepares the input record required for the Settings page to route Msgs back to Main.elm
-}
repoSettingsMsgs : Pages.RepoSettings.Msgs Msg
repoSettingsMsgs =
    Pages.RepoSettings.Msgs UpdateRepoEvent UpdateRepoAccess UpdateRepoForkPolicy UpdateRepoLimit ChangeRepoLimit UpdateRepoTimeout ChangeRepoTimeout UpdateRepoCounter ChangeRepoCounter DisableRepo EnableRepo Copy ChownRepo RepairRepo UpdateRepoPipelineType


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
    , approveBuild = ApproveBuild
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
    , buildGraphMsgs =
        { refresh = BuildGraphRefresh
        , rotate = BuildGraphRotate
        , showServices = BuildGraphShowServices
        , showSteps = BuildGraphShowSteps
        , updateFilter = BuildGraphUpdateFilter
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



-- todo: these shouldnt be needed to use the Effect Api
-- LEGACY HELPERS (API CALLS)


{-| getToken attempts to retrieve a new access token
-}
getToken : Model -> Cmd Msg
getToken model =
    Api.Api.try TokenResponse <| Api.Operations.getToken model


getLogout : Model -> Cmd Msg
getLogout model =
    Api.Api.try LogoutResponse <| Api.Operations.getLogout model


getCurrentUser : Model -> Cmd Msg
getCurrentUser model =
    case model.shared.user of
        NotAsked ->
            Api.Api.try CurrentUserResponse <| Api.Operations.getCurrentUser model

        _ ->
            Cmd.none


getHooks : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getHooks model org repo maybePage maybePerPage =
    Api.Api.try HooksResponse <| Api.Operations.getHooks model maybePage maybePerPage org repo


redeliverHook : Model -> Org -> Repo -> HookNumber -> Cmd Msg
redeliverHook model org repo hookNumber =
    Api.Api.try (RedeliverHookResponse org repo hookNumber) <| Api.Operations.redeliverHook model org repo hookNumber


getRepo : Model -> Org -> Repo -> Cmd Msg
getRepo model org repo =
    Api.Api.try RepoResponse <| Api.Operations.getRepo model org repo


getOrgRepos : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getOrgRepos model org maybePage maybePerPage =
    Api.Api.try OrgRepositoriesResponse <| Api.Operations.getOrgRepositories model maybePage maybePerPage org


getOrgBuilds : Model -> Org -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Cmd Msg
getOrgBuilds model org maybePage maybePerPage maybeEvent =
    Api.Api.try (OrgBuildsResponse org) <| Api.Operations.getOrgBuilds model maybePage maybePerPage maybeEvent org


getBuilds : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Cmd Msg
getBuilds model org repo maybePage maybePerPage maybeEvent =
    Api.Api.try (BuildsResponse org repo) <| Api.Operations.getBuilds model maybePage maybePerPage maybeEvent org repo


getSchedules : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getSchedules model org repo maybePage maybePerPage =
    Api.Api.try (SchedulesResponse org repo) <| Api.Operations.getSchedules model maybePage maybePerPage org repo


getBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.Api.try (BuildResponse org repo) <| Api.Operations.getBuild model org repo buildNumber


getBuildAndPipeline : Model -> Org -> Repo -> BuildNumber -> Maybe ExpandTemplatesQuery -> Cmd Msg
getBuildAndPipeline model org repo buildNumber expand =
    Api.Api.try (BuildAndPipelineResponse org repo expand) <| Api.Operations.getBuild model org repo buildNumber


getBuildGraph : Model -> Org -> Repo -> BuildNumber -> Bool -> Cmd Msg
getBuildGraph model org repo buildNumber refresh =
    Api.Api.try (BuildGraphResponse org repo buildNumber refresh) <| Api.Operations.getBuildGraph model org repo buildNumber


getDeployment : Model -> Org -> Repo -> DeploymentId -> Cmd Msg
getDeployment model org repo deploymentNumber =
    Api.Api.try DeploymentResponse <| Api.Operations.getDeployment model org repo <| Just deploymentNumber


getDeployments : Model -> Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Cmd Msg
getDeployments model org repo maybePage maybePerPage =
    Api.Api.try (DeploymentsResponse org repo) <| Api.Operations.getDeployments model maybePage maybePerPage org repo


getAllBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Bool -> Cmd Msg
getAllBuildSteps model org repo buildNumber logFocus refresh =
    Api.Api.tryAll (StepsResponse org repo buildNumber logFocus refresh) <| Api.Operations.getAllSteps model org repo buildNumber


getBuildStepLogs : Model -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd Msg
getBuildStepLogs model org repo buildNumber stepNumber logFocus refresh =
    Api.Api.try (StepLogResponse stepNumber logFocus refresh) <| Api.Operations.getStepLogs model org repo buildNumber stepNumber


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
    Api.Api.tryAll (ServicesResponse org repo buildNumber logFocus refresh) <| Api.Operations.getAllServices model org repo buildNumber


getBuildServiceLogs : Model -> Org -> Repo -> BuildNumber -> ServiceNumber -> FocusFragment -> Bool -> Cmd Msg
getBuildServiceLogs model org repo buildNumber serviceNumber logFocus refresh =
    Api.Api.try (ServiceLogResponse serviceNumber logFocus refresh) <| Api.Operations.getServiceLogs model org repo buildNumber serviceNumber


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


approveBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
approveBuild model org repo buildNumber =
    Api.Api.try (ApprovedBuildResponse org repo buildNumber) <| Api.Operations.approveBuild model org repo buildNumber


restartBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
restartBuild model org repo buildNumber =
    Api.Api.try (RestartedBuildResponse org repo buildNumber) <| Api.Operations.restartBuild model org repo buildNumber


cancelBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
cancelBuild model org repo buildNumber =
    Api.Api.try (CancelBuildResponse org repo buildNumber) <| Api.Operations.cancelBuild model org repo buildNumber


getRepoSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Repo
    -> Cmd Msg
getRepoSecrets model maybePage maybePerPage engine org repo =
    Api.Api.try RepoSecretsResponse <| Api.Operations.getSecrets model maybePage maybePerPage engine "repo" org repo


getAllRepoSecrets :
    Model
    -> Engine
    -> Org
    -> Repo
    -> Cmd Msg
getAllRepoSecrets model engine org repo =
    Api.Api.tryAll RepoSecretsResponse <| Api.Operations.getAllSecrets model engine "repo" org repo


getOrgSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Cmd Msg
getOrgSecrets model maybePage maybePerPage engine org =
    Api.Api.try OrgSecretsResponse <| Api.Operations.getSecrets model maybePage maybePerPage engine "org" org "*"


getAllOrgSecrets :
    Model
    -> Engine
    -> Org
    -> Cmd Msg
getAllOrgSecrets model engine org =
    Api.Api.tryAll OrgSecretsResponse <| Api.Operations.getAllSecrets model engine "org" org "*"


getSharedSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Org
    -> Team
    -> Cmd Msg
getSharedSecrets model maybePage maybePerPage engine org team =
    Api.Api.try SharedSecretsResponse <| Api.Operations.getSecrets model maybePage maybePerPage engine "shared" org team


getSecret : Model -> Engine -> Type -> Org -> Key -> Name -> Cmd Msg
getSecret model engine type_ org key name =
    Api.Api.try SecretResponse <| Api.Operations.getSecret model engine type_ org key name


getSchedule : Model -> Org -> Repo -> ScheduleName -> Cmd Msg
getSchedule model org repo id =
    Api.Api.try ScheduleResponse <| Api.Operations.getSchedule model org repo id


{-| getPipelineConfig : takes model, org, repo and ref and fetches a pipeline configuration from the API.
-}
getPipelineConfig : Model -> Org -> Repo -> Ref -> FocusFragment -> Bool -> Cmd Msg
getPipelineConfig model org repo ref lineFocus refresh =
    Api.Api.try (GetPipelineConfigResponse lineFocus refresh) <| Api.Operations.getPipelineConfig model org repo ref


{-| expandPipelineConfig : takes model, org, repo and ref and expands a pipeline configuration via the API.
-}
expandPipelineConfig : Model -> Org -> Repo -> Ref -> FocusFragment -> Bool -> Cmd Msg
expandPipelineConfig model org repo ref lineFocus refresh =
    Api.Api.tryString (ExpandPipelineConfigResponse lineFocus refresh) <| Api.Operations.expandPipelineConfig model org repo ref


{-| getPipelineTemplates : takes model, org, repo and ref and fetches templates used in a pipeline configuration from the API.
-}
getPipelineTemplates : Model -> Org -> Repo -> Ref -> FocusFragment -> Bool -> Cmd Msg
getPipelineTemplates model org repo ref lineFocus refresh =
    Api.Api.try (GetPipelineTemplatesResponse lineFocus refresh) <| Api.Operations.getPipelineTemplates model org repo ref



-- REFRESH
-- todo: refactor this to msg or Effect msg to move it into Refresh.elm


{-| refreshSubscriptions : takes model and returns the subscriptions for automatically refreshing page data
-}
refreshSubscriptions : Model -> Sub Msg
refreshSubscriptions model =
    Sub.batch <|
        case model.shared.visibility of
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
                    ( newFavicon, Interop.setFavicon <| Json.Encode.string newFavicon )

                else
                    ( currentFavicon, Cmd.none )

            _ ->
                ( currentFavicon, Cmd.none )

    else if currentFavicon /= defaultFavicon then
        ( defaultFavicon, Interop.setFavicon <| Json.Encode.string defaultFavicon )

    else
        ( currentFavicon, Cmd.none )


{-| refreshPage : refreshes Vela data based on current page and build status
-}
refreshPage : Model -> Cmd Msg
refreshPage model =
    let
        page =
            model.legacyPage
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
                , refreshStepLogs model org repo buildNumber model.shared.repo.build.steps.steps Nothing
                ]

        Pages.BuildServices org repo buildNumber focusFragment ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildServices model org repo buildNumber focusFragment
                , refreshServiceLogs model org repo buildNumber model.shared.repo.build.services.services Nothing
                ]

        Pages.BuildPipeline org repo buildNumber _ _ ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                ]

        Pages.BuildGraph org repo buildNumber ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildGraph model org repo buildNumber
                ]

        Pages.Hooks org repo maybePage maybePerPage ->
            getHooks model org repo maybePage maybePerPage

        Pages.OrgSecrets engine org maybePage maybePerPage ->
            Cmd.batch
                [ getOrgSecrets model maybePage maybePerPage engine org
                , getSharedSecrets model maybePage maybePerPage engine org "*"
                ]

        Pages.RepoSecrets engine org repo maybePage maybePerPage ->
            getRepoSecrets model maybePage maybePerPage engine org repo

        Pages.SharedSecrets engine org team maybePage maybePerPage ->
            getSharedSecrets model maybePage maybePerPage engine org team

        _ ->
            Cmd.none


{-| refreshPageHidden : refreshes Vela data based on current page and build status when tab is not visible
-}
refreshPageHidden : Model -> RefreshData -> Cmd Msg
refreshPageHidden model _ =
    let
        page =
            model.legacyPage
    in
    case page of
        Pages.Build org repo buildNumber _ ->
            refreshBuild model org repo buildNumber

        _ ->
            Cmd.none


{-| refreshData : takes model and extracts data needed to refresh the page
-}
refreshData : Model -> RefreshData
refreshData model =
    let
        rm =
            model.shared.repo

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
    if shouldRefresh model.legacyPage model.shared.repo.build then
        getBuild model org repo buildNumber

    else
        Cmd.none


{-| refreshBuildSteps : takes model org repo and build number and refreshes the build steps based on step status
-}
refreshBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildSteps model org repo buildNumber focusFragment =
    if shouldRefresh model.legacyPage model.shared.repo.build then
        getAllBuildSteps model org repo buildNumber focusFragment True

    else
        Cmd.none


{-| refreshBuildServices : takes model org repo and build number and refreshes the build services based on service status
-}
refreshBuildServices : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildServices model org repo buildNumber focusFragment =
    if shouldRefresh model.legacyPage model.shared.repo.build then
        getAllBuildServices model org repo buildNumber focusFragment True

    else
        Cmd.none


{-| refreshBuildGraph : takes model org repo and build number and refreshes the build graph if necessary
-}
refreshBuildGraph : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
refreshBuildGraph model org repo buildNumber =
    if shouldRefresh model.legacyPage model.shared.repo.build then
        getBuildGraph model org repo buildNumber True

    else
        Cmd.none


{-| refreshRenderBuildGraph : takes model and refreshes the build graph render if necessary
-}
refreshRenderBuildGraph : Model -> Cmd Msg
refreshRenderBuildGraph model =
    case model.legacyPage of
        Pages.BuildGraph _ _ _ ->
            renderBuildGraph model False

        _ ->
            Cmd.none


{-| shouldRefresh : takes build and returns true if a refresh is required
-}
shouldRefresh : Page -> BuildModel -> Bool
shouldRefresh page build =
    case build.build of
        Success bld ->
            -- build is incomplete
            (not <| isComplete bld.status)
                -- any steps or services are incomplete
                || (case page of
                        -- check steps when viewing build tab
                        Pages.Build _ _ _ _ ->
                            case build.steps.steps of
                                Success steps ->
                                    List.any (\s -> not <| isComplete s.status) steps

                                -- do not use unsuccessful states to dictate refresh
                                NotAsked ->
                                    False

                                Failure _ ->
                                    False

                                Loading ->
                                    False

                        -- check services when viewing services tab
                        Pages.BuildServices _ _ _ _ ->
                            case build.services.services of
                                Success services ->
                                    List.any (\s -> not <| isComplete s.status) services

                                -- do not use unsuccessful states to dictate refresh
                                NotAsked ->
                                    False

                                Failure _ ->
                                    False

                                Loading ->
                                    False

                        -- check graph nodes when viewing graph tab
                        Pages.BuildGraph _ _ _ ->
                            case build.graph.graph of
                                Success graph ->
                                    List.any (\( _, n ) -> not <| isComplete (stringToStatus n.status)) (Dict.toList graph.nodes)

                                -- do not use unsuccessful states to dictate refresh
                                NotAsked ->
                                    False

                                Failure _ ->
                                    False

                                Loading ->
                                    False

                        _ ->
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
    in
    if shouldRefresh model.legacyPage model.shared.repo.build then
        getBuildStepsLogs model org repo buildNumber stepsToRefresh focusFragment True

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
    in
    if shouldRefresh model.legacyPage model.shared.repo.build then
        getBuildServicesLogs model org repo buildNumber servicesToRefresh focusFragment True

    else
        Cmd.none



-- RANDOM HELPERS
-- LOGS


{-| updateStepLogs : takes model and incoming log and updates the list of step logs if necessary
-}
updateStepLogs : Model -> Log -> Model
updateStepLogs model incomingLog =
    let
        sm =
            model.shared

        rm =
            sm.repo

        build =
            rm.build

        logs =
            build.steps.logs

        logExists =
            List.member incomingLog.id <| (List.map (\log -> log.id) <| Util.successful logs)
    in
    if logExists then
        { model | shared = { sm | repo = updateBuildStepsLogs (updateLog incomingLog logs model.shared.velaLogBytesLimit) rm } }

    else if incomingLog.id /= 0 then
        { model | shared = { sm | repo = updateBuildStepsLogs (addLog incomingLog logs model.shared.velaLogBytesLimit) rm } }

    else
        model


{-| updateServiceLogs : takes model and incoming log and updates the list of service logs if necessary
-}
updateServiceLogs : Model -> Log -> Model
updateServiceLogs model incomingLog =
    let
        sm =
            model.shared

        rm =
            sm.repo

        build =
            rm.build

        logs =
            build.services.logs

        logExists =
            List.member incomingLog.id <| (List.map (\log -> log.id) <| Util.successful logs)
    in
    if logExists then
        { model | shared = { sm | repo = updateBuildServicesLogs (updateLog incomingLog logs model.shared.velaLogBytesLimit) rm } }

    else if incomingLog.id /= 0 then
        { model | shared = { sm | repo = updateBuildServicesLogs (addLog incomingLog logs model.shared.velaLogBytesLimit) rm } }

    else
        model



-- SECRETS


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
                                    Errors.addError HandleError error

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



-- BUILD


{-| resourceChanged : takes two repo resource identifiers and returns if the build has changed
-}
resourceChanged : RepoResourceIdentifier -> RepoResourceIdentifier -> Bool
resourceChanged ( orgA, repoA, idA ) ( orgB, repoB, idB ) =
    not <| orgA == orgB && repoA == repoB && idA == idB


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

        Pages.BuildGraph o r b ->
            not <| resourceChanged id ( o, r, b )

        _ ->
            False


{-| setBuild : takes new build information and sets the appropriate model state
-}
setBuild : Org -> Repo -> BuildNumber -> Bool -> Model -> Model
setBuild org repo buildNumber soft model =
    let
        sm =
            model.shared

        rm =
            sm.repo

        gm =
            rm.build.graph

        pipeline =
            sm.pipeline
    in
    { model
        | shared =
            { sm
                | repo =
                    rm
                        |> updateBuild
                            (if soft then
                                model.shared.repo.build.build

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
                        |> updateBuildGraph NotAsked
                        |> updateBuildGraphShowServices gm.showServices
                        |> updateBuildGraphShowSteps gm.showSteps
                        |> updateBuildGraphFilter gm.filter
                , pipeline =
                    { pipeline
                        | focusFragment = Nothing
                        , config = ( NotAsked, "" )
                        , expand = Nothing
                        , expanding = False
                        , expanded = False
                    }
                , templates = { data = NotAsked, error = "", show = True }
            }
    }



-- todo: MOST OF THESE RETURN CMD MSG AND THEREFORE REQUIRE MIGRATION TO SHARED IN ORDER TO BE MOVED
-- REPO ENABLED


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
                            ( toFailure error, Errors.addError HandleError error )

                _ ->
                    ( toFailure error, Errors.addError HandleError error )
    in
    ( enableUpdate repo enabled sourceRepos
    , action
    )



-- RANDOM COMPONENTS


viewBuildsFilter : Bool -> Org -> Repo -> Maybe Event -> Html Msg
viewBuildsFilter shouldRender org repo maybeEvent =
    let
        eventToMaybe : String -> Maybe Event
        eventToMaybe event =
            case event of
                "all" ->
                    Nothing

                _ ->
                    Just event
    in
    if shouldRender then
        let
            eventEnum : List String
            eventEnum =
                [ "all"
                , "push"
                , "pull_request"
                , "tag"
                , "deployment"
                , "schedule"
                , "comment"
                ]
        in
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
            Util.open showId
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
        , nav [ class "help-links" ]
            [ ul []
                [ li [] [ viewThemeToggle theme ]
                , li [] [ a [ href feedbackLink, attribute "aria-label" "go to feedback" ] [ text "feedback" ] ]
                , li [] [ a [ href docsLink, attribute "aria-label" "go to docs" ] [ text "docs" ] ]
                , Help.View.help help
                ]
            ]
        ]


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



-- ALERTS


viewAlerts : Stack Alert -> Html Msg
viewAlerts toasties =
    div [ Util.testAttribute "alerts", class "alerts" ] [ Alerting.view Alerts.successConfig (Alerts.view Copy) AlertsUpdate toasties ]


wrapAlertMessage : String -> String
wrapAlertMessage message =
    if not <| String.isEmpty message then
        "`" ++ message ++ "` "

    else
        message



-- HELP


helpArg : WebData a -> Help.Commands.Arg
helpArg arg =
    { success = Util.isSuccess arg, loading = Util.isLoading arg }


helpArgs : Model -> Help.Commands.Model Msg
helpArgs model =
    { user = helpArg model.shared.user
    , sourceRepos = helpArg model.shared.sourceRepos
    , orgRepos = helpArg model.shared.repo.orgRepos.orgRepos
    , builds = helpArg model.shared.repo.builds.builds
    , deployments = helpArg model.shared.repo.deployments.deployments
    , build = helpArg model.shared.repo.build.build
    , repo = helpArg model.shared.repo.repo
    , hooks = helpArg model.shared.repo.hooks.hooks
    , secrets = helpArg model.secretsModel.repoSecrets
    , show = model.shared.showHelp
    , toggle = ShowHideHelp
    , copy = Copy
    , noOp = NoOp
    , page = model.legacyPage

    -- TODO: use env flag velaDocsURL
    -- , velaDocsURL = model.velaDocsURL
    , velaDocsURL = "https://go-vela.github.io/docs"
    }



-- TIMESTAMPS?


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



-- UNUSED REFERENCE CODE


viewPageUNUSED : Model -> ( String, Html Msg )
viewPageUNUSED model =
    case model.legacyPage of
        -- todo: vader: remove this in favor of migrated page
        Pages.Overview ->
            ( "Overview"
            , div [] [ text "Legacy Overview, how'd we get here?" ]
            )

        Pages.SourceRepositories ->
            ( "Source Repositories"
            , lazy2 Pages.SourceRepos.view
                { user = model.shared.user
                , sourceRepos = model.shared.sourceRepos
                , filters = model.shared.filters
                }
                sourceReposMsgs
            )

        Pages.OrgRepositories org maybePage _ ->
            ( org ++ Util.pageToString maybePage
            , div []
                [ Pager.view model.shared.repo.orgRepos.pager Pager.prevNextLabels GotoPage
                , lazy2 Pages.Organization.viewOrgRepos org model.shared.repo.orgRepos
                , Pager.view model.shared.repo.orgRepos.pager Pager.prevNextLabels GotoPage
                ]
            )

        Pages.Hooks org repo maybePage _ ->
            ( String.join "/" [ org, repo ] ++ " hooks" ++ Util.pageToString maybePage
            , div []
                [ Pager.view model.shared.repo.hooks.pager Pager.defaultLabels GotoPage
                , lazy2 Pages.Hooks.view
                    { hooks = model.shared.repo.hooks
                    , time = model.shared.time
                    , org = model.shared.repo.org
                    , repo = model.shared.repo.name
                    }
                    RedeliverHook
                , Pager.view model.shared.repo.hooks.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepoSettings org repo ->
            ( String.join "/" [ org, repo ] ++ " settings"
            , lazy5 Pages.RepoSettings.view model.shared.repo.repo repoSettingsMsgs model.shared.velaAPI (Url.toString model.url) model.shared.velaMaxBuildLimit
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
                [ Html.map SecretsUpdate <| lazy3 Pages.Secrets.View.viewSharedSecrets model False True
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
            , Html.map AddDeploymentUpdate <| lazy Pages.Deployments.View.addDeployment model
            )

        Pages.RepositoryDeployments org repo maybePage _ ->
            ( String.join "/" [ org, repo ] ++ " deployments" ++ Util.pageToString maybePage
            , div []
                [ lazy3 Pages.Deployments.View.viewDeployments model.shared.repo org repo
                , Pager.view model.shared.repo.deployments.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.AddSchedule org repo ->
            ( String.join "/" [ org, repo, "add schedule" ]
            , Html.map AddScheduleUpdate <| lazy Pages.Schedules.View.viewAddSchedule model
            )

        Pages.Schedule org repo name ->
            ( String.join "/" [ org, repo, name ]
            , Html.map AddScheduleUpdate <| lazy Pages.Schedules.View.viewEditSchedule model
            )

        Pages.Schedules org repo maybePage _ ->
            let
                viewPager =
                    if Util.checkScheduleAllowlist org repo model.shared.velaScheduleAllowlist then
                        Pager.view model.schedulesModel.pager Pager.defaultLabels GotoPage

                    else
                        text ""
            in
            ( String.join "/" [ org, repo ] ++ " schedules" ++ Util.pageToString maybePage
            , div []
                [ lazy3 Pages.Schedules.View.viewRepoSchedules model org repo
                , viewPager
                ]
            )

        Pages.OrgBuilds org maybePage _ maybeEvent ->
            let
                repo =
                    ""

                shouldRenderFilter : Bool
                shouldRenderFilter =
                    case ( model.shared.repo.builds.builds, maybeEvent ) of
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
                    , viewTimeToggle shouldRenderFilter model.shared.repo.builds.showTimestamp
                    ]
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy7 Pages.Organization.viewBuilds model.shared.repo.builds buildMsgs model.shared.buildMenuOpen model.shared.time model.shared.zone org maybeEvent
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepositoryBuilds org repo maybePage _ maybeEvent ->
            let
                shouldRenderFilter : Bool
                shouldRenderFilter =
                    case ( model.shared.repo.builds.builds, maybeEvent ) of
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
                    , viewTimeToggle shouldRenderFilter model.shared.repo.builds.showTimestamp
                    ]
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy8 Pages.Builds.view model.shared.repo.builds buildMsgs model.shared.buildMenuOpen model.shared.time model.shared.zone org repo maybeEvent
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepositoryBuildsPulls org repo maybePage _ ->
            let
                shouldRenderFilter : Bool
                shouldRenderFilter =
                    case ( model.shared.repo.builds.builds, Just "pull_request" ) of
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
                    , viewTimeToggle shouldRenderFilter model.shared.repo.builds.showTimestamp
                    ]
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy8 Pages.Builds.view model.shared.repo.builds buildMsgs model.shared.buildMenuOpen model.shared.time model.shared.zone org repo (Just "pull_request")
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepositoryBuildsTags org repo maybePage _ ->
            let
                shouldRenderFilter : Bool
                shouldRenderFilter =
                    case ( model.shared.repo.builds.builds, Just "tag" ) of
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
                    [ viewBuildsFilter shouldRenderFilter org repo (Just "tag")
                    , viewTimeToggle shouldRenderFilter model.shared.repo.builds.showTimestamp
                    ]
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
                , lazy8 Pages.Builds.view model.shared.repo.builds buildMsgs model.shared.buildMenuOpen model.shared.time model.shared.zone org repo (Just "tag")
                , Pager.view model.shared.repo.builds.pager Pager.defaultLabels GotoPage
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

        Pages.BuildGraph org repo buildNumber ->
            ( "Visualize " ++ String.join "/" [ org, repo, buildNumber ]
            , Pages.Build.View.viewBuildGraph
                model
                buildMsgs
                org
                repo
                buildNumber
            )

        Pages.Settings ->
            ( "Settings"
            , Pages.Settings.view model.shared.session model.shared.time (Pages.Settings.Msgs Copy)
            )

        Pages.Login ->
            ( "Login"
            , viewLogin
            )

        Pages.NotFound ->
            ( "404"
            , h1 [] [ text "Not Found" ]
            )


setNewPageUNUSED : Routes.Route -> Model -> ( Model, Cmd Msg )
setNewPageUNUSED route model =
    let
        shared =
            model.shared
    in
    case ( route, model.shared.session ) of
        -- Logged in and on auth flow pages - what are you doing here?
        ( Routes.Login, Authenticated _ ) ->
            ( model, Browser.Navigation.pushUrl model.key <| Routes.routeToUrl Routes.Overview )

        ( Routes.Authenticate _, Authenticated _ ) ->
            ( model, Browser.Navigation.pushUrl model.key <| Routes.routeToUrl Routes.Overview )

        -- "Not logged in" (yet) and on auth flow pages, continue on..
        ( Routes.Authenticate { code, state }, Unauthenticated ) ->
            ( { model | legacyPage = Pages.Login }
            , Api.Api.try TokenResponse <| Api.Operations.getInitialToken model <| AuthParams code state
            )

        -- On the login page but not logged in.. good place to be
        ( Routes.Login, Unauthenticated ) ->
            ( { model | legacyPage = Pages.Login }, Cmd.none )

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

        ( Routes.RepositoryBuildsTags org repo maybePage maybePerPage, Authenticated _ ) ->
            loadRepoBuildsTagsPage model org repo maybePage maybePerPage

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

        ( Routes.BuildGraph org repo buildNumber, Authenticated _ ) ->
            loadBuildGraphPage model org repo buildNumber

        ( Routes.AddSchedule org repo, Authenticated _ ) ->
            loadAddSchedulePage model org repo

        ( Routes.Schedules org repo maybePage maybePerPage, Authenticated _ ) ->
            loadRepoSchedulesPage model org repo maybePage maybePerPage

        ( Routes.Schedule org repo id, Authenticated _ ) ->
            loadEditSchedulePage model org repo id

        ( Routes.Settings, Authenticated _ ) ->
            ( { model | legacyPage = Pages.Settings, shared = { shared | showIdentity = False } }, Cmd.none )

        ( Routes.Logout, Authenticated _ ) ->
            ( model, getLogout model )

        -- Not found page handling
        ( Routes.NotFound, Authenticated _ ) ->
            ( { model | legacyPage = Pages.NotFound }, Cmd.none )

        {--Hitting any page and not being logged in will load the login page content

           Note: we're not using .pushUrl to retain ability for user to use
           browser's back button
        --}
        ( _, Unauthenticated ) ->
            ( { model
                | legacyPage =
                    if model.shared.fetchingToken then
                        model.legacyPage

                    else
                        Pages.Login
              }
            , Interop.setRedirect <| Json.Encode.string <| Url.toString model.url
            )
