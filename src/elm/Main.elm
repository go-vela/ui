{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Main exposing (main)

import Alerts exposing (Alert)
import Api
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Navigation
import Build
    exposing
        ( viewFullBuild
        , viewRepositoryBuilds
        )
import Crumbs
import Dict exposing (Dict)
import Errors exposing (detailedErrorToString)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , br
        , button
        , code
        , details
        , div
        , h1
        , header
        , input
        , li
        , main_
        , nav
        , p
        , span
        , summary
        , text
        , ul
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , disabled
        , href
        , placeholder
        , value
        )
import Html.Events exposing (onClick, onInput)
import Html.Lazy exposing (lazy2)
import Http exposing (Error(..))
import Http.Detailed
import Interop
import Json.Decode as Decode exposing (string)
import Json.Encode as Encode
import List.Extra exposing (setIf, updateIf)
import Pages exposing (Page(..))
import Pages.Hooks
import Pages.Settings
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
        ( AddRepositoryPayload
        , AuthParams
        , Build
        , BuildIdentifier
        , BuildNumber
        , Builds
        , BuildsModel
        , Field
        , HookBuilds
        , Hooks
        , Log
        , Logs
        , Org
        , Repo
        , Repositories
        , Repository
        , Session
        , SourceRepoUpdateFunction
        , SourceRepositories
        , Step
        , StepNumber
        , Steps
        , UpdateRepositoryPayload
        , User
        , Viewing
        , buildUpdateRepoBoolPayload
        , buildUpdateRepoIntPayload
        , buildUpdateRepoStringPayload
        , decodeSession
        , defaultAddRepositoryPayload
        , defaultBuilds
        , defaultRepository
        , defaultSession
        , encodeAddRepository
        , encodeSession
        , encodeUpdateRepository
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
    }


type alias Model =
    { page : Page
    , session : Maybe Session
    , currentRepos : WebData Repositories
    , toasties : Stack Alert
    , sourceRepos : WebData SourceRepositories
    , hooks : WebData Hooks
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
    , sourceSearchFilters : RepoSearchFilters
    , repo : WebData Repository
    , inTimeout : Maybe Int
    , entryURL : Url
    , hookBuilds : HookBuilds
    }


type alias RepoSearchFilters =
    Dict Org SearchFilter


type alias SearchFilter =
    String


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
            , currentRepos = NotAsked
            , sourceRepos = NotAsked
            , velaAPI = flags.velaAPI
            , hooks = NotAsked
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
            , sourceSearchFilters = Dict.empty
            , repo = RemoteData.succeed defaultRepository
            , inTimeout = Nothing
            , entryURL = url
            , hookBuilds = Dict.empty
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
    | ChangeRepoTimeout String
    | RefreshSettings Org Repo
    | ClickHook Org Repo BuildNumber
    | ClickStep Org Repo BuildNumber StepNumber
      -- Outgoing HTTP requests
    | SignInRequested
    | FetchSourceRepositories
    | AddRepo Repository
    | UpdateRepoEvent Org Repo Field Bool
    | UpdateRepoAccess Org Repo Field String
    | UpdateRepoTimeout Org Repo Field Int
    | AddOrgRepos Repositories
    | RemoveRepo Repository
    | RestartBuild Org Repo BuildNumber
      -- Inbound HTTP responses
    | UserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, User ))
    | RepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repositories ))
    | RepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | HooksResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Hooks ))
    | HookBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | RepoAddedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoUpdatedResponse Field (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoRemovedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | StepsResponse Org Repo BuildNumber (Maybe String) (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | StepLogResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
      -- Other
    | Error String
    | AlertsUpdate (Alerting.Msg Alert)
    | SessionChanged (Maybe Session)
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
            ( model, Navigation.load model.velaSourceOauthStartURL )

        SessionChanged newSession ->
            ( { model | session = newSession }, Cmd.none )

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

        RepositoriesResponse response ->
            case response of
                Ok ( _, repositories ) ->
                    ( { model | currentRepos = RemoteData.succeed repositories }, Cmd.none )

                Err error ->
                    ( { model | currentRepos = toFailure error }, addError error )

        RepoResponse response ->
            case response of
                Ok ( _, repoResponse ) ->
                    ( { model | repo = RemoteData.succeed repoResponse }, Cmd.none )

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

        FetchSourceRepositories ->
            ( { model | sourceRepos = Loading, sourceSearchFilters = Dict.empty }, Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model )

        SourceRepositoriesResponse response ->
            case response of
                Ok ( _, repositories ) ->
                    ( { model | sourceRepos = RemoteData.succeed repositories }, Cmd.none )

                Err error ->
                    ( { model | sourceRepos = toFailure error }, addError error )

        RepoAddedResponse repo response ->
            case response of
                Ok ( _, addedRepo ) ->
                    ( { model | sourceRepos = updateSourceRepoStatus addedRepo (RemoteData.succeed True) model.sourceRepos updateSourceRepoListByRepoName }, Cmd.none )
                        |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Success "Success" (addedRepo.full_name ++ " added.") Nothing)

                Err error ->
                    ( { model | sourceRepos = updateSourceRepoStatus repo (toFailure error) model.sourceRepos updateSourceRepoListByRepoName }, addError error )

        RepoUpdatedResponse field response ->
            case response of
                Ok ( _, updatedRepo ) ->
                    ( { model | repo = RemoteData.succeed updatedRepo }, Cmd.none )
                        |> Alerting.addToast Alerts.config AlertsUpdate (Alerts.Success "Success" (Pages.Settings.alert field updatedRepo) Nothing)

                Err error ->
                    ( { model | repo = toFailure error }, addError error )

        RemoveRepo repo ->
            ( model, Api.try (RepoRemovedResponse repo) <| Api.deleteRepo model repo )

        RepoRemovedResponse repo response ->
            case response of
                Ok _ ->
                    ( { model
                        | currentRepos = RemoteData.succeed (List.filter (\currentRepo -> currentRepo /= repo) (RemoteData.withDefault [] model.currentRepos))
                        , sourceRepos = updateSourceRepoStatus repo NotAsked model.sourceRepos updateSourceRepoListByRepoName
                      }
                    , Cmd.none
                    )
                        |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " removed.") Nothing)

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
                    , getBuilds model org repo
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
                    ( { model | builds = { builds | org = org, repo = repo }, build = RemoteData.succeed build }, Cmd.none )

                Err error ->
                    ( model, addError error )

        BuildsResponse org repo response ->
            case response of
                Ok ( _, builds ) ->
                    let
                        currentBuilds =
                            model.builds
                    in
                    ( { model | builds = { currentBuilds | org = org, repo = repo, builds = RemoteData.succeed builds } }, Cmd.none )

                Err error ->
                    ( model, addError error )

        StepResponse _ _ _ _ response ->
            case response of
                Ok ( _, step ) ->
                    ( updateStep model step, Cmd.none )

                Err error ->
                    ( model, addError error )

        StepsResponse org repo buildNumber frag response ->
            case response of
                Ok ( _, stepsResponse ) ->
                    let
                        steps =
                            RemoteData.succeed <| expandStepFrag frag stepsResponse

                        cmd =
                            getBuildStepsLogs model org repo buildNumber steps
                    in
                    ( { model | steps = steps }, cmd )

                Err error ->
                    ( model, addError error )

        StepLogResponse response ->
            case response of
                Ok ( _, log ) ->
                    ( updateLogs model log, Cmd.none )

                Err error ->
                    ( model, addError error )

        AddRepo repo ->
            let
                payload : AddRepositoryPayload
                payload =
                    buildAddRepositoryPayload repo model.velaSourceBaseURL

                body : Http.Body
                body =
                    Http.jsonBody <| encodeAddRepository payload
            in
            ( { model | sourceRepos = updateSourceRepoStatus repo Loading model.sourceRepos updateSourceRepoListByRepoName }
            , Api.try (RepoAddedResponse repo) <| Api.addRepository model body
            )

        UpdateRepoEvent org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoBoolPayload field value

                body : Http.Body
                body =
                    Http.jsonBody <| encodeUpdateRepository payload
            in
            ( model
            , Api.try (RepoUpdatedResponse field) (Api.updateRepository model org repo body)
            )

        UpdateRepoAccess org repo field value ->
            let
                payload : UpdateRepositoryPayload
                payload =
                    buildUpdateRepoStringPayload field value

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

        AddOrgRepos repos ->
            ( model
            , Cmd.batch <| List.map (Util.dispatch << AddRepo) repos
            )

        ClickHook org repo buildNumber ->
            let
                ( hookBuilds, action ) =
                    clickHook model org repo buildNumber
            in
            ( { model | hookBuilds = hookBuilds }
            , action
            )

        ClickStep org repo buildNumber stepNumber ->
            let
                ( steps, action ) =
                    clickStep model org repo buildNumber stepNumber
            in
            ( { model | steps = steps }
            , action
            )

        RestartBuild org repo buildNumber ->
            ( model
            , restartBuild model org repo buildNumber
            )

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Error "Error" error)

        HooksResponse _ _ response ->
            case response of
                Ok ( _, hooks ) ->
                    ( { model | hooks = RemoteData.succeed hooks }, Cmd.none )

                Err error ->
                    ( { model | hooks = toFailure error }, addError error )

        HookBuildResponse org repo buildNumber response ->
            case response of
                Ok ( _, build ) ->
                    ( { model | hookBuilds = receiveHookBuild ( org, repo, buildNumber ) (RemoteData.succeed build) model.hookBuilds }, Cmd.none )

                Err error ->
                    ( { model | hookBuilds = receiveHookBuild ( org, repo, buildNumber ) (toFailure error) model.hookBuilds }, addError error )

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
                    Dict.update org (\_ -> Just searchBy) model.sourceSearchFilters
            in
            ( { model | sourceSearchFilters = filters }, Cmd.none )

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

        NoOp ->
            ( model, Cmd.none )


expandStepFrag : Maybe String -> Steps -> Steps
expandStepFrag frag steps =
    let
        frags =
            String.split (Maybe.withDefault "" frag) ":"
    in
    if List.length frags > 0 then
        updateIf (\_ -> True) (\step -> step) steps

    else
        steps



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Interop.onSessionChange decodeOnSessionChange
        , every Util.oneSecondMillis <| Tick OneSecond
        , every Util.fiveSecondsMillis <| Tick (FiveSecond <| refreshData model)
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


{-| refreshPage : refreshes Vela data based on current page and build status
-}
refreshPage : Model -> RefreshData -> Cmd Msg
refreshPage model _ =
    let
        page =
            model.page
    in
    case page of
        Pages.RepositoryBuilds org repo ->
            getBuilds model org repo

        Pages.Build org repo buildNumber frag ->
            Cmd.batch
                [ getBuilds model org repo
                , refreshBuild model org repo buildNumber
                , refreshBuildSteps model org repo buildNumber
                , refreshLogs model org repo buildNumber model.steps
                ]

        Pages.Hooks org repo ->
            Cmd.batch
                [ getHooks model org repo
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
refreshLogs : Model -> Org -> Repo -> BuildNumber -> WebData Steps -> Cmd Msg
refreshLogs model org repo buildNumber inSteps =
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
            getBuildStepsLogs model org repo buildNumber stepsToRefresh
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
        [ lazy2 viewHeader model.session { feedbackLink = model.velaFeedbackURL, docsLink = model.velaDocsURL }
        , viewNav model
        , div [ class "util" ] [ Build.viewBuildHistory model.time model.zone model.page model.builds.org model.builds.repo model.builds.builds ]
        , main_ []
            [ div [ class "content-wrap" ] [ content ] ]
        , div [ Util.testAttribute "alerts", class "alerts" ] [ Alerting.view Alerts.config Alerts.view AlertsUpdate model.toasties ]
        ]
    }


viewContent : Model -> ( String, Html Msg )
viewContent model =
    case model.page of
        Pages.Overview ->
            ( "Overview"
            , viewOverview model
            )

        Pages.AddRepositories ->
            ( "Add Repositories"
            , viewAddRepos model
            )

        Pages.Hooks org repo ->
            ( "Repository Hooks"
            , Pages.Hooks.view model.hooks model.hookBuilds model.time org repo ClickHook
            )

        Pages.Settings _ _ ->
            ( "Repository Settings"
            , Pages.Settings.view model.repo model.inTimeout UpdateRepoEvent UpdateRepoAccess UpdateRepoTimeout ChangeRepoTimeout
            )

        Pages.RepositoryBuilds org repo ->
            ( String.join "/" [ org, repo ] ++ " builds"
            , viewRepositoryBuilds model.builds.builds model.time org repo
            )

        Pages.Build org repo num frag ->
            ( "Build #" ++ num ++ " - " ++ String.join "/" [ org, repo ]
            , viewFullBuild model.time org repo model.build model.steps model.logs ClickStep
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
        , button [ class "btn-login", class "-solid", onClick SignInRequested, Util.testAttribute "login-button" ]
            [ FeatherIcons.github
                |> FeatherIcons.withSize 20
                |> FeatherIcons.withClass "login-source-icon"
                |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
            , text "GitHub"
            ]
        , p [] [ text "You will be taken to Github to authenticate." ]
        ]


viewOverview : Model -> Html Msg
viewOverview model =
    let
        blankMessage : Html Msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p []
                    [ text "To have Vela start building your projects we need to get them added."
                    , br [] []
                    , text "Add repositories from your GitHub account to Vela now!"
                    ]
                , a [ class "-btn", class "-solid", class "-overview", Routes.href Routes.AddRepositories ] [ text "Add Repositories" ]
                ]
    in
    div []
        [ case model.currentRepos of
            Success repos ->
                let
                    activeRepos : Repositories
                    activeRepos =
                        List.filter .active repos
                in
                if List.length activeRepos > 0 then
                    activeRepos
                        |> recordsGroupBy .org
                        |> viewCurrentRepoListByOrg

                else
                    blankMessage

            Loading ->
                div []
                    [ h1 [] [ text "Loading your Repositories", span [ class "loading-ellipsis" ] [] ]
                    ]

            NotAsked ->
                blankMessage

            Failure _ ->
                text ""
        ]


viewSingleRepo : Repository -> Html Msg
viewSingleRepo repo =
    div [ class "-item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "-actions" ]
            [ a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Routes.href <| Routes.Settings repo.org repo.name
                ]
                [ text "Settings" ]
            , button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| RemoveRepo repo ] [ text "Remove" ]
            , a
                [ class "-btn"
                , class "-inverted"
                , class "-view"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks repo.org repo.name
                ]
                [ text "Hooks" ]
            , a
                [ class "-btn"
                , class "-solid"
                , class "-view"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds repo.org repo.name
                ]
                [ text "View" ]
            ]
        ]


viewOrg : String -> Repositories -> Html Msg
viewOrg org repos =
    div [ class "repo-org", Util.testAttribute "repo-org" ]
        [ details [ class "details", class "repo-item", attribute "open" "open" ]
            (summary [ class "summary" ] [ text org ]
                :: List.map viewSingleRepo repos
            )
        ]


viewCurrentRepoListByOrg : Dict String Repositories -> Html Msg
viewCurrentRepoListByOrg repoList =
    repoList
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, repos ) -> viewOrg org repos)
        |> div [ class "repo-list" ]


{-| viewAddRepos : takes model and renders account page for adding repos to overview
-}
viewAddRepos : Model -> Html Msg
viewAddRepos model =
    let
        loading =
            div []
                [ h1 []
                    [ text "Loading your Repositories"
                    , span [ class "loading-ellipsis" ] []
                    ]
                , p []
                    [ text <|
                        "Hang tight while we grab the list of repositories that you have access to from Github. If you have access to "
                            ++ "a lot of organizations and repositories this might take a little while."
                    ]
                ]
    in
    case model.sourceRepos of
        Success sourceRepos ->
            div [ class "source-repos", Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal model
                , viewSourceRepos model sourceRepos
                ]

        Loading ->
            loading

        NotAsked ->
            loading

        Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching your available repositories... Click Refresh or try again later!"
                    ]
                ]


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : Model -> SourceRepositories -> Html Msg
viewSourceRepos model sourceRepos =
    if shouldSearch <| searchFilterGlobal model.sourceSearchFilters then
        -- Search and render repos using the global filter
        searchReposGlobal model.sourceSearchFilters sourceRepos

    else
        -- Render repos normally
        sourceRepos
            |> Dict.toList
            |> Util.filterEmptyLists
            |> List.map (\( org, repos_ ) -> viewSourceOrg model org repos_)
            |> div [ class "repo-list" ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : Model -> Org -> Repositories -> Html Msg
viewSourceOrg model org repos =
    let
        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org model.sourceSearchFilters then
                -- Search and render repos using the global filter
                searchReposLocal org model.sourceSearchFilters repos

            else
                -- Render repos normally
                ( repos, False, List.map viewSourceRepo repos )
    in
    viewSourceOrgDetails model org repos_ filtered content


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : Model -> Org -> Repositories -> Bool -> List (Html Msg) -> Html Msg
viewSourceOrgDetails model org repos filtered content =
    div [ class "org" ]
        [ details [ class "details", class "repo-item" ] <|
            viewSourceOrgSummary model org repos filtered content
        ]


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : Model -> Org -> Repositories -> Bool -> List (Html Msg) -> List (Html Msg)
viewSourceOrgSummary model org repos filtered content =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ div [ class "org-header" ]
            [ text org
            , viewRepoCount repos
            ]
        ]
        :: div [ class "source-actions" ]
            [ repoSearchBarLocal model org
            , addReposBtn org repos filtered
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos

    viewSourceRepo uses model.SourceRepositories and buildAddRepoElement to determine the state of each specific 'Add' button

-}
viewSourceRepo : Repository -> Html Msg
viewSourceRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , buildAddRepoElement repo
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : Repository -> Html Msg
viewSearchedSourceRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text <| repo.org ++ "/" ++ repo.name ]
        , buildAddRepoElement repo
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html Msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ code [] [ text <| (String.fromInt <| List.length repos) ++ " repos" ] ]


{-| addReposBtn : takes List of repos and renders a button to add them all at once, texts depends on user input filter
-}
addReposBtn : Org -> Repositories -> Bool -> Html Msg
addReposBtn org repos filtered =
    button [ class "-inverted", Util.testAttribute <| "add-org-" ++ org, onClick (AddOrgRepos repos) ]
        [ text <|
            if filtered then
                "Add Results"

            else
                "Add All"
        ]


{-| buildAddRepoElement : builds action element for adding single repos
-}
buildAddRepoElement : Repository -> Html Msg
buildAddRepoElement repo =
    case repo.added of
        NotAsked ->
            button [ class "-solid", onClick (AddRepo repo) ] [ text "Add" ]

        Loading ->
            div [ class "repo-add--adding" ] [ span [ class "repo-add--adding-text" ] [ text "Adding" ], span [ class "loading-ellipsis" ] [] ]

        Failure _ ->
            div [ class "repo-add--failed", onClick (AddRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]

        Success addedStatus ->
            if addedStatus then
                div [ class "-added-container" ]
                    [ div [ class "repo-add--added" ] [ FeatherIcons.check |> FeatherIcons.toHtml [ attribute "role" "img" ], span [] [ text "Added" ] ]
                    , a [ class "-btn", class "-solid", class "-view", Routes.href <| Routes.RepositoryBuilds repo.org repo.name ] [ text "View" ]
                    ]

            else
                div [ class "repo-add--failed", onClick (AddRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| repoSearchBarGlobal : renders a input bar for searching across all repos
-}
repoSearchBarGlobal : Model -> Html Msg
repoSearchBarGlobal model =
    div [ class "-filter", Util.testAttribute "global-search-bar" ]
        [ FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "role" "img" ]
        , input
            [ Util.testAttribute "global-search-input"
            , placeholder "Type to filter all repositories..."
            , value <| searchFilterGlobal model.sourceSearchFilters
            , onInput <| SearchSourceRepos ""
            ]
            []
        ]


{-| repoSearchBarLocal : takes an org and placeholder text and renders a search bar for local repo filtering
-}
repoSearchBarLocal : Model -> Org -> Html Msg
repoSearchBarLocal model org =
    div [ class "-filter", Util.testAttribute "local-search-bar" ]
        [ FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "role" "img" ]
        , input
            [ Util.testAttribute <| "local-search-input-" ++ org
            , placeholder <|
                "Type to filter repositories in "
                    ++ org
                    ++ "..."
            , value <| searchFilterLocal org model.sourceSearchFilters
            , onInput <| SearchSourceRepos org
            ]
            []
        ]


{-| viewNav : uses current state to render navigation, such as breadcrumb
-}
viewNav : Model -> Html Msg
viewNav model =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        [ Crumbs.view model.page
        , navButton model
        ]


{-| navButton : uses current page to build the commonly used button on the right side of the nav
-}
navButton : Model -> Html Msg
navButton model =
    case model.page of
        Pages.Overview ->
            case model.currentRepos of
                Success repos ->
                    if (repos |> List.filter .active |> List.length) > 0 then
                        a
                            [ class "-btn"
                            , class "-inverted"
                            , Util.testAttribute "repo-add"
                            , Routes.href <| Routes.AddRepositories
                            ]
                            [ text "Add Repositories" ]

                    else
                        text ""

                _ ->
                    text ""

        Pages.AddRepositories ->
            button
                [ classList
                    [ ( "btn-refresh", True )
                    , ( "-inverted", True )
                    , ( "loading", model.sourceRepos == Loading )
                    ]
                , onClick FetchSourceRepositories
                , disabled (model.sourceRepos == Loading)
                , Util.testAttribute "refresh-source-repos"
                ]
                [ case model.sourceRepos of
                    Loading ->
                        text "Loading…"

                    _ ->
                        text "Refresh List"
                ]

        Pages.RepositoryBuilds org repo ->
            div [ class "nav-buttons" ]
                [ a
                    [ class "-btn"
                    , class "-inverted"
                    , class "-hooks"
                    , Util.testAttribute <| "goto-repo-hooks-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.Hooks org repo
                    ]
                    [ text "Hooks" ]
                , a
                    [ class "-btn"
                    , class "-inverted"
                    , Util.testAttribute <| "goto-repo-settings-" ++ org ++ "/" ++ repo
                    , Routes.href <| Routes.Settings org repo
                    ]
                    [ text "Repo Settings" ]
                ]

        Pages.Settings org repo ->
            button
                [ classList
                    [ ( "btn-refresh", True )
                    , ( "-inverted", True )
                    ]
                , onClick <| RefreshSettings org repo
                , Util.testAttribute "refresh-repo-settings"
                ]
                [ text "Refresh Settings"
                ]

        Pages.Build org repo buildNumber frag ->
            button
                [ classList
                    [ ( "btn-restart-build", True )
                    , ( "-inverted", True )
                    ]
                , onClick <| RestartBuild org repo buildNumber
                , Util.testAttribute "restart-build"
                ]
                [ text "Restart Build"
                ]

        _ ->
            text ""


viewHeader : Maybe Session -> { feedbackLink : String, docsLink : String } -> Html Msg
viewHeader maybeSession { feedbackLink, docsLink } =
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
                    details [ class "details", class "identity-name", attribute "role" "navigation" ]
                        [ summary [ class "summary" ] [ text "Vela" ] ]

                _ ->
                    details [ class "details", class "identity-name", attribute "role" "navigation" ]
                        [ summary [ class "summary" ]
                            [ text session.username
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , ul [ attribute "aria-hidden" "true", attribute "role" "menu" ]
                            [ li [] [ a [ Routes.href Routes.Logout, Util.testAttribute "logout-link", attribute "role" "menuitem" ] [ text "Logout" ] ]
                            ]
                        ]
            ]
        , div [ class "help-links" ]
            [ a [ href feedbackLink, attribute "aria-label" "go to feedback" ] [ text "feedback" ]
            , a [ href docsLink, attribute "aria-label" "go to docs" ] [ text "docs" ]
            , FeatherIcons.terminal |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml []
            ]
        ]



-- HELPERS


buildUrl : String -> List String -> List QueryParameter -> String
buildUrl base paths params =
    UB.crossOrigin base paths params


{-| recordsGroupBy takes a list of records and groups them by the provided key

    recordsGroupBy .lastname listOfFullNames

-}
recordsGroupBy : (a -> comparable) -> List a -> Dict comparable (List a)
recordsGroupBy key recordList =
    List.foldr (\x acc -> Dict.update (key x) (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just) acc) Dict.empty recordList


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
            ( { model | page = Pages.Overview }, Api.tryAll RepositoriesResponse <| Api.getAllRepositories model )

        ( Routes.AddRepositories, True ) ->
            case model.sourceRepos of
                NotAsked ->
                    ( { model | page = Pages.AddRepositories, sourceRepos = Loading }
                    , Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model
                    )

                Failure _ ->
                    ( { model | page = Pages.AddRepositories, sourceRepos = Loading }
                    , Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model
                    )

                _ ->
                    ( { model | page = Pages.AddRepositories }, Cmd.none )

        ( Routes.Hooks org repo, True ) ->
            loadHooksPage model org repo

        ( Routes.Settings org repo, True ) ->
            loadSettingsPage model org repo

        ( Routes.RepositoryBuilds org repo, True ) ->
            loadRepoBuildsPage model org repo

        ( Routes.Build org repo buildNumber frag, True ) ->
            loadBuildPage model org repo buildNumber frag

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

        -- Hitting any page and not being logged in will land you on the login page
        ( _, False ) ->
            ( model
            , Cmd.batch
                [ Interop.storeSession <| encodeSession <| Session "" "" <| Url.toString model.entryURL
                , Navigation.pushUrl model.navigationKey <| Routes.routeToUrl Routes.Login
                ]
            )


{-| loadHooksPage : takes model org and repo and loads the hooks page.
-}
loadHooksPage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadHooksPage model org repo =
    -- Fetch builds from Api
    ( { model | page = Pages.Hooks org repo, hooks = Loading, hookBuilds = Dict.empty }
    , Cmd.batch
        [ getHooks model org repo
        ]
    )


{-| loadSettingsPage : takes model org and repo and loads the page for updating repo configurations
-}
loadSettingsPage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadSettingsPage model org repo =
    -- Fetch repo from Api
    ( { model | page = Pages.Settings org repo, repo = Loading, inTimeout = Nothing }
    , getRepo model org repo
    )


{-| loadRepoBuildsPage : takes model org and repo and loads the appropriate builds.

    loadRepoBuildsPage   Checks if the builds have already been loaded from the repo view. If not, fetches the builds from the Api.

-}
loadRepoBuildsPage : Model -> Org -> Repo -> ( Model, Cmd Msg )
loadRepoBuildsPage model org repo =
    let
        -- Builds already loaded
        loadedBuilds =
            model.builds

        -- Set builds to Loading
        loadingBuilds =
            { loadedBuilds | org = org, repo = repo, builds = Loading }
    in
    -- Fetch builds from Api
    ( { model | page = Pages.RepositoryBuilds org repo, builds = loadingBuilds }
    , Cmd.batch
        [ getBuilds model org repo
        ]
    )


{-| loadBuildPage : takes model org, repo, and build number and loads the appropriate build.

    loadBuildPage   Checks if the build has already been loaded from the repo view. If not, fetches the build from the Api.

-}
loadBuildPage : Model -> Org -> Repo -> BuildNumber -> Maybe String -> ( Model, Cmd Msg )
loadBuildPage model org repo buildNumber frag =
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
    ( { model | page = Pages.Build org repo buildNumber frag, builds = builds, build = Loading, steps = NotAsked, logs = [] }
    , Cmd.batch
        [ getBuilds model org repo
        , getBuild model org repo buildNumber
        , getAllBuildSteps model org repo buildNumber frag
        ]
    )


{-| updateSourceRepoStatus : update the UI state for source repos, single or by org
-}
updateSourceRepoStatus : Repository -> WebData Bool -> WebData SourceRepositories -> SourceRepoUpdateFunction -> WebData SourceRepositories
updateSourceRepoStatus repo status sourceRepos updateFn =
    case sourceRepos of
        Success repos ->
            case Dict.get repo.org repos of
                Just orgRepos ->
                    RemoteData.succeed <| updateSourceRepoDict repo status repos orgRepos updateFn

                _ ->
                    sourceRepos

        _ ->
            sourceRepos


{-| updateSourceRepoDict : update the dictionary containing org source repo lists
-}
updateSourceRepoDict : Repository -> WebData Bool -> Dict String Repositories -> Repositories -> SourceRepoUpdateFunction -> Dict String Repositories
updateSourceRepoDict repo status repos orgRepos updateFn =
    Dict.update repo.org (\_ -> Just <| updateFn repo status orgRepos) repos


{-| updateSourceRepoListByRepoName : list map for updating single repo status by repo name
-}
updateSourceRepoListByRepoName : Repository -> WebData Bool -> Repositories -> Repositories
updateSourceRepoListByRepoName repo status orgRepos =
    List.map
        (\sourceRepo ->
            if sourceRepo.name == repo.name then
                { sourceRepo | added = status }

            else
                sourceRepo
        )
        orgRepos


{-| buildAddRepositoryPayload : builds the payload for adding a repository via the api
-}
buildAddRepositoryPayload : Repository -> String -> AddRepositoryPayload
buildAddRepositoryPayload repo velaSourceBaseURL =
    { defaultAddRepositoryPayload
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


{-| toFailure : maps a detailed error into a WebData Failure value
-}
toFailure : Http.Detailed.Error String -> WebData a
toFailure error =
    Failure <| Errors.detailedErrorToError error


{-| stepsIDs : extracts IDs from list of steps and returns List Int
-}
stepsIDs : Steps -> List Int
stepsIDs steps =
    List.map (\step -> step.number) steps


{-| logIDs : extracts IDs from list of logs and returns List Int
-}
logIDs : Logs -> List Int
logIDs logs =
    List.map (\log -> log.id) <| successfulLogs logs


{-| logIDs : extracts successful logs from list of logs and returns List Log
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
            List.member incomingStep.number <| stepsIDs steps
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
            List.member incomingLog.id <| logIDs logs
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


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : RepoSearchFilters -> SourceRepositories -> Html Msg
searchReposGlobal filters repos =
    let
        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.map (\( _, repos_ ) -> repos_)
                |> List.concat
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo repo)

        else
            -- No repos matched the search
            [ div [ class "-no-repos" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : Org -> RepoSearchFilters -> Repositories -> ( Repositories, Bool, List (Html Msg) )
searchReposLocal org filters repos =
    -- Filter the repos if the user typed more than 2 characters
    let
        filteredRepos =
            List.filter (\repo -> filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map viewSourceRepo filteredRepos

      else
        [ div [ class "-no-repos" ] [ text "No results" ] ]
    )


{-| filterRepo : takes org/repo display filters, the org and filters a single repo based on user-entered text
-}
filterRepo : RepoSearchFilters -> Maybe Org -> String -> Bool
filterRepo filters org filterOn =
    let
        org_ =
            Maybe.withDefault "" <| org

        filterBy =
            Maybe.withDefault "" <| Dict.get org_ filters

        by =
            String.toLower filterBy

        on =
            String.toLower filterOn
    in
    String.contains by on


{-| searchFilterGlobal : takes repo search filters and returns the global filter (org == "")
-}
searchFilterGlobal : RepoSearchFilters -> SearchFilter
searchFilterGlobal filters =
    Maybe.withDefault "" <| Dict.get "" filters


{-| searchFilterLocal : takes repo search filters and org and returns the local filter
-}
searchFilterLocal : Org -> RepoSearchFilters -> SearchFilter
searchFilterLocal org filters =
    Maybe.withDefault "" <| Dict.get org filters


{-| shouldSearch : takes repo search filter and returns if results should be filtered
-}
shouldSearch : SearchFilter -> Bool
shouldSearch filter =
    String.length filter > 2


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


{-| clickStep : takes model org repo and step number and fetches step information from the api
-}
clickStep : Model -> Org -> Repo -> BuildNumber -> StepNumber -> ( WebData Steps, Cmd Msg )
clickStep model org repo buildNumber stepNumber =
    if stepNumber == "0" then
        ( model.steps
        , Cmd.none
        )

    else
        let
            ( steps, action ) =
                case model.steps of
                    Success steps_ ->
                        ( RemoteData.succeed <| toggleStepView steps_ stepNumber
                        , getBuildStepLogs model org repo buildNumber stepNumber
                        )

                    _ ->
                        ( model.steps, Cmd.none )
        in
        ( steps
        , action
        )


toggleStepView : Steps -> String -> Steps
toggleStepView steps stepNumber =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = not step.viewing })
        steps


{-| receiveHookBuild : takes org repo build and updates the appropriate build within hookbuilds
-}
receiveHookBuild : BuildIdentifier -> WebData Build -> HookBuilds -> HookBuilds
receiveHookBuild buildIdentifier build hookBuilds =
    Dict.update buildIdentifier (\_ -> Just ( build, viewingHook buildIdentifier hookBuilds )) hookBuilds


viewingHook : BuildIdentifier -> HookBuilds -> Bool
viewingHook buildIdentifier hookBuilds =
    case Dict.get buildIdentifier hookBuilds of
        Just ( _, viewing ) ->
            viewing

        Nothing ->
            False



-- API HELPERS


getHooks : Model -> Org -> Repo -> Cmd Msg
getHooks model org repo =
    Api.tryAll (HooksResponse org repo) <| Api.getAllHooks model org repo


getHookBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getHookBuild model org repo buildNumber =
    Api.try (HookBuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getRepo : Model -> Org -> Repo -> Cmd Msg
getRepo model org repo =
    Api.try RepoResponse <| Api.getRepo model org repo


getBuilds : Model -> Org -> Repo -> Cmd Msg
getBuilds model org repo =
    Api.tryAll (BuildsResponse org repo) <| Api.getAllBuilds model org repo


getBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.try (BuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getAllBuildSteps : Model -> Org -> Repo -> BuildNumber -> Maybe String -> Cmd Msg
getAllBuildSteps model org repo buildNumber frag =
    Api.try (StepsResponse org repo buildNumber frag) <| Api.getSteps model Nothing Nothing org repo buildNumber


getBuildStep : Model -> Org -> Repo -> BuildNumber -> StepNumber -> Cmd Msg
getBuildStep model org repo buildNumber stepNumber =
    Api.try (StepResponse org repo buildNumber stepNumber) <| Api.getStep model org repo buildNumber stepNumber


getBuildStepLogs : Model -> Org -> Repo -> BuildNumber -> StepNumber -> Cmd Msg
getBuildStepLogs model org repo buildNumber stepNumber =
    Api.try StepLogResponse <| Api.getStepLogs model org repo buildNumber stepNumber


getBuildStepsLogs : Model -> Org -> Repo -> BuildNumber -> WebData Steps -> Cmd Msg
getBuildStepsLogs model org repo buildNumber steps =
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
                    getBuildStepLogs model org repo buildNumber <| String.fromInt step.number

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
