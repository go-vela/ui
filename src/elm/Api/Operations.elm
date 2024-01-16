{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Operations exposing
    ( addDeployment
    , addSchedule
    , addSecret
    , approveBuild
    , cancelBuild
    , chownRepo
    , deleteRepo
    , deleteSchedule
    , deleteSecret
    , enableRepository
    , expandPipelineConfig
    , getAllSecrets
    , getAllServices
    , getAllSteps
    , getBuild
    , getBuildGraph
    , getBuilds
    , getCurrentUser
    , getDeployment
    , getDeployments
    , getHooks
    , getInitialToken
    , getLogout
    , getOrgBuilds
    , getOrgRepositories
    , getPipelineConfig
    , getPipelineTemplates
    , getRepo
    , getSchedule
    , getSchedules
    , getSecret
    , getSecrets
    , getServiceLogs
    , getSourceRepositories
    , getStepLogs
    , getToken
    , redeliverHook
    , repairRepo
    , restartBuild
    , updateCurrentUser
    , updateRepository
    , updateSchedule
    , updateSecret
    )

import Api.Api exposing (Request, delete, get, patch, post, put, withAuth)
import Api.Endpoint as Endpoint exposing (Endpoint)
import Api.Pagination as Pagination
import Auth.Jwt exposing (JwtAccessToken, decodeJwtAccessToken)
import Http
import Json.Decode
import Shared
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


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a | shared : Shared.Model }



-- OPERATIONS


getLogout : PartialModel a -> Request String
getLogout model =
    get model.shared.velaAPI Endpoint.Logout Json.Decode.string
        |> withAuth model.shared.session


{-| getToken : gets a new token with refresh token in cookie
-}
getToken : PartialModel a -> Request JwtAccessToken
getToken model =
    get model.shared.velaAPI Endpoint.Token decodeJwtAccessToken


{-| getInitialToken : fetches a the initial token from the authentication endpoint
which will also set the refresh token cookie
-}
getInitialToken : PartialModel a -> AuthParams -> Request JwtAccessToken
getInitialToken model { code, state } =
    get model.shared.velaAPI (Endpoint.Authenticate { code = code, state = state }) decodeJwtAccessToken


{-| getCurrentUser : fetches a user from the current user endpoint
-}
getCurrentUser : PartialModel a -> Request CurrentUser
getCurrentUser model =
    get model.shared.velaAPI Endpoint.CurrentUser decodeCurrentUser
        |> withAuth model.shared.session


{-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-}
updateCurrentUser : PartialModel a -> Http.Body -> Request CurrentUser
updateCurrentUser model body =
    put model.shared.velaAPI Endpoint.CurrentUser body decodeCurrentUser
        |> withAuth model.shared.session


{-| getRepo : fetches single repo by org and repo name
-}
getRepo : PartialModel a -> Org -> Repo -> Request Repository
getRepo model org repo =
    get model.shared.velaAPI (Endpoint.Repository org repo) decodeRepository
        |> withAuth model.shared.session


{-| getOrgRepositories : fetches repos by org
-}
getOrgRepositories : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Request (List Repository)
getOrgRepositories model maybePage maybePerPage org =
    get model.shared.velaAPI (Endpoint.OrgRepositories maybePage maybePerPage org) decodeRepositories
        |> withAuth model.shared.session


{-| getSourceRepositories : fetches source repositories by username for creating them via api
-}
getSourceRepositories : PartialModel a -> Request SourceRepositories
getSourceRepositories model =
    get model.shared.velaAPI Endpoint.UserSourceRepositories decodeSourceRepositories
        |> withAuth model.shared.session


{-| deleteRepo : removes an enabled repository
-}
deleteRepo : PartialModel a -> Repository -> Request String
deleteRepo model repository =
    delete model.shared.velaAPI (Endpoint.Repository repository.org repository.name) Json.Decode.string
        |> withAuth model.shared.session


{-| chownRepo : changes ownership of a repository
-}
chownRepo : PartialModel a -> Repository -> Request String
chownRepo model repository =
    patch model.shared.velaAPI (Endpoint.RepositoryChown repository.org repository.name)
        |> withAuth model.shared.session


{-| repairRepo: re-enables a webhook for a repository
-}
repairRepo : PartialModel a -> Repository -> Request String
repairRepo model repository =
    patch model.shared.velaAPI (Endpoint.RepositoryRepair repository.org repository.name)
        |> withAuth model.shared.session


{-| enableRepository : enables a repository
-}
enableRepository : PartialModel a -> Http.Body -> Request Repository
enableRepository model body =
    post model.shared.velaAPI (Endpoint.Repositories Nothing Nothing) body decodeRepository
        |> withAuth model.shared.session


{-| updateRepository : updates a repository
-}
updateRepository : PartialModel a -> Org -> Repo -> Http.Body -> Request Repository
updateRepository model org repo body =
    put model.shared.velaAPI (Endpoint.Repository org repo) body decodeRepository
        |> withAuth model.shared.session


{-| getPipelineConfig : fetches vela pipeline by repository
-}
getPipelineConfig : PartialModel a -> Org -> Repo -> Ref -> Request PipelineConfig
getPipelineConfig model org repository ref =
    get model.shared.velaAPI (Endpoint.PipelineConfig org repository ref) decodePipelineConfig
        |> withAuth model.shared.session


{-| expandPipelineConfig : expands vela pipeline by repository
-}
expandPipelineConfig : PartialModel a -> Org -> Repo -> Ref -> Request String
expandPipelineConfig model org repository ref =
    post model.shared.velaAPI (Endpoint.ExpandPipelineConfig org repository ref) Http.emptyBody decodePipelineExpand
        |> withAuth model.shared.session


{-| getPipelineTemplates : fetches vela pipeline templates by repository
-}
getPipelineTemplates : PartialModel a -> Org -> Repo -> Ref -> Request Templates
getPipelineTemplates model org repository ref =
    get model.shared.velaAPI (Endpoint.PipelineTemplates org repository ref) decodePipelineTemplates
        |> withAuth model.shared.session


{-| restartBuild : restarts a build
-}
restartBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
restartBuild model org repository buildNumber =
    post model.shared.velaAPI (Endpoint.Build org repository buildNumber) Http.emptyBody decodeBuild
        |> withAuth model.shared.session


{-| approveBuild : approves a build
-}
approveBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request String
approveBuild model org repository buildNumber =
    post model.shared.velaAPI (Endpoint.ApproveBuild org repository buildNumber) Http.emptyBody Json.Decode.string
        |> withAuth model.shared.session


{-| cancelBuild : cancels a build
-}
cancelBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
cancelBuild model org repository buildNumber =
    delete model.shared.velaAPI (Endpoint.CancelBuild org repository buildNumber) decodeBuild
        |> withAuth model.shared.session


{-| getOrgBuilds : fetches vela builds by org
-}
getOrgBuilds : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Org -> Request Builds
getOrgBuilds model maybePage maybePerPage maybeEvent org =
    get model.shared.velaAPI (Endpoint.OrgBuilds maybePage maybePerPage maybeEvent org) decodeBuilds
        |> withAuth model.shared.session


{-| getBuilds : fetches vela builds by repository
-}
getBuilds : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Org -> Repo -> Request Builds
getBuilds model maybePage maybePerPage maybeEvent org repository =
    get model.shared.velaAPI (Endpoint.Builds maybePage maybePerPage maybeEvent org repository) decodeBuilds
        |> withAuth model.shared.session


{-| getBuild : fetches vela build by repository and build number
-}
getBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
getBuild model org repository buildNumber =
    get model.shared.velaAPI (Endpoint.Build org repository buildNumber) decodeBuild
        |> withAuth model.shared.session


{-| getAllSteps : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllSteps : PartialModel a -> Org -> Repo -> BuildNumber -> Request Step
getAllSteps model org repository buildNumber =
    -- we are using the max perPage setting of 100 to reduce the number of calls
    get model.shared.velaAPI (Endpoint.Steps (Just 1) (Just 100) org repository buildNumber) decodeStep
        |> withAuth model.shared.session


{-| getStepLogs : fetches vela build step log by repository, build number and step number
-}
getStepLogs : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> Request Log
getStepLogs model org repository buildNumber stepNumber =
    get model.shared.velaAPI (Endpoint.StepLogs org repository buildNumber stepNumber) decodeLog
        |> withAuth model.shared.session


{-| getAllServices : used in conjuction with 'tryAll', it retrieves all pages for a build service
-}
getAllServices : PartialModel a -> Org -> Repo -> BuildNumber -> Request Service
getAllServices model org repository buildNumber =
    get model.shared.velaAPI (Endpoint.Services (Just 1) (Just 100) org repository buildNumber) decodeService
        |> withAuth model.shared.session


{-| getServiceLogs : fetches vela build service log by repository, build number and service number
-}
getServiceLogs : PartialModel a -> Org -> Repo -> BuildNumber -> ServiceNumber -> Request Log
getServiceLogs model org repository buildNumber serviceNumber =
    get model.shared.velaAPI (Endpoint.ServiceLogs org repository buildNumber serviceNumber) decodeLog
        |> withAuth model.shared.session


{-| getHooks : fetches hooks for the given repository
-}
getHooks : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request Hooks
getHooks model maybePage maybePerPage org repository =
    get model.shared.velaAPI (Endpoint.Hooks maybePage maybePerPage org repository) decodeHooks
        |> withAuth model.shared.session


{-| redeliverHook : redelivers a hook
-}
redeliverHook : PartialModel a -> Org -> Repo -> HookNumber -> Request String
redeliverHook model org repository hookNumber =
    post model.shared.velaAPI (Endpoint.Hook org repository hookNumber) Http.emptyBody Json.Decode.string
        |> withAuth model.shared.session


{-| getAllSecrets : fetches secrets for the given type org and key
-}
getAllSecrets : PartialModel a -> Engine -> Type -> Org -> Key -> Request Secret
getAllSecrets model engine type_ org key =
    get model.shared.velaAPI (Endpoint.Secrets (Just 1) (Just 100) engine type_ org key) decodeSecret
        |> withAuth model.shared.session


{-| getSecrets : fetches secrets for the given type org and key
-}
getSecrets : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Engine -> Type -> Org -> Key -> Request Secrets
getSecrets model maybePage maybePerPage engine type_ org key =
    get model.shared.velaAPI (Endpoint.Secrets maybePage maybePerPage engine type_ org key) decodeSecrets
        |> withAuth model.shared.session


{-| getSecret : fetches secret for the given type org key and name
-}
getSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Name -> Request Secret
getSecret model engine type_ org key name =
    get model.shared.velaAPI (Endpoint.Secret engine type_ org key name) decodeSecret
        |> withAuth model.shared.session


{-| updateSecret : updates a secret
-}
updateSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Name -> Http.Body -> Request Secret
updateSecret model engine type_ org key name body =
    put model.shared.velaAPI (Endpoint.Secret engine type_ org key name) body decodeSecret
        |> withAuth model.shared.session


{-| addSecret : adds a secret
-}
addSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Http.Body -> Request Secret
addSecret model engine type_ org key body =
    post model.shared.velaAPI (Endpoint.Secrets Nothing Nothing engine type_ org key) body decodeSecret
        |> withAuth model.shared.session


{-| getDeployments : fetches vela deployments by repository
-}
getDeployments : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request (List Deployment)
getDeployments model maybePage maybePerPage org repository =
    get model.shared.velaAPI (Endpoint.Deployments maybePage maybePerPage org repository) decodeDeployments
        |> withAuth model.shared.session


{-| getDeployment : fetches vela deployments by repository and deploymentId
-}
getDeployment : PartialModel a -> Org -> Repo -> Maybe DeploymentId -> Request Deployment
getDeployment model org repo deploymentId =
    get model.shared.velaAPI (Endpoint.Deployment org repo deploymentId) decodeDeployment
        |> withAuth model.shared.session


{-| addDeployment : adds a deployment
-}
addDeployment : PartialModel a -> Org -> Repo -> Http.Body -> Request Deployment
addDeployment model org key body =
    post model.shared.velaAPI (Endpoint.Deployment org key Nothing) body decodeDeployment
        |> withAuth model.shared.session


{-| deleteSecret : deletes a secret
-}
deleteSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Name -> Request String
deleteSecret model engine type_ org key name =
    delete model.shared.velaAPI (Endpoint.Secret engine type_ org key name) Json.Decode.string
        |> withAuth model.shared.session



-- SCHEDULES


{-| getSchedules : fetches vela schedules by repository
-}
getSchedules : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request Schedules
getSchedules model maybePage maybePerPage org repository =
    get model.shared.velaAPI (Endpoint.Schedule org repository Nothing maybePage maybePerPage) decodeSchedules
        |> withAuth model.shared.session


{-| getSchedule : fetches vela schedules by repository and name
-}
getSchedule : PartialModel a -> Org -> Repo -> ScheduleName -> Request Schedule
getSchedule model org repo id =
    get model.shared.velaAPI (Endpoint.Schedule org repo (Just id) Nothing Nothing) decodeSchedule
        |> withAuth model.shared.session


{-| addSchedule : adds a schedule
-}
addSchedule : PartialModel a -> Org -> Repo -> Http.Body -> Request Schedule
addSchedule model org repo body =
    post model.shared.velaAPI (Endpoint.Schedule org repo Nothing Nothing Nothing) body decodeSchedule
        |> withAuth model.shared.session


{-| updateSchedule : updates a schedule
-}
updateSchedule : PartialModel a -> Org -> Repo -> ScheduleName -> Http.Body -> Request Schedule
updateSchedule model org repo name body =
    put model.shared.velaAPI (Endpoint.Schedule org repo (Just name) Nothing Nothing) body decodeSchedule
        |> withAuth model.shared.session


{-| deleteSchedule : deletes a schedule
-}
deleteSchedule : PartialModel a -> Org -> Repo -> ScheduleName -> Request String
deleteSchedule model org repo id =
    delete model.shared.velaAPI (Endpoint.Schedule org repo (Just id) Nothing Nothing) Json.Decode.string
        |> withAuth model.shared.session



-- GRAPH


{-| getBuildGraph : fetches vela build graph by repository and build number
-}
getBuildGraph : PartialModel a -> Org -> Repo -> BuildNumber -> Request BuildGraph
getBuildGraph model org repository buildNumber =
    get model.shared.velaAPI (Endpoint.BuildGraph org repository buildNumber) decodeBuildGraph
        |> withAuth model.shared.session
