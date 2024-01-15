module Api.Operations_ exposing (enableRepo, finishAuthentication, getCurrentUser, getToken, getUserSourceRepos, logout, updateCurrentUser)

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
        , Build
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
        , Repository
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
        , decodeBuild
        , decodeBuildGraph
        , decodeBuilds
        , decodeCurrentUser
        , decodeDeployment
        , decodeDeployments
        , decodeHooks
        , decodeLog
        , decodePipelineConfig
        , decodePipelineExpand
        , decodePipelineTemplates
        , decodeRepositories
        , decodeRepository
        , decodeSchedule
        , decodeSchedules
        , decodeSecret
        , decodeSecrets
        , decodeService
        , decodeSourceRepositories
        , decodeStep
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
    get baseUrl Endpoint.CurrentUser decodeCurrentUser
        |> withAuth session


{-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-}
updateCurrentUser : String -> Session -> Http.Body -> Request CurrentUser
updateCurrentUser baseUrl session body =
    put baseUrl Endpoint.CurrentUser body decodeCurrentUser
        |> withAuth session


{-| getUserSourceRepos : retrieves the current users source repositories
-}
getUserSourceRepos : String -> Session -> Request SourceRepositories
getUserSourceRepos baseUrl session =
    get baseUrl Endpoint.UserSourceRepositories decodeSourceRepositories
        |> withAuth session


{-| enableRepo : enable a repo
-}
enableRepo : String -> Session -> Http.Body -> Request Repository
enableRepo baseUrl session body =
    post baseUrl (Endpoint.Repositories Nothing Nothing) body decodeRepository
        |> withAuth session
