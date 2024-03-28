{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Operations exposing
    ( addDeployment
    , addOrgSecret
    , addRepoSchedule
    , addRepoSecret
    , addSharedSecret
    , approveBuild
    , cancelBuild
    , chownRepo
    , deleteOrgSecret
    , deleteRepoSchedule
    , deleteRepoSecret
    , deleteSharedSecret
    , disableRepo
    , enableRepo
    , expandPipelineConfig
    , finishAuthentication
    , getBuild
    , getBuildGraph
    , getBuildServiceLog
    , getBuildServices
    , getBuildStepLog
    , getBuildSteps
    , getCurrentUser
    , getOrgBuilds
    , getOrgRepos
    , getOrgSecret
    , getOrgSecrets
    , getPipelineConfig
    , getPipelineTemplates
    , getRepo
    , getRepoBuilds
    , getRepoDeployments
    , getRepoHooks
    , getRepoSchedule
    , getRepoSchedules
    , getRepoSecret
    , getRepoSecrets
    , getSharedSecret
    , getSharedSecrets
    , getToken
    , getUserSourceRepos
    , logout
    , redeliverHook
    , repairRepo
    , restartBuild
    , updateCurrentUser
    , updateOrgSecret
    , updateRepo
    , updateRepoSchedule
    , updateRepoSecret
    , updateSharedSecret
    )

import Api.Api exposing (Request, delete, get, patch, post, put, withAuth)
import Api.Endpoint
import Auth.Jwt exposing (JwtAccessToken)
import Auth.Session exposing (Session(..))
import Dict exposing (Dict)
import Html exposing (option)
import Http
import Json.Decode
import Vela



-- OPERATIONS


{-| getToken attempts to retrieve a new access token
-}
getToken : String -> Request JwtAccessToken
getToken baseUrl =
    get baseUrl
        Api.Endpoint.Token
        Auth.Jwt.decodeJwtAccessToken


{-| finishAuthentication : complete authentication by supplying code and state to the authenciate endpoint
which will also set the refresh token cookie
-}
finishAuthentication : String -> Auth.Session.AuthParams -> Request JwtAccessToken
finishAuthentication baseUrl { code, state } =
    get baseUrl
        (Api.Endpoint.Authenticate { code = code, state = state })
        Auth.Jwt.decodeJwtAccessToken


{-| logout: logs the user out by deleting the refresh token cookie
-}
logout : String -> Session -> Request String
logout baseUrl session =
    get baseUrl
        Api.Endpoint.Logout
        Json.Decode.string
        |> withAuth session


{-| getCurrentUser : retrieves the currently authenticated user with the current user endpoint
-}
getCurrentUser : String -> Session -> Request Vela.CurrentUser
getCurrentUser baseUrl session =
    get baseUrl
        Api.Endpoint.CurrentUser
        Vela.decodeCurrentUser
        |> withAuth session


{-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-}
updateCurrentUser : String -> Session -> Http.Body -> Request Vela.CurrentUser
updateCurrentUser baseUrl session body =
    put baseUrl
        Api.Endpoint.CurrentUser
        body
        Vela.decodeCurrentUser
        |> withAuth session


{-| getUserSourceRepos : retrieves the current users source repositories
-}
getUserSourceRepos : String -> Session -> Request Vela.SourceRepositories
getUserSourceRepos baseUrl session =
    get baseUrl
        Api.Endpoint.UserSourceRepositories
        Vela.decodeSourceRepositories
        |> withAuth session


{-| getRepo : retrieves a repo
-}
getRepo : String -> Session -> { a | org : String, repo : String } -> Request Vela.Repository
getRepo baseUrl session options =
    get baseUrl
        (Api.Endpoint.Repository
            options.org
            options.repo
        )
        Vela.decodeRepository
        |> withAuth session


{-| enableRepo : enables a repo
-}
enableRepo : String -> Session -> Http.Body -> Request Vela.Repository
enableRepo baseUrl session body =
    post baseUrl
        (Api.Endpoint.Repositories
            Nothing
            Nothing
        )
        body
        Vela.decodeRepository
        |> withAuth session


{-| updateRepo : updates a repo
-}
updateRepo : String -> Session -> { a | org : String, repo : String, body : Http.Body } -> Request Vela.Repository
updateRepo baseUrl session options =
    put baseUrl
        (Api.Endpoint.Repository
            options.org
            options.repo
        )
        options.body
        Vela.decodeRepository
        |> withAuth session


{-| repairRepo : repairs a repo
-}
repairRepo : String -> Session -> { a | org : String, repo : String } -> Request String
repairRepo baseUrl session options =
    patch baseUrl
        (Api.Endpoint.RepositoryRepair
            options.org
            options.repo
        )
        Json.Decode.string
        |> withAuth session


{-| chownRepo : chowns a repo
-}
chownRepo : String -> Session -> { a | org : String, repo : String } -> Request String
chownRepo baseUrl session options =
    patch baseUrl
        (Api.Endpoint.RepositoryChown
            options.org
            options.repo
        )
        Json.Decode.string
        |> withAuth session


{-| disableRepo : disables a repo
-}
disableRepo : String -> Session -> { a | org : String, repo : String } -> Request String
disableRepo baseUrl session options =
    delete baseUrl
        (Api.Endpoint.Repository
            options.org
            options.repo
        )
        Json.Decode.string
        |> withAuth session


{-| getOrgRepos : retrieves the repositories for an org
-}
getOrgRepos :
    String
    -> Session
    ->
        { a
            | org : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Repository)
getOrgRepos baseUrl session options =
    get baseUrl
        (Api.Endpoint.OrgRepositories
            options.pageNumber
            options.perPage
            options.org
        )
        Vela.decodeRepositories
        |> withAuth session


{-| getOrgBuilds : retrieves builds for an org
-}
getOrgBuilds :
    String
    -> Session
    ->
        { a
            | org : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
            , maybeEvent : Maybe String
        }
    -> Request (List Vela.Build)
getOrgBuilds baseUrl session options =
    get baseUrl
        (Api.Endpoint.OrgBuilds
            options.pageNumber
            options.perPage
            options.maybeEvent
            options.org
        )
        Vela.decodeBuilds
        |> withAuth session


{-| getRepoBuilds : retrieves builds for a repo
-}
getRepoBuilds :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
            , maybeEvent : Maybe String
        }
    -> Request (List Vela.Build)
getRepoBuilds baseUrl session options =
    get baseUrl
        (Api.Endpoint.Builds
            options.pageNumber
            options.perPage
            options.maybeEvent
            options.org
            options.repo
        )
        Vela.decodeBuilds
        |> withAuth session


{-| restartBuild : restarts a build
-}
restartBuild :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
        }
    -> Request Vela.Build
restartBuild baseUrl session options =
    post baseUrl
        (Api.Endpoint.Build
            options.org
            options.repo
            options.build
        )
        Http.emptyBody
        Vela.decodeBuild
        |> withAuth session


{-| cancelBuild : cancels a build
-}
cancelBuild :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
        }
    -> Request Vela.Build
cancelBuild baseUrl session options =
    delete baseUrl
        (Api.Endpoint.CancelBuild
            options.org
            options.repo
            options.build
        )
        Vela.decodeBuild
        |> withAuth session


{-| approveBuild : approves a build
-}
approveBuild :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
        }
    -> Request Vela.Build
approveBuild baseUrl session options =
    post baseUrl
        (Api.Endpoint.ApproveBuild
            options.org
            options.repo
            options.build
        )
        Http.emptyBody
        Vela.decodeBuild
        |> withAuth session


{-| getRepoDeployments : retrieves deployments for a repo
-}
getRepoDeployments :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Deployment)
getRepoDeployments baseUrl session options =
    get baseUrl
        (Api.Endpoint.Deployments
            options.pageNumber
            options.perPage
            options.org
            options.repo
        )
        Vela.decodeDeployments
        |> withAuth session


{-| addDeployment : adds a deployment for a repo
-}
addDeployment :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , body : Http.Body
        }
    -> Request Vela.Deployment
addDeployment baseUrl session options =
    post baseUrl
        (Api.Endpoint.Deployment
            options.org
            options.repo
            Nothing
        )
        options.body
        Vela.decodeDeployment
        |> withAuth session


{-| getRepoHooks : retrieves hooks for a repo
-}
getRepoHooks :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Hook)
getRepoHooks baseUrl session options =
    get baseUrl
        (Api.Endpoint.Hooks
            options.pageNumber
            options.perPage
            options.org
            options.repo
        )
        Vela.decodeHooks
        |> withAuth session


{-| getRepoSchedules : retrieves schedules for a repo
-}
getRepoSchedules :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Schedule)
getRepoSchedules baseUrl session options =
    get baseUrl
        (Api.Endpoint.Schedules
            options.pageNumber
            options.perPage
            options.org
            options.repo
        )
        Vela.decodeSchedules
        |> withAuth session


{-| getRepoSchedule : retrieves a schedule for a repo
-}
getRepoSchedule :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , name : String
        }
    -> Request Vela.Schedule
getRepoSchedule baseUrl session options =
    get baseUrl
        (Api.Endpoint.Schedule
            options.org
            options.repo
            options.name
        )
        Vela.decodeSchedule
        |> withAuth session


{-| addRepoSchedule : adds a repo schedule
-}
addRepoSchedule :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , name : String
            , body : Http.Body
        }
    -> Request Vela.Schedule
addRepoSchedule baseUrl session options =
    post baseUrl
        (Api.Endpoint.Schedule
            options.org
            options.repo
            ""
        )
        options.body
        Vela.decodeSchedule
        |> withAuth session


{-| updateRepoSchedule : updates a repo schedule
-}
updateRepoSchedule :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , name : String
            , body : Http.Body
        }
    -> Request Vela.Schedule
updateRepoSchedule baseUrl session options =
    put baseUrl
        (Api.Endpoint.Schedule
            options.org
            options.repo
            options.name
        )
        options.body
        Vela.decodeSchedule
        |> withAuth session


{-| deleteRepoSchedule : deletes a repo schedule
-}
deleteRepoSchedule :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , name : String
        }
    -> Request String
deleteRepoSchedule baseUrl session options =
    delete baseUrl
        (Api.Endpoint.Schedule
            options.org
            options.repo
            options.name
        )
        Json.Decode.string
        |> withAuth session


{-| redeliverHook : redelivers a hook for a repo
-}
redeliverHook :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , hookNumber : String
        }
    -> Request String
redeliverHook baseUrl session options =
    post baseUrl
        (Api.Endpoint.Hook
            options.org
            options.repo
            options.hookNumber
        )
        Http.emptyBody
        Json.Decode.string
        |> withAuth session


{-| getBuild : retrieves a build
-}
getBuild :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
        }
    -> Request Vela.Build
getBuild baseUrl session options =
    get baseUrl
        (Api.Endpoint.Build
            options.org
            options.repo
            options.build
        )
        Vela.decodeBuild
        |> withAuth session


{-| getBuildSteps : retrieves steps for a build
-}
getBuildSteps :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Step)
getBuildSteps baseUrl session options =
    get baseUrl
        (Api.Endpoint.Steps
            options.pageNumber
            options.perPage
            options.org
            options.repo
            options.build
        )
        Vela.decodeSteps
        |> withAuth session


{-| getBuildServices: retrieves services for a build
-}
getBuildServices :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Service)
getBuildServices baseUrl session options =
    get baseUrl
        (Api.Endpoint.Services
            options.pageNumber
            options.perPage
            options.org
            options.repo
            options.build
        )
        Vela.decodeServices
        |> withAuth session


{-| getBuildStepLog: retrieves a log for a step
-}
getBuildStepLog :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
            , stepNumber : String
        }
    -> Request Vela.Log
getBuildStepLog baseUrl session options =
    get baseUrl
        (Api.Endpoint.StepLogs
            options.org
            options.repo
            options.build
            options.stepNumber
        )
        Vela.decodeLog
        |> withAuth session


{-| getBuildServiceLog: retrieves a log for a service
-}
getBuildServiceLog :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
            , serviceNumber : String
        }
    -> Request Vela.Log
getBuildServiceLog baseUrl session options =
    get baseUrl
        (Api.Endpoint.ServiceLogs
            options.org
            options.repo
            options.build
            options.serviceNumber
        )
        Vela.decodeLog
        |> withAuth session


{-| getPipelineConfig: retrieves a pipeline config for a ref
-}
getPipelineConfig :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , ref : String
        }
    -> Request Vela.PipelineConfig
getPipelineConfig baseUrl session options =
    get baseUrl
        (Api.Endpoint.PipelineConfig
            options.org
            options.repo
            options.ref
        )
        Vela.decodePipelineConfig
        |> withAuth session


{-| expandPipelineConfig: retrieves an expanded pipeline config for a ref
-}
expandPipelineConfig :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , ref : String
        }
    -> Request String
expandPipelineConfig baseUrl session options =
    post baseUrl
        (Api.Endpoint.ExpandPipelineConfig
            options.org
            options.repo
            options.ref
        )
        Http.emptyBody
        Json.Decode.string
        |> withAuth session


{-| getPipelineTemplates: retrieves templates for a pipeline ref
-}
getPipelineTemplates :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , ref : String
        }
    -> Request (Dict String Vela.Template)
getPipelineTemplates baseUrl session options =
    get baseUrl
        (Api.Endpoint.PipelineTemplates
            options.org
            options.repo
            options.ref
        )
        Vela.decodePipelineTemplates
        |> withAuth session


{-| getBuildGraph: retrieves a graph for a build
-}
getBuildGraph :
    String
    -> Session
    ->
        { a
            | org : String
            , repo : String
            , build : String
        }
    -> Request Vela.BuildGraph
getBuildGraph baseUrl session options =
    get baseUrl
        (Api.Endpoint.BuildGraph
            options.org
            options.repo
            options.build
        )
        Vela.decodeBuildGraph
        |> withAuth session


{-| getOrgSecrets : retrieves secrets for an org
-}
getOrgSecrets :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Secret)
getOrgSecrets baseUrl session options =
    get baseUrl
        (Api.Endpoint.Secrets
            options.pageNumber
            options.perPage
            options.engine
            "org"
            options.org
            "*"
        )
        Vela.decodeSecrets
        |> withAuth session


{-| getOrgSecret : retrieves a secret for an org
-}
getOrgSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , name : String
        }
    -> Request Vela.Secret
getOrgSecret baseUrl session options =
    get baseUrl
        (Api.Endpoint.Secret
            options.engine
            "org"
            options.org
            "*"
            options.name
        )
        Vela.decodeSecret
        |> withAuth session


{-| updateOrgSecret : updates a secret for an org
-}
updateOrgSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , name : String
            , body : Http.Body
        }
    -> Request Vela.Secret
updateOrgSecret baseUrl session options =
    put baseUrl
        (Api.Endpoint.Secret
            options.engine
            "org"
            options.org
            "*"
            options.name
        )
        options.body
        Vela.decodeSecret
        |> withAuth session


{-| addOrgSecret : adds an org secret
-}
addOrgSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , body : Http.Body
        }
    -> Request Vela.Secret
addOrgSecret baseUrl session options =
    post baseUrl
        (Api.Endpoint.Secrets
            Nothing
            Nothing
            options.engine
            "org"
            options.org
            "*"
        )
        options.body
        Vela.decodeSecret
        |> withAuth session


{-| deleteOrgSecret : deletes a secret for an org
-}
deleteOrgSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , name : String
        }
    -> Request String
deleteOrgSecret baseUrl session options =
    delete baseUrl
        (Api.Endpoint.Secret
            options.engine
            "org"
            options.org
            "*"
            options.name
        )
        Json.Decode.string
        |> withAuth session


{-| getRepoSecrets : retrieves secrets for a repo
-}
getRepoSecrets :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , repo : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Secret)
getRepoSecrets baseUrl session options =
    get baseUrl
        (Api.Endpoint.Secrets
            options.pageNumber
            options.perPage
            options.engine
            "repo"
            options.org
            options.repo
        )
        Vela.decodeSecrets
        |> withAuth session


{-| getRepoSecret : retrieve a secret for a repo
-}
getRepoSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , repo : String
            , name : String
        }
    -> Request Vela.Secret
getRepoSecret baseUrl session options =
    get baseUrl
        (Api.Endpoint.Secret
            options.engine
            "repo"
            options.org
            options.repo
            options.name
        )
        Vela.decodeSecret
        |> withAuth session


{-| updateRepoSecret : updates a secret for a repo
-}
updateRepoSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , repo : String
            , name : String
            , body : Http.Body
        }
    -> Request Vela.Secret
updateRepoSecret baseUrl session options =
    put baseUrl
        (Api.Endpoint.Secret
            options.engine
            "repo"
            options.org
            options.repo
            options.name
        )
        options.body
        Vela.decodeSecret
        |> withAuth session


{-| addRepoSecret : adds a repo secret
-}
addRepoSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , repo : String
            , body : Http.Body
        }
    -> Request Vela.Secret
addRepoSecret baseUrl session options =
    post baseUrl
        (Api.Endpoint.Secrets
            Nothing
            Nothing
            options.engine
            "repo"
            options.org
            options.repo
        )
        options.body
        Vela.decodeSecret
        |> withAuth session


{-| deleteRepoSecret : deletes a secret for a repo
-}
deleteRepoSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , repo : String
            , name : String
        }
    -> Request String
deleteRepoSecret baseUrl session options =
    delete baseUrl
        (Api.Endpoint.Secret
            options.engine
            "repo"
            options.org
            options.repo
            options.name
        )
        Json.Decode.string
        |> withAuth session


{-| getSharedSecrets : retrieves secrets for an org/team
-}
getSharedSecrets :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , team : String
            , pageNumber : Maybe Int
            , perPage : Maybe Int
        }
    -> Request (List Vela.Secret)
getSharedSecrets baseUrl session options =
    get baseUrl
        (Api.Endpoint.Secrets
            options.pageNumber
            options.perPage
            options.engine
            "shared"
            options.org
            options.team
        )
        Vela.decodeSecrets
        |> withAuth session


{-| getSharedSecret : retrieve a secret for an org/team
-}
getSharedSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , team : String
            , name : String
        }
    -> Request Vela.Secret
getSharedSecret baseUrl session options =
    get baseUrl
        (Api.Endpoint.Secret
            options.engine
            "shared"
            options.org
            options.team
            options.name
        )
        Vela.decodeSecret
        |> withAuth session


{-| updateSharedSecret : updates a secret for an org/team
-}
updateSharedSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , team : String
            , name : String
            , body : Http.Body
        }
    -> Request Vela.Secret
updateSharedSecret baseUrl session options =
    put baseUrl
        (Api.Endpoint.Secret
            options.engine
            "shared"
            options.org
            options.team
            options.name
        )
        options.body
        Vela.decodeSecret
        |> withAuth session


{-| addSharedSecret : adds a shared secret
-}
addSharedSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , team : String
            , body : Http.Body
        }
    -> Request Vela.Secret
addSharedSecret baseUrl session options =
    post baseUrl
        (Api.Endpoint.Secrets
            Nothing
            Nothing
            options.engine
            "shared"
            options.org
            options.team
        )
        options.body
        Vela.decodeSecret
        |> withAuth session


{-| deleteSharedSecret : deletes a secret for an org/team
-}
deleteSharedSecret :
    String
    -> Session
    ->
        { a
            | engine : String
            , org : String
            , team : String
            , name : String
        }
    -> Request String
deleteSharedSecret baseUrl session options =
    delete baseUrl
        (Api.Endpoint.Secret
            options.engine
            "shared"
            options.org
            options.team
            options.name
        )
        Json.Decode.string
        |> withAuth session
