{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Operations_ exposing
    ( cancelBuild
    , enableRepo
    , finishAuthentication
    , getCurrentUser
    , getOrgRepos
    , getRepoBuilds
    , getRepoDeployments
    , getToken
    , getUserSourceRepos
    , logout
    , restartBuild
    , updateCurrentUser
    )

import Api.Api exposing (Request, delete, get, patch, post, put, withAuth)
import Api.Endpoint as Endpoint exposing (Endpoint)
import Api.Pagination as Pagination
import Auth.Jwt exposing (JwtAccessToken, decodeJwtAccessToken)
import Auth.Session exposing (Session(..))
import Http
import Json.Decode
import Vela
    exposing
        ( AuthParams
        , BuildGraph
        , BuildNumber
        , Builds
        , CurrentUser
        , Deployment
        , DeploymentId
        , Engine
        , Event
        , Hook
        , HookNumber
        , Hooks
        , Key
        , Log
        , Name
        , Org
        , PipelineConfig
        , Ref
        , Repo
        , Schedule
        , ScheduleName
        , Schedules
        , Secret
        , Secrets
        , Service
        , ServiceNumber
        , SourceRepositories
        , Step
        , StepNumber
        , Templates
        , Type
        )



-- OPERATIONS


{-| getToken attempts to retrieve a new access token
-}
getToken : String -> Request JwtAccessToken
getToken baseUrl =
    get baseUrl Endpoint.Token decodeJwtAccessToken


{-| finishAuthentication : complete authentication by supplying code and state to the authenciate endpoint
which will also set the refresh token cookie
-}
finishAuthentication : String -> AuthParams -> Request JwtAccessToken
finishAuthentication baseUrl { code, state } =
    get baseUrl (Endpoint.Authenticate { code = code, state = state }) decodeJwtAccessToken


{-| logout: logs the user out by deleting the refresh token cookie
-}
logout : String -> Session -> Request String
logout baseUrl session =
    get baseUrl Endpoint.Logout Json.Decode.string
        |> withAuth session


{-| getCurrentUser : retrieves the currently authenticated user with the current user endpoint
-}
getCurrentUser : String -> Session -> Request CurrentUser
getCurrentUser baseUrl session =
    get baseUrl Endpoint.CurrentUser Vela.decodeCurrentUser
        |> withAuth session


{-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-}
updateCurrentUser : String -> Session -> Http.Body -> Request CurrentUser
updateCurrentUser baseUrl session body =
    put baseUrl Endpoint.CurrentUser body Vela.decodeCurrentUser
        |> withAuth session


{-| getUserSourceRepos : retrieves the current users source repositories
-}
getUserSourceRepos : String -> Session -> Request SourceRepositories
getUserSourceRepos baseUrl session =
    get baseUrl Endpoint.UserSourceRepositories Vela.decodeSourceRepositories
        |> withAuth session


{-| enableRepo : enables a repo
-}
enableRepo : String -> Session -> Http.Body -> Request Vela.Repository
enableRepo baseUrl session body =
    post baseUrl (Endpoint.Repositories Nothing Nothing) body Vela.decodeRepository
        |> withAuth session


{-| getOrgRepos : retrieves the repositories for an org
-}
getOrgRepos : String -> Session -> { a | org : String } -> Request (List Vela.Repository)
getOrgRepos baseUrl session { org } =
    get baseUrl (Endpoint.OrgRepositories Nothing Nothing org) Vela.decodeRepositories
        |> withAuth session


{-| getRepoBuilds : retrieves builds for a repo
-}
getRepoBuilds : String -> Session -> { a | org : String, repo : String, pageNumber : Maybe Int, perPage : Maybe Int, maybeEvent : Maybe String } -> Request (List Vela.Build)
getRepoBuilds baseUrl session options =
    get baseUrl (Endpoint.Builds options.pageNumber options.perPage options.maybeEvent options.org options.repo) Vela.decodeBuilds
        |> withAuth session


restartBuild : String -> Session -> { a | org : String, repo : String, buildNumber : String } -> Request Vela.Build
restartBuild baseUrl session options =
    post baseUrl (Endpoint.Build options.org options.repo options.buildNumber) Http.emptyBody Vela.decodeBuild
        |> withAuth session


cancelBuild : String -> Session -> { a | org : String, repo : String, buildNumber : String } -> Request Vela.Build
cancelBuild baseUrl session options =
    delete baseUrl (Endpoint.CancelBuild options.org options.repo options.buildNumber) Vela.decodeBuild
        |> withAuth session


{-| getRepoDeployments : retrieves deployments for a repo
-}
getRepoDeployments : String -> Session -> { a | org : String, repo : String, pageNumber : Maybe Int, perPage : Maybe Int } -> Request (List Vela.Deployment)
getRepoDeployments baseUrl session options =
    get baseUrl (Endpoint.Deployments options.pageNumber options.perPage options.org options.repo) Vela.decodeDeployments
        |> withAuth session
