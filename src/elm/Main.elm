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
import Errors exposing (detailedErrorToString)
import Favorites exposing (toFavorite, updateFavorites)
import FeatherIcons
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
import Html.Lazy exposing (lazy, lazy2, lazy3, lazy5, lazy7)
import Http exposing (Error(..))
import Http.Detailed
import Interop
import Json.Decode as Decode exposing (string)
import Json.Encode as Encode
import List.Extra exposing (updateIf)
import Maybe
import Nav
import Pager
import Pages exposing (Page(..))
import Pages.Build.Logs
    exposing
        ( focusFragmentToFocusId
        , focusLogs
        , getCurrentStep
        , stepBottomTrackerFocusId
        )
import Pages.Build.Model
import Pages.Build.Update exposing (expandActiveStep)
import Pages.Build.View
import Pages.Builds exposing (view)
import Pages.Home
import Pages.Hooks
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
        , BuildIdentifier
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
        , Event
        , Favicon
        , Field
        , FocusFragment
        , Hooks
        , HooksModel
        , Key
        , Log
        , Logs
        , Name
        , Org
        , RepairRepo
        , Repo
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
    , hooks : HooksModel
    , builds : BuildsModel
    , build : WebData Build
    , steps : WebData Steps
    , logs : Logs
    , followingStep : Int
    , velaAPI : String
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
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    , showHelp : Bool
    , showIdentity : Bool
    , favicon : Favicon
    , secretsModel : Pages.Secrets.Model.Model Msg
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
            , hooks = defaultHooks
            , builds = defaultBuilds
            , build = NotAsked
            , steps = NotAsked
            , logs = []
            , followingStep = 0
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
            , theme = stringToTheme flags.velaTheme
            , shift = False
            , visibility = Visible
            , showHelp = False
            , showIdentity = False
            , favicon = defaultFavicon
            , secretsModel = initSecretsModel
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
    | RefreshHooks Org Repo
    | RefreshSecrets Engine Type Org Repo
    | SetTheme Theme
    | GotoPage Pagination.Page
    | ShowHideHelp (Maybe Bool)
    | ShowHideIdentity (Maybe Bool)
    | Copy String
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
    | ChownRepo Repository
    | RepairRepo Repository
    | RestartBuild Org Repo BuildNumber
      -- Inbound HTTP responses
    | UserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, User ))
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | RepoFavoritedResponse String Bool (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
    | HooksResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | RepoEnabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoDisabledResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoChownedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RepoRepairedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | StepsResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | StepLogResponse StepNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
    | SecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secret ))
    | SecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Secrets ))
      -- Other
    | Error String
    | AlertsUpdate (Alerting.Msg Alert)
    | SessionChanged (Maybe Session)
    | FilterBuildEventBy (Maybe Event) Org Repo
    | FocusOn String
    | FocusResult (Result Dom.Error ())
    | OnKeyDown String
    | OnKeyUp String
    | VisibilityChanged Visibility
      -- Components
    | BuildUpdate Pages.Build.Model.Msg
    | AddSecretUpdate Engine Pages.Secrets.Model.Msg
      -- Time
    | AdjustTimeZone Zone
    | AdjustTime Posix
    | Tick Interval Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewRoute route ->
            setNewPage route model

        SignInRequested ->
            ( model, Navigation.load <| Api.Endpoint.toUrl model.velaAPI Api.Endpoint.Login )

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

        EnableRepo repo ->
            let
                payload : EnableRepositoryPayload
                payload =
                    buildEnableRepositoryPayload repo

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
            , Api.try (RepoEnabledResponse repo) <| Api.enableRepository model body
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
                    ( { model | user = toFailure error }, addError error )

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
                    , Util.dispatch <| ToggleFavorite repo.org <| Just repo.name
                    )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (enabledRepo.full_name ++ " enabled.") Nothing)

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
                                Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (favorite ++ " added to favorites.") Nothing)

                            else
                                Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (favorite ++ " removed from favorites.") Nothing)
                           )

                Err error ->
                    ( { model | user = toFailure error }, addError error )

        RepoUpdatedResponse field response ->
            case response of
                Ok ( _, updatedRepo ) ->
                    ( { model | repo = RemoteData.succeed updatedRepo }, Cmd.none )
                        |> Alerting.addToast Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (Pages.RepoSettings.alert field updatedRepo) Nothing)

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
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " disabled.") Nothing)

                Err error ->
                    ( model, addError error )

        ChownRepo repo ->
            ( model, Api.try (RepoChownedResponse repo) <| Api.chownRepo model repo )

        RepoChownedResponse repo response ->
            case response of
                Ok _ ->
                    ( model, Cmd.none )
                        |> Alerting.addToastIfUnique Alerts.successConfig AlertsUpdate (Alerts.Success "Success" ("You are now the owner of " ++ repo.full_name) Nothing)

                Err error ->
                    ( model, addError error )

        RepairRepo repo ->
            ( model, Api.try (RepoRepairedResponse repo) <| Api.repairRepo model repo )

        RepoRepairedResponse repo response ->
            let
                currentRepo =
                    RemoteData.withDefault defaultRepository model.repo
            in
            case response of
                Ok _ ->
                    -- TODO: could 'refresh' settings page instead
                    ( { model
                        | sourceRepos = enableUpdate repo (RemoteData.succeed True) model.sourceRepos
                        , repo = RemoteData.succeed <| { currentRepo | enabling = Vela.Enabled }
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
                        , favicon = statusToFavicon build.status
                      }
                    , Interop.setFavicon <| Encode.string <| statusToFavicon build.status
                    )

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

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

        StepsResponse org repo buildNumber logFocus refresh response ->
            case response of
                Ok ( _, steps ) ->
                    let
                        mergedSteps =
                            steps
                                |> List.sortBy .number
                                |> Pages.Build.Update.mergeSteps logFocus refresh model.steps

                        updatedModel =
                            { model | steps = RemoteData.succeed mergedSteps }

                        cmd =
                            getBuildStepsLogs updatedModel org repo buildNumber mergedSteps logFocus refresh
                    in
                    ( { updatedModel | steps = RemoteData.succeed mergedSteps }, cmd )

                Err error ->
                    ( model, addError error )

        StepLogResponse stepNumber logFocus refresh response ->
            case response of
                Ok ( _, incomingLog ) ->
                    let
                        following =
                            model.followingStep /= 0

                        onFollowedStep =
                            model.followingStep == (Maybe.withDefault -1 <| String.toInt stepNumber)

                        ( steps, focusId ) =
                            if following && refresh && onFollowedStep then
                                ( model.steps
                                    |> RemoteData.unwrap model.steps
                                        (\s -> expandActiveStep stepNumber s |> RemoteData.succeed)
                                , stepBottomTrackerFocusId <| String.fromInt model.followingStep
                                )

                            else if not refresh then
                                ( model.steps, Util.extractFocusIdFromRange <| focusFragmentToFocusId logFocus )

                            else
                                ( model.steps, "" )

                        cmd =
                            if not <| String.isEmpty focusId then
                                Util.dispatch <| FocusOn <| focusId

                            else
                                Cmd.none
                    in
                    ( updateLogs { model | steps = steps } incomingLog
                    , cmd
                    )

                Err error ->
                    ( model, addError error )

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

        SecretsResponse response ->
            let
                secretsModel =
                    model.secretsModel
            in
            case response of
                Ok ( meta, secrets ) ->
                    let
                        mergedSecrets =
                            case secretsModel.secrets of
                                Success s ->
                                    RemoteData.succeed <| Util.mergeListsById s secrets

                                _ ->
                                    RemoteData.succeed secrets

                        pager =
                            Pagination.get meta.headers
                    in
                    ( { model | secretsModel = { secretsModel | secrets = mergedSecrets, pager = pager } }, Cmd.none )

                Err error ->
                    ( { model | secretsModel = { secretsModel | secrets = toFailure error } }, addError error )

        UpdateRepoEvent org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoBoolPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload

                cmd =
                    if Pages.RepoSettings.validEventsUpdate model.repo payload then
                        Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)

                    else
                        addErrorString "Could not disable webhook event. At least one event must be active."
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
                    if Pages.RepoSettings.validAccessUpdate model.repo payload then
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

        EnableRepos repos ->
            ( model
            , Cmd.batch <| List.map (Util.dispatch << EnableRepo) repos
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
                            model.builds

                        loadingBuilds =
                            { currentBuilds | builds = Loading }
                    in
                    ( { model | builds = loadingBuilds }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo (Just pageNumber) maybePerPage maybeEvent )

                Pages.Hooks org repo _ maybePerPage ->
                    let
                        currentHooks =
                            model.hooks

                        loadingHooks =
                            { currentHooks | hooks = Loading }
                    in
                    ( { model | hooks = loadingHooks }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.Hooks org repo (Just pageNumber) maybePerPage )

                Pages.OrgSecrets engine org _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | secrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.OrgSecrets engine org (Just pageNumber) maybePerPage )

                Pages.RepoSecrets engine org repo _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | secrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepoSecrets engine org repo (Just pageNumber) maybePerPage )

                Pages.SharedSecrets engine org team _ maybePerPage ->
                    let
                        currentSecrets =
                            model.secretsModel

                        loadingSecrets =
                            { currentSecrets | secrets = Loading }
                    in
                    ( { model | secretsModel = loadingSecrets }, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.SharedSecrets engine org team (Just pageNumber) maybePerPage )

                _ ->
                    ( model, Cmd.none )

        RestartBuild org repo buildNumber ->
            ( model
            , restartBuild model org repo buildNumber
            )

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.errorConfig AlertsUpdate (Alerts.Error "Error" error)

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

        AlertsUpdate subMsg ->
            Alerting.update Alerts.successConfig AlertsUpdate subMsg model

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

        RefreshHooks org repo ->
            let
                hooks =
                    model.hooks
            in
            ( { model | hooks = { hooks | hooks = Loading } }, getHooks model org repo Nothing Nothing )

        RefreshSecrets engine type_ org key ->
            let
                secretsModel =
                    model.secretsModel
            in
            ( { model | secretsModel = { secretsModel | secrets = Loading } }
            , getSecrets model Nothing Nothing engine type_ org key
            )

        BuildUpdate m ->
            let
                ( newModel, action ) =
                    Pages.Build.Update.update model m ( getBuildStepLogs, getBuildStepsLogs ) FocusResult
            in
            ( newModel
            , action
            )

        AddSecretUpdate engine m ->
            let
                ( newModel, action ) =
                    Pages.Secrets.Update.update model m
            in
            ( newModel
            , action
            )

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
                            refreshFavicon model.page model.favicon model.build
                    in
                    ( { model | time = time, favicon = favicon }, cmd )

                FiveSecond _ ->
                    ( model, refreshPage model )

                OneSecondHidden ->
                    let
                        ( favicon, cmd ) =
                            refreshFavicon model.page model.favicon model.build
                    in
                    ( { model | time = time, favicon = favicon }, cmd )

                FiveSecondHidden data ->
                    ( model, refreshPageHidden model data )

        FilterBuildEventBy maybeEvent org repo ->
            ( model, Navigation.pushUrl model.navigationKey <| Routes.routeToUrl <| Routes.RepositoryBuilds org repo Nothing Nothing maybeEvent )

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
        Pages.Build _ _ _ _ ->
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

        Pages.Build org repo buildNumber focusFragment ->
            Cmd.batch
                [ getBuilds model org repo Nothing Nothing Nothing
                , refreshBuild model org repo buildNumber
                , refreshBuildSteps model org repo buildNumber focusFragment
                , refreshLogs model org repo buildNumber model.steps Nothing
                ]

        Pages.Hooks org repo maybePage maybePerPage ->
            Cmd.batch
                [ getHooks model org repo maybePage maybePerPage
                ]

        Pages.OrgSecrets engine org maybePage maybePerPage ->
            Cmd.batch
                [ getSecrets model maybePage maybePerPage engine "org" org "*"
                ]

        Pages.RepoSecrets engine org repo maybePage maybePerPage ->
            Cmd.batch
                [ getSecrets model maybePage maybePerPage engine "repo" org repo
                ]

        Pages.SharedSecrets engine org team maybePage maybePerPage ->
            Cmd.batch
                [ getSecrets model maybePage maybePerPage engine "shared" org team
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
refreshBuildSteps : Model -> Org -> Repo -> BuildNumber -> FocusFragment -> Cmd Msg
refreshBuildSteps model org repo buildNumber focusFragment =
    if shouldRefresh model.build then
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
    if shouldRefresh model.build then
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
                [ Pager.view model.hooks.pager Pager.defaultLabels GotoPage
                , lazy Pages.Hooks.view
                    { hooks = model.hooks
                    , time = model.time
                    }
                , Pager.view model.hooks.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.RepoSettings org repo ->
            ( String.join "/" [ org, repo ] ++ " settings"
            , lazy5 Pages.RepoSettings.view model.repo model.inTimeout repoSettingsMsgs model.velaAPI (Url.toString model.entryURL)
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
                [ Pager.view model.secretsModel.pager { previousLabel = "prev", nextLabel = "next" } GotoPage
                , Html.map (\_ -> NoOp) <| lazy Pages.Secrets.View.secrets model
                , Pager.view model.secretsModel.pager { previousLabel = "prev", nextLabel = "next" } GotoPage
                ]
            )

        Pages.RepoSecrets engine org repo _ _ ->
            ( String.join "/" [ org, repo ] ++ " " ++ engine ++ " repo secrets"
            , div []
                [ Pager.view model.secretsModel.pager { previousLabel = "prev", nextLabel = "next" } GotoPage
                , Html.map (\_ -> NoOp) <| lazy Pages.Secrets.View.secrets model
                , Pager.view model.secretsModel.pager { previousLabel = "prev", nextLabel = "next" } GotoPage
                ]
            )

        Pages.SharedSecrets engine org team _ _ ->
            ( String.join "/" [ org, team ] ++ " " ++ engine ++ " shared secrets"
            , div []
                [ Pager.view model.secretsModel.pager { previousLabel = "prev", nextLabel = "next" } GotoPage
                , Html.map (\_ -> NoOp) <| lazy Pages.Secrets.View.secrets model
                , Pager.view model.secretsModel.pager { previousLabel = "prev", nextLabel = "next" } GotoPage
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
                    case ( model.builds.builds, maybeEvent ) of
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
                , Pager.view model.builds.pager Pager.defaultLabels GotoPage
                , Html.map (\m -> BuildUpdate m) <|
                    lazy5 Pages.Builds.view model.builds model.time org repo maybeEvent
                , Pager.view model.builds.pager Pager.defaultLabels GotoPage
                ]
            )

        Pages.Build org repo buildNumber _ ->
            ( "Build #" ++ buildNumber ++ " - " ++ String.join "/" [ org, repo ]
            , Html.map (\m -> BuildUpdate m) <|
                lazy3 Pages.Build.View.viewBuild
                    { navigationKey = model.navigationKey
                    , time = model.time
                    , build = model.build
                    , steps = model.steps
                    , logs = model.logs
                    , followingStep = model.followingStep
                    , shift = model.shift
                    }
                    org
                    repo
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
            [ "all", "push", "pull_request", "tag", "deployment" ]

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
    , builds = helpArg model.builds.builds
    , build = helpArg model.build
    , repo = helpArg model.repo
    , hooks = helpArg model.hooks.hooks
    , secrets = helpArg model.secretsModel.secrets
    , show = model.showHelp
    , toggle = ShowHideHelp
    , copy = Copy
    , noOp = NoOp
    , page = model.page
    }


viewUtil : Model -> Html Msg
viewUtil model =
    div [ class "util" ]
        [ lazy7 Pages.Build.View.viewBuildHistory model.time model.zone model.page model.builds.org model.builds.repo model.builds.builds 10 ]


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

        ( Routes.Build org repo buildNumber logFocus, True ) ->
            case model.page of
                Pages.Build o r b _ ->
                    if not <| buildChanged ( org, repo, buildNumber ) ( o, r, b ) then
                        let
                            ( page, steps, action ) =
                                focusLogs model (RemoteData.withDefault [] model.steps) org repo buildNumber logFocus getBuildStepsLogs
                        in
                        ( { model | page = page, steps = RemoteData.succeed steps }, action )

                    else
                        loadBuildPage model org repo buildNumber logFocus

                _ ->
                    loadBuildPage model org repo buildNumber logFocus

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
    ( { model | page = Pages.Hooks org repo maybePage maybePerPage, hooks = loadingHooks }
    , Cmd.batch
        [ getHooks model org repo maybePage maybePerPage
        , getCurrentUser model
        ]
    )


{-| loadSettingsPage : takes model org and repo and loads the page for updating repo configurations
-}
loadRepoSettingsPage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadRepoSettingsPage model org repo =
    -- Fetch repo from Api
    ( { model | page = Pages.RepoSettings org repo, repo = Loading, inTimeout = Nothing }
    , Cmd.batch
        [ getRepo model org repo
        , getCurrentUser model
        ]
    )


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
                | secrets = Loading
                , org = org
                , engine = engine
                , type_ = Vela.OrgSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecrets model maybePage maybePerPage engine "org" org "*"
        ]
    )


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
    -- Fetch secrets from Api
    let
        secretsModel =
            model.secretsModel
    in
    ( { model
        | page = Pages.RepoSecrets engine org repo maybePage maybePerPage
        , secretsModel =
            { secretsModel
                | secrets = Loading
                , org = org
                , repo = repo
                , engine = engine
                , type_ = Vela.RepoSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecrets model maybePage maybePerPage engine "repo" org repo
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
                | secrets = Loading
                , org = org
                , team = team
                , engine = engine
                , type_ = Vela.SharedSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecrets model maybePage maybePerPage engine "shared" org team
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
                | secrets = Loading
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
                | secrets = Loading
                , org = org
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
                | secrets = Loading
                , org = org
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
                | secrets = Loading
                , org = org
                , engine = engine
                , type_ = Vela.OrgSecret
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
                | secrets = Loading
                , org = org
                , repo = repo
                , engine = engine
                , type_ = Vela.RepoSecret
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
                | secrets = Loading
                , org = org
                , team = team
                , engine = engine
                , type_ = Vela.SharedSecret
            }
      }
    , Cmd.batch
        [ getCurrentUser model
        , getSecret model engine "shared" org team name
        ]
    )


{-| loadRepoBuildsPage : takes model org and repo and loads the appropriate builds.

    loadRepoBuildsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadRepoBuildsPage : Model -> Org -> Repo -> Session -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> ( Model, Cmd Msg )
loadRepoBuildsPage model org repo _ maybePage maybePerPage maybeEvent =
    let
        -- Builds already loaded
        loadedBuilds =
            model.builds

        -- Set builds to Loading
        loadingBuilds =
            { loadedBuilds | org = org, repo = repo, builds = Loading }
    in
    -- Fetch builds from Api
    ( { model | page = Pages.RepositoryBuilds org repo maybePage maybePerPage maybeEvent, builds = loadingBuilds }
    , Cmd.batch
        [ getBuilds model org repo maybePage maybePerPage maybeEvent
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
        , followingStep = 0
        , logs = []
      }
    , Cmd.batch
        [ getBuilds model org repo Nothing Nothing Nothing
        , getBuild model org repo buildNumber
        , getAllBuildSteps model org repo buildNumber focusFragment False
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
    List.map (\log -> log.id) <| Util.successful logs


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

        following =
            model.followingStep /= 0
    in
    if stepExists then
        { model
            | steps =
                steps
                    |> updateIf (\step -> incomingStep.number == step.number)
                        (\step ->
                            let
                                shouldView =
                                    following
                                        && (step.status /= Vela.Pending)
                                        && (step.number == getCurrentStep steps)
                            in
                            { incomingStep
                                | viewing = step.viewing || shouldView
                            }
                        )
                    |> RemoteData.succeed
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
    Pages.Secrets.Update.init SecretResponse SecretsResponse AddSecretResponse UpdateSecretResponse



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


getBuildStep : Model -> Org -> Repo -> BuildNumber -> StepNumber -> Cmd Msg
getBuildStep model org repo buildNumber stepNumber =
    Api.try (StepResponse org repo buildNumber stepNumber) <| Api.getStep model org repo buildNumber stepNumber


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


restartBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
restartBuild model org repo buildNumber =
    Api.try (RestartedBuildResponse org repo buildNumber) <| Api.restartBuild model org repo buildNumber


getSecrets :
    Model
    -> Maybe Pagination.Page
    -> Maybe Pagination.PerPage
    -> Engine
    -> Type
    -> Org
    -> Repo
    -> Cmd Msg
getSecrets model maybePage maybePerPage engine type_ org repo =
    Api.try SecretsResponse <| Api.getSecrets model maybePage maybePerPage engine type_ org repo


getSecret : Model -> Engine -> Type -> Org -> Key -> Name -> Cmd Msg
getSecret model engine type_ org key name =
    Api.try SecretResponse <| Api.getSecret model engine type_ org key name



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
