{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Api.Endpoint exposing (Endpoint(..), toUrl)

import Api.Pagination as Pagination
import Url.Builder as UB exposing (QueryParameter)
import Vela exposing (AuthParams, BuildNumber, Engine, Event, Name, Org, Ref, Repo, ServiceNumber, StepNumber, Type)


{-| apiBase : is the versioned base of all API paths
-}
apiBase : String
apiBase =
    "api/v1"


{-| Endpoint : represents any one unique API endpoint
-}
type Endpoint
    = Authenticate AuthParams
    | Login
    | Logout
    | CurrentUser
    | Token
    | Repositories (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Repository Org Repo
    | RepositoryChown Org Repo
    | RepositoryRepair Org Repo
    | UserSourceRepositories
    | Hooks (Maybe Pagination.Page) (Maybe Pagination.PerPage) Org Repo
    | Builds (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event) Org Repo
    | Build Org Repo BuildNumber
    | CancelBuild Org Repo BuildNumber
    | Services (Maybe Pagination.Page) (Maybe Pagination.PerPage) Org Repo BuildNumber
    | ServiceLogs Org Repo BuildNumber ServiceNumber
    | Steps (Maybe Pagination.Page) (Maybe Pagination.PerPage) Org Repo BuildNumber
    | StepLogs Org Repo BuildNumber StepNumber
    | Secrets (Maybe Pagination.Page) (Maybe Pagination.PerPage) Engine Type Org Name
    | Secret Engine Type Org String Name
    | PipelineConfig Org Repo (Maybe Ref)
    | ExpandPipelineConfig Org Repo (Maybe Ref)
    | PipelineTemplates Org Repo (Maybe Ref)


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

        Builds maybePage maybePerPage maybeEvent org repo ->
            url api [ "repos", org, repo, "builds" ] <| Pagination.toQueryParams maybePage maybePerPage ++ [ UB.string "event" <| Maybe.withDefault "" maybeEvent ]

        Build org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber ] []

        CancelBuild org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "cancel" ] []

        Services maybePage maybePerPage org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "services" ] <| Pagination.toQueryParams maybePage maybePerPage

        ServiceLogs org repo buildNumber serviceNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "services", serviceNumber, "logs" ] []

        Steps maybePage maybePerPage org repo buildNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "steps" ] <| Pagination.toQueryParams maybePage maybePerPage

        StepLogs org repo buildNumber stepNumber ->
            url api [ "repos", org, repo, "builds", buildNumber, "steps", stepNumber, "logs" ] []

        Secrets maybePage maybePerPage engine type_ org key ->
            url api [ "secrets", engine, type_, org, key ] <| Pagination.toQueryParams maybePage maybePerPage

        Secret engine type_ org key name ->
            url api [ "secrets", engine, type_, org, key, name ] []

        PipelineConfig org repo ref ->
            url api [ "pipelines", org, repo ] [ UB.string "ref" <| Maybe.withDefault "" ref ]

        ExpandPipelineConfig org repo ref ->
            url api [ "pipelines", org, repo, "expand" ] [ UB.string "ref" <| Maybe.withDefault "" ref ]

        PipelineTemplates org repo ref ->
            url api [ "pipelines", org, repo, "templates" ] [ UB.string "output" "json", UB.string "ref" <| Maybe.withDefault "" ref ]


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
            UB.crossOrigin api (apiBase :: segments) params
