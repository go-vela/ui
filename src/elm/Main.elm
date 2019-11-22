{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Main exposing (main)

import Alerts exposing (Alert)
import Api
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Navigation
import Build exposing (viewFullBuild, viewRepositoryBuilds)
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
import List.Extra exposing (setIf)
import Pages exposing (Page(..))
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (velaLogo)
import Task exposing (perform, succeed)
import Time exposing (utc)
import Toasty as Alerting exposing (Stack)
import Url exposing (Url)
import Url.Builder as UB exposing (QueryParameter)
import Util
import Vela
    exposing
        ( AddRepositoryPayload
        , AuthParams
        , Build
        , BuildNumber
        , Builds
        , BuildsModel
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
        , User
        , decodeSession
        , defaultAddRepositoryPayload
        , defaultBuilds
        , defaultSession
        , encodeAddRepository
        , encodeSession
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
    , zone : Time.Zone
    , time : Time.Posix
    , source_search_filters : RepoSearchFilters
    , entryURL : Url
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
            , zone = Time.utc
            , time = Time.millisToPosix 0
            , source_search_filters = Dict.empty
            , entryURL = url
            }

        ( newModel, newPage ) =
            setNewPage (Routes.match url) model

        setTimeZone =
            Task.perform AdjustTimeZone Time.here

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
      -- Outgoing HTTP requests
    | SignInRequested
    | FetchSourceRepositories
    | AddRepo Repository
    | AddOrgRepos Repositories
    | RemoveRepo Repository
    | RestartBuild Org Repo BuildNumber
    | GetBuilds Org Repo
      -- Inbound HTTP responses
    | UserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, User ))
    | RepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Repositories ))
    | SourceRepositoriesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | RepoAddedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | RepoRemovedResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | RestartedBuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | BuildsResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Builds ))
    | StepsResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | StepLogResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
      -- Other
    | Error String
    | AlertsUpdate (Alerting.Msg Alert)
    | SessionChanged (Maybe Session)
      -- Time
    | AdjustTimeZone Time.Zone
    | AdjustTime Time.Posix
    | Tick Interval Time.Posix


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

        FetchSourceRepositories ->
            ( { model | sourceRepos = Loading, source_search_filters = Dict.empty }, Api.try SourceRepositoriesResponse <| Api.getSourceRepositories model )

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
                        |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Success "Success" (repo.full_name ++ " added.") Nothing)

                Err error ->
                    ( { model | sourceRepos = updateSourceRepoStatus repo (toFailure error) model.sourceRepos updateSourceRepoListByRepoName }, addError error )

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

        StepsResponse org repo buildNumber response ->
            case response of
                Ok ( _, stepsResponse ) ->
                    let
                        steps =
                            RemoteData.succeed stepsResponse

                        cmd =
                            getBuildStepsLogs model org repo buildNumber steps
                    in
                    ( { model | steps = steps }, cmd )

                Err error ->
                    ( model, addError error )

        StepLogResponse _ _ _ _ response ->
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

        AddOrgRepos repos ->
            ( model
            , Cmd.batch <| List.map (Util.dispatch << AddRepo) repos
            )

        GetBuilds org repo ->
            let
                currentBuilds =
                    model.builds
            in
            ( { model | builds = { currentBuilds | org = org, repo = repo, builds = Loading } }
            , getBuilds model org repo
            )

        RestartBuild org repo buildNumber ->
            ( model
            , restartBuild model org repo buildNumber
            )

        Error error ->
            ( model, Cmd.none )
                |> Alerting.addToastIfUnique Alerts.config AlertsUpdate (Alerts.Error "Error" error)

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
                    Dict.update org (\_ -> Just searchBy) model.source_search_filters
            in
            ( { model | source_search_filters = filters }, Cmd.none )

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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Interop.onSessionChange decodeOnSessionChange
        , Time.every Util.oneSecondMillis <| Tick OneSecond
        , Time.every Util.fiveSecondsMillis <| Tick (FiveSecond <| refreshData model)
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

        Pages.Build org repo buildNumber ->
            Cmd.batch
                [ getBuilds model org repo
                , refreshBuild model org repo buildNumber
                , refreshBuildSteps model org repo buildNumber
                , refreshLogs model org repo buildNumber model.steps
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

        Failure _ ->
            True

        -- Do not refresh a Loading build
        Loading ->
            False


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

        Pages.RepositoryBuilds org repo ->
            ( "Repository Builds"
            , viewRepositoryBuilds model.builds.builds model.time org repo
            )

        Pages.Build org repo _ ->
            ( "Build"
            , viewFullBuild model.time org repo model.build model.steps model.logs
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
            [ button [ class "-inverted", Util.testAttribute "repo-remove", onClick <| RemoveRepo repo ] [ text "Remove" ]
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
    if shouldSearch <| searchFilterGlobal model.source_search_filters then
        -- Search and render repos using the global filter
        searchReposGlobal model.source_search_filters sourceRepos

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
            if shouldSearch <| searchFilterLocal org model.source_search_filters then
                -- Search and render repos using the global filter
                searchReposLocal org model.source_search_filters repos

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
            , value <| searchFilterGlobal model.source_search_filters
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
            , value <| searchFilterLocal org model.source_search_filters
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

        Pages.Build org repo buildNumber ->
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

        ( Routes.RepositoryBuilds org repo, True ) ->
            loadRepoBuildsPage model org repo

        ( Routes.Build org repo buildNumber, True ) ->
            loadBuildPage model org repo buildNumber

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
loadBuildPage : Model -> Org -> Repo -> BuildNumber -> ( Model, Cmd Msg )
loadBuildPage model org repo buildNumber =
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
    ( { model | page = Pages.Build org repo buildNumber, builds = builds, build = Loading, steps = NotAsked, logs = [] }
    , Cmd.batch
        [ getBuilds model org repo
        , getBuild model org repo buildNumber
        , getAllBuildSteps model org repo buildNumber
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
    List.map (\log -> log.id) logs


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
        { model | steps = RemoteData.succeed <| setIf (\step -> incomingStep.number == step.number) incomingStep steps }

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
        { model | logs = setIf (\log -> incomingLog.id == log.id && incomingLog.data /= log.data) incomingLog logs }

    else
        { model | logs = incomingLog :: logs }


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



-- API HELPERS


getBuilds : Model -> Org -> Repo -> Cmd Msg
getBuilds model org repo =
    Api.tryAll (BuildsResponse org repo) <| Api.getAllBuilds model org repo


getBuild : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getBuild model org repo buildNumber =
    Api.try (BuildResponse org repo buildNumber) <| Api.getBuild model org repo buildNumber


getAllBuildSteps : Model -> Org -> Repo -> BuildNumber -> Cmd Msg
getAllBuildSteps model org repo buildNumber =
    Api.try (StepsResponse org repo buildNumber) <| Api.getSteps model Nothing Nothing org repo buildNumber


getBuildStep : Model -> Org -> Repo -> BuildNumber -> StepNumber -> Cmd Msg
getBuildStep model org repo buildNumber stepNumber =
    Api.try (StepResponse org repo buildNumber stepNumber) <| Api.getStep model org repo buildNumber stepNumber


getBuildStepLogs : Model -> Org -> Repo -> BuildNumber -> StepNumber -> Cmd Msg
getBuildStepLogs model org repo buildNumber stepNumber =
    Api.try (StepLogResponse org repo buildNumber stepNumber) <| Api.getStepLogs model org repo buildNumber stepNumber


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
                if True then
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
