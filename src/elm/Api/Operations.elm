{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Operations exposing
    ( enableRepo
    , finishAuthentication
    , getCurrentUser
    , getOrgRepos
    , getRepoBuilds
    , getRepoDeployments
    , getToken
    , getUserSourceRepos
    , logout
    , updateCurrentUser
    )

import Api.Api exposing (Request, delete, get, patch, post, put, withAuth)
import Api.Endpoint
import Auth.Jwt exposing (JwtAccessToken)
import Auth.Session exposing (Session(..))
import Http
import Json.Decode
import Vela



-- OPERATIONS


{-| getToken attempts to retrieve a new access token
-}
getToken : String -> Request JwtAccessToken
getToken baseUrl =
    get baseUrl Api.Endpoint.Token Auth.Jwt.decodeJwtAccessToken


{-| finishAuthentication : complete authentication by supplying code and state to the authenciate endpoint
which will also set the refresh token cookie
-}
finishAuthentication : String -> Vela.AuthParams -> Request JwtAccessToken
finishAuthentication baseUrl { code, state } =
    get baseUrl (Api.Endpoint.Authenticate { code = code, state = state }) Auth.Jwt.decodeJwtAccessToken


{-| logout: logs the user out by deleting the refresh token cookie
-}
logout : String -> Session -> Request String
logout baseUrl session =
    get baseUrl Api.Endpoint.Logout Json.Decode.string
        |> withAuth session


{-| getCurrentUser : retrieves the currently authenticated user with the current user endpoint
-}
getCurrentUser : String -> Session -> Request Vela.CurrentUser
getCurrentUser baseUrl session =
    get baseUrl Api.Endpoint.CurrentUser Vela.decodeCurrentUser
        |> withAuth session


{-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-}
updateCurrentUser : String -> Session -> Http.Body -> Request Vela.CurrentUser
updateCurrentUser baseUrl session body =
    put baseUrl Api.Endpoint.CurrentUser body Vela.decodeCurrentUser
        |> withAuth session


{-| getUserSourceRepos : retrieves the current users source repositories
-}
getUserSourceRepos : String -> Session -> Request Vela.SourceRepositories
getUserSourceRepos baseUrl session =
    get baseUrl Api.Endpoint.UserSourceRepositories Vela.decodeSourceRepositories
        |> withAuth session


{-| enableRepo : enables a repo
-}
enableRepo : String -> Session -> Http.Body -> Request Vela.Repository
enableRepo baseUrl session body =
    post baseUrl (Api.Endpoint.Repositories Nothing Nothing) body Vela.decodeRepository
        |> withAuth session


{-| getOrgRepos : retrieves the repositories for an org
-}
getOrgRepos : String -> Session -> { a | org : String } -> Request (List Vela.Repository)
getOrgRepos baseUrl session { org } =
    get baseUrl (Api.Endpoint.OrgRepositories Nothing Nothing org) Vela.decodeRepositories
        |> withAuth session


{-| getRepoBuilds : retrieves builds for a repo
-}
getRepoBuilds : String -> Session -> { a | org : String, repo : String, pageNumber : Maybe Int, perPage : Maybe Int, maybeEvent : Maybe String } -> Request (List Vela.Build)
getRepoBuilds baseUrl session options =
    get baseUrl (Api.Endpoint.Builds options.pageNumber options.perPage options.maybeEvent options.org options.repo) Vela.decodeBuilds
        |> withAuth session


{-| getRepoDeployments : retrieves deployments for a repo
-}
getRepoDeployments : String -> Session -> { a | org : String, repo : String, pageNumber : Maybe Int, perPage : Maybe Int } -> Request (List Vela.Deployment)
getRepoDeployments baseUrl session options =
    get baseUrl (Api.Endpoint.Deployments options.pageNumber options.perPage options.org options.repo) Vela.decodeDeployments
        |> withAuth session
