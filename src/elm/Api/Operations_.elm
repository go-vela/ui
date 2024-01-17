{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Operations_ exposing
    ( enableRepo
    , finishAuthentication
    , getCurrentUser
    , getOrgRepoBuilds
    , getOrgRepos
    , getToken
    , getUserSourceRepos
    , logout
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


{-| enableRepo : enable a repo
-}
enableRepo : String -> Session -> Http.Body -> Request Vela.Repository
enableRepo baseUrl session body =
    post baseUrl (Endpoint.Repositories Nothing Nothing) body Vela.decodeRepository
        |> withAuth session


{-| getOrgRepos : retrieves the current users source repositories
-}
getOrgRepos : String -> Session -> { a | org : String } -> Request (List Vela.Repository)
getOrgRepos baseUrl session { org } =
    get baseUrl (Endpoint.OrgRepositories Nothing Nothing org) Vela.decodeRepositories
        |> withAuth session


{-| getOrgRepoBuilds : retrieves the current users source repositories
-}
getOrgRepoBuilds : String -> Session -> { a | org : String, repo : String } -> Request (List Vela.Build)
getOrgRepoBuilds baseUrl session { org, repo } =
    get baseUrl (Endpoint.Builds Nothing Nothing Nothing org repo) Vela.decodeBuilds
        |> withAuth session
