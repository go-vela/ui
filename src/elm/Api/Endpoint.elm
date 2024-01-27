{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Endpoint exposing (Endpoint(..), toUrl)

import Api.Pagination as Pagination
import Auth.Session
import Url.Builder as UB exposing (QueryParameter)
import Vela


{-| apiBase : is the versioned base of all API paths
-}
apiBase : String
apiBase =
    "api/v1"


{-| Endpoint : represents any one unique API endpoint
-}
type Endpoint
    = Authenticate Auth.Session.AuthParams
    | Login
    | Logout
    | CurrentUser
    | Deployment Vela.Org Vela.Repo (Maybe String)
    | Deployments (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Org Vela.Repo
    | Token
    | Repositories (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Repository Vela.Org Vela.Repo
    | OrgRepositories (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Org
    | RepositoryChown Vela.Org Vela.Repo
    | RepositoryRepair Vela.Org Vela.Repo
    | UserSourceRepositories
    | Hooks (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Org Vela.Repo
    | Hook Vela.Org Vela.Repo Vela.HookNumber
    | OrgBuilds (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Vela.Event) Vela.Org
    | Builds (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Vela.Event) Vela.Org Vela.Repo
    | Build Vela.Org Vela.Repo Vela.BuildNumber
    | CancelBuild Vela.Org Vela.Repo Vela.BuildNumber
    | ApproveBuild Vela.Org Vela.Repo Vela.BuildNumber
    | Services (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Org Vela.Repo Vela.BuildNumber
    | ServiceLogs Vela.Org Vela.Repo Vela.BuildNumber Vela.ServiceNumber
    | Steps (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Org Vela.Repo Vela.BuildNumber
    | StepLogs Vela.Org Vela.Repo Vela.BuildNumber Vela.StepNumber
    | BuildGraph Vela.Org Vela.Repo Vela.BuildNumber
    | Schedule Vela.Org Vela.Repo String
    | Schedules (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Org Vela.Repo
    | Secrets (Maybe Pagination.Page) (Maybe Pagination.PerPage) Vela.Engine Vela.Type Vela.Org Vela.Name
    | Secret Vela.Engine Vela.Type Vela.Org String Vela.Name
    | PipelineConfig Vela.Org Vela.Repo Vela.Ref
    | ExpandPipelineConfig Vela.Org Vela.Repo Vela.Ref
    | PipelineTemplates Vela.Org Vela.Repo Vela.Ref


{-| toUrl : turns and Endpoint into a URL string
-}
toUrl : String -> Endpoint -> String
toUrl api endpoint =
    case endpoint of
        Authenticate { code, state } ->
            url api [ "authenticate" ] [ UB.string "code" <| Maybe.withDefault "" code, UB.string "state" <| Maybe.withDefault "" state ]

        Login ->
            url api [ "login" ] [ UB.string "type" "web" ]

        Logout ->
            url api [ "logout" ] []

        Token ->
            url api [ "token-refresh" ] []

        Repositories maybePage maybePerPage ->
            url api [ "repos" ] <| Pagination.toQueryParams maybePage maybePerPage

        Repository org repo ->
            url api [ "repos", org, repo ] []

        OrgRepositories maybePage maybePerPage org ->
            url api [ "repos", org ] <| Pagination.toQueryParams maybePage maybePerPage

        RepositoryChown org repo ->
            url api [ "repos", org, repo, "chown" ] []

        RepositoryRepair org repo ->
            url api [ "repos", org, repo, "repair" ] []

        CurrentUser ->
            url api [ "user" ] []

        UserSourceRepositories ->
            url api [ "user", "source", "repos" ] []

        Hooks maybePage maybePerPage org repo ->
            url api [ "hooks", org, repo ] <| Pagination.toQueryParams maybePage maybePerPage

        Hook org repo hookNumber ->
            url api [ "hooks", org, repo, hookNumber, "redeliver" ] []

        OrgBuilds maybePage maybePerPage maybeEvent org ->
            url api [ "repos", org, "builds" ] <| Pagination.toQueryParams maybePage maybePerPage ++ [ UB.string "event" <| Maybe.withDefault "" maybeEvent ]

        Builds maybePage maybePerPage maybeEvent org repo ->
            url api [ "repos", org, repo, "builds" ] <| Pagination.toQueryParams maybePage maybePerPage ++ [ UB.string "event" <| Maybe.withDefault "" maybeEvent ]

        Build org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber ] []

        CancelBuild org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "cancel" ] []

        ApproveBuild org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "approve" ] []

        Services maybePage maybePerPage org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "services" ] <| Pagination.toQueryParams maybePage maybePerPage

        ServiceLogs org repo buildNumber serviceNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "services", serviceNumber, "logs" ] []

        Steps maybePage maybePerPage org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "steps" ] <| Pagination.toQueryParams maybePage maybePerPage

        StepLogs org repo buildNumber stepNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "steps", stepNumber, "logs" ] []

        BuildGraph org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "graph" ] []

        Secrets maybePage maybePerPage engine type_ org key ->
            url api [ "secrets", engine, type_, org, key ] <| Pagination.toQueryParams maybePage maybePerPage

        Schedules maybePage maybePerPage org repo ->
            url api [ "schedules", org, repo ] <| Pagination.toQueryParams maybePage maybePerPage

        Schedule org repo name ->
            url api [ "schedules", org, repo, name ] []

        Secret engine type_ org key name ->
            url api [ "secrets", engine, type_, org, key, name ] []

        PipelineConfig org repo ref ->
            url api [ "pipelines", org, repo, ref ] []

        ExpandPipelineConfig org repo ref ->
            url api [ "pipelines", org, repo, ref, "expand" ] []

        PipelineTemplates org repo ref ->
            url api [ "pipelines", org, repo, ref, "templates" ] [ UB.string "output" "json" ]

        Deployment org repo deploymentNumber ->
            case deploymentNumber of
                Just id ->
                    url api [ "deployments", org, repo, id ] []

                Nothing ->
                    url api [ "deployments", org, repo ] []

        Deployments maybePage maybePerPage org repo ->
            url api [ "deployments", org, repo ] <| Pagination.toQueryParams maybePage maybePerPage


{-| url : creates a URL string with the given path segments and query parameters
-}
url : String -> List String -> List QueryParameter -> String
url api segments params =
    -- these endpoints don't live at the api base path
    case List.head segments of
        Just "authenticate" ->
            UB.crossOrigin api segments params

        Just "login" ->
            UB.crossOrigin api segments params

        Just "logout" ->
            UB.crossOrigin api segments params

        Just "token-refresh" ->
            UB.crossOrigin api segments params

        _ ->
            UB.crossOrigin api (apiBase :: List.filter (\s -> not <| String.isEmpty s) segments) params
