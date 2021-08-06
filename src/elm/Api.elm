{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Api exposing
    ( Request(..)
    , addDeployment
    , addSecret
    , cancelBuild
    , chownRepo
    , deleteRepo
    , deleteSecret
    , enableRepository
    , expandPipelineConfig
    , getAllRepositories
    , getAllSecrets
    , getAllServices
    , getAllSteps
    , getBuild
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
    , getSecret
    , getSecrets
    , getServiceLogs
    , getSourceRepositories
    , getStepLogs
    , getToken
    , repairRepo
    , restartBuild
    , try
    , tryAll
    , tryString
    , updateCurrentUser
    , updateRepository
    , updateSecret
    )

import Api.Endpoint as Endpoint exposing (Endpoint(..))
import Api.Pagination as Pagination
import Auth.Jwt exposing (JwtAccessToken, decodeJwtAccessToken)
import Auth.Session exposing (Session(..))
import Http
import Http.Detailed
import Json.Decode exposing (Decoder)
import Task exposing (Task)
import Vela
    exposing
        ( AuthParams
        , Build
        , BuildNumber
        , Builds
        , CurrentUser
        , Deployment
        , DeploymentId
        , Engine
        , Event
        , Hooks
        , Key
        , Log
        , Name
        , Org
        , Repo
        , Repository
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
        , decodeBuilds
        , decodeCurrentUser
        , decodeDeployment
        , decodeDeployments
        , decodeHooks
        , decodeLog
        , decodePipelineConfig
        , decodePipelineTemplates
        , decodeRepositories
        , decodeRepository
        , decodeSecret
        , decodeSecrets
        , decodeService
        , decodeSourceRepositories
        , decodeStep
        )



-- TYPES


{-| RequestConfig : a basic configuration record for an API request
-}
type alias RequestConfig a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , decoder : Decoder a
    }


{-| Request : wraps a configuration for an API request
-}
type Request a
    = Request (RequestConfig a)


{-| ListResponse : a custom response type to be used in conjunction
with API pagination response headers to discern between
a response that has more pages to fetch vs a response that has
no further pages.
-}
type ListResponse a
    = Partial (Request a) (List a)
    | Done (List a)


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | velaAPI : String
        , session : Session
    }



-- HELPERS


{-| request : turn a request configuration into a request
-}
request : RequestConfig a -> Request a
request =
    Request


{-| toTask : turn a request config into an HTTP task
-}
toTask : Request a -> Task (Http.Detailed.Error String) ( Http.Metadata, a )
toTask (Request config) =
    Http.riskyTask
        { body = config.body
        , headers = config.headers
        , method = config.method
        , resolver = Http.stringResolver <| Http.Detailed.responseToJson config.decoder
        , timeout = Nothing
        , url = config.url
        }


{-| toStringTask : turn a request config into an HTTP task
-}
toStringTask : Request String -> Task (Http.Detailed.Error String) ( Http.Metadata, String )
toStringTask (Request config) =
    Http.task
        { body = config.body
        , headers = config.headers
        , method = config.method
        , resolver = Http.stringResolver <| Http.Detailed.responseToString
        , timeout = Nothing
        , url = config.url
        }


{-| toAllTask : like _toTask_ but attaches a custom resolver to use in conjunction with _tryAll_
-}
toAllTask : Request a -> Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a )
toAllTask (Request config) =
    Http.riskyTask
        { body = config.body
        , headers = config.headers
        , method = config.method
        , resolver = Http.stringResolver (listResponseResolver config)
        , timeout = Nothing
        , url = config.url
        }


{-| listResponseToList : small helper that forwards the inital HTTP task to the recurse function
-}
listResponseToList : Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a ) -> Task (Http.Detailed.Error String) ( Http.Metadata, List a )
listResponseToList task =
    task |> recurse


{-| listResponseResolver : turns a response from an HTTP request into a 'ListResponse' response
-}
listResponseResolver : RequestConfig a -> Http.Response String -> Result (Http.Detailed.Error String) ( Http.Metadata, ListResponse a )
listResponseResolver config response =
    case response of
        Http.GoodStatus_ m _ ->
            let
                items : Result (Http.Detailed.Error String) ( Http.Metadata, List a )
                items =
                    Http.Detailed.responseToJson (Json.Decode.list config.decoder) response

                next : Maybe String
                next =
                    Pagination.get m.headers
                        |> Pagination.maybeNextLink
            in
            case next of
                Nothing ->
                    Result.map (\( _, res ) -> ( m, Done res )) items

                Just url ->
                    Result.map (\( _, res ) -> ( m, Partial (request { config | url = url }) res )) items

        Http.BadUrl_ b ->
            Err (Http.Detailed.BadUrl b)

        Http.Timeout_ ->
            Err Http.Detailed.Timeout

        Http.NetworkError_ ->
            Err Http.Detailed.NetworkError

        Http.BadStatus_ m b ->
            Err (Http.Detailed.BadStatus m b)


{-| recurse : keeps firing off HTTP tasks if the response is of type Partial

    Thanks to "https://github.com/correl/elm-paginated" for the inspiration

-}
recurse : Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a ) -> Task (Http.Detailed.Error String) ( Http.Metadata, List a )
recurse originalRequest =
    originalRequest
        |> Task.andThen
            (\( meta, response ) ->
                case response of
                    Partial request_ _ ->
                        toAllTask request_
                            |> Task.map (update ( meta, response ))
                            |> recurse

                    Done data ->
                        Task.succeed ( meta, data )
            )


{-| update: aggregates the results from two responses as needed
-}
update : ( Http.Metadata, ListResponse a ) -> ( Http.Metadata, ListResponse a ) -> ( Http.Metadata, ListResponse a )
update old new =
    case ( old, new ) of
        ( ( _, Done _ ), _ ) ->
            old

        ( ( _, Partial _ oldItems ), ( meta, Done newItems ) ) ->
            ( meta, Done (oldItems ++ newItems) )

        ( ( _, Partial _ oldItems ), ( meta, Partial request_ newItems ) ) ->
            ( meta, Partial request_ (oldItems ++ newItems) )


{-| withAuth : returns an auth header with given Bearer token
-}
withAuth : Session -> Request a -> Request a
withAuth session (Request config) =
    let
        token : String
        token =
            case session of
                Unauthenticated ->
                    ""

                Authenticated auth ->
                    auth.token
    in
    request { config | headers = Http.header "authorization" ("Bearer " ++ token) :: config.headers }



-- METHODS


{-| get : creates a GET request configuration
-}
get : String -> Endpoint -> Decoder b -> Request b
get api endpoint decoder =
    request
        { method = "GET"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = decoder
        }


{-| post : creates a POST request configuration
-}
post : String -> Endpoint -> Http.Body -> Decoder b -> Request b
post api endpoint body decoder =
    request
        { method = "POST"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = body
        , decoder = decoder
        }


{-| put : creates a PUT request configuration
-}
put : String -> Endpoint -> Http.Body -> Decoder b -> Request b
put api endpoint body decoder =
    request
        { method = "PUT"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = body
        , decoder = decoder
        }


{-| delete : creates a DELETE request configuration
-}
delete : String -> Endpoint -> Decoder b -> Request b
delete api endpoint decoder =
    request
        { method = "DELETE"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = decoder
        }


{-| patch : creates a PATCH request configuration
-}
patch : String -> Endpoint -> Request String
patch api endpoint =
    request
        { method = "PATCH"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = Json.Decode.string
        }



-- ENTRYPOINT


{-| try : default way to request information from an endpoint

    example usage:
        Api.try UserResponse <| Api.getUser model authParams

-}
try : (Result (Http.Detailed.Error String) ( Http.Metadata, a ) -> msg) -> Request a -> Cmd msg
try msg request_ =
    toTask request_
        |> Task.attempt msg


{-| tryAll : will attempt to get all results for the endpoint based on pagination

    example usage:
        Api.tryAll RepositoriesResponse <| Api.getAllRepositories model

-}
tryAll : (Result (Http.Detailed.Error String) ( Http.Metadata, List a ) -> msg) -> Request a -> Cmd msg
tryAll msg request_ =
    toAllTask request_
        |> listResponseToList
        |> Task.attempt msg



-- ENTRYPOINT


{-| try : default way to request information from an endpoint
example usage:
Api.try UserResponse <| Api.getUser model authParams
-}
tryString : (Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg) -> Request String -> Cmd msg
tryString msg request_ =
    toStringTask request_
        |> Task.attempt msg



-- OPERATIONS


getLogout : PartialModel a -> Request String
getLogout model =
    get model.velaAPI Endpoint.Logout Json.Decode.string
        |> withAuth model.session


{-| getToken : gets a new token with refresh token in cookie
-}
getToken : PartialModel a -> Request JwtAccessToken
getToken model =
    get model.velaAPI Endpoint.Token decodeJwtAccessToken


{-| getInitialToken : fetches a the initial token from the authentication endpoint
which will also set the refresh token cookie
-}
getInitialToken : PartialModel a -> AuthParams -> Request JwtAccessToken
getInitialToken model { code, state } =
    get model.velaAPI (Endpoint.Authenticate { code = code, state = state }) decodeJwtAccessToken


{-| getCurrentUser : fetches a user from the current user endpoint
-}
getCurrentUser : PartialModel a -> Request CurrentUser
getCurrentUser model =
    get model.velaAPI Endpoint.CurrentUser decodeCurrentUser
        |> withAuth model.session


{-| updateCurrentUser : updates the currently authenticated user with the current user endpoint
-}
updateCurrentUser : PartialModel a -> Http.Body -> Request CurrentUser
updateCurrentUser model body =
    put model.velaAPI Endpoint.CurrentUser body decodeCurrentUser
        |> withAuth model.session


{-| getAllRepositories : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllRepositories : PartialModel a -> Request Repository
getAllRepositories model =
    -- we using the max perPage setting of 100 to reduce the number of calls
    get model.velaAPI (Endpoint.Repositories (Just 1) (Just 100)) decodeRepository
        |> withAuth model.session


{-| getRepo : fetches single repo by org and repo name
-}
getRepo : PartialModel a -> Org -> Repo -> Request Repository
getRepo model org repo =
    get model.velaAPI (Endpoint.Repository org repo) decodeRepository
        |> withAuth model.session


{-| getOrgRepositories : fetches single repo by org and repo name
-}
getOrgRepositories : PartialModel a -> Org -> Request (List Repository)
getOrgRepositories model org =
    get model.velaAPI (Endpoint.OrgRepositories org) decodeRepositories
        |> withAuth model.session


{-| getSourceRepositories : fetches source repositories by username for creating them via api
-}
getSourceRepositories : PartialModel a -> Request SourceRepositories
getSourceRepositories model =
    get model.velaAPI Endpoint.UserSourceRepositories decodeSourceRepositories
        |> withAuth model.session


{-| deleteRepo : removes an enabled repository
-}
deleteRepo : PartialModel a -> Repository -> Request String
deleteRepo model repository =
    delete model.velaAPI (Endpoint.Repository repository.org repository.name) Json.Decode.string
        |> withAuth model.session


{-| chownRepo : changes ownership of a repository
-}
chownRepo : PartialModel a -> Repository -> Request String
chownRepo model repository =
    patch model.velaAPI (Endpoint.RepositoryChown repository.org repository.name)
        |> withAuth model.session


{-| repairRepo: re-enables a webhook for a repository
-}
repairRepo : PartialModel a -> Repository -> Request String
repairRepo model repository =
    patch model.velaAPI (Endpoint.RepositoryRepair repository.org repository.name)
        |> withAuth model.session


{-| enableRepository : enables a repository
-}
enableRepository : PartialModel a -> Http.Body -> Request Repository
enableRepository model body =
    post model.velaAPI (Endpoint.Repositories Nothing Nothing) body decodeRepository
        |> withAuth model.session


{-| updateRepository : updates a repository
-}
updateRepository : PartialModel a -> Org -> Repo -> Http.Body -> Request Repository
updateRepository model org repo body =
    put model.velaAPI (Endpoint.Repository org repo) body decodeRepository
        |> withAuth model.session


{-| getPipelineConfig : fetches vela pipeline by repository
-}
getPipelineConfig : PartialModel a -> Org -> Repo -> Maybe String -> Request String
getPipelineConfig model org repository ref =
    get model.velaAPI (Endpoint.PipelineConfig org repository ref) decodePipelineConfig
        |> withAuth model.session


{-| expandPipelineConfig : expands vela pipeline by repository
-}
expandPipelineConfig : PartialModel a -> Org -> Repo -> Maybe String -> Request String
expandPipelineConfig model org repository ref =
    post model.velaAPI (Endpoint.ExpandPipelineConfig org repository ref) Http.emptyBody decodePipelineConfig
        |> withAuth model.session


{-| getPipelineTemplates : fetches vela pipeline templates by repository
-}
getPipelineTemplates : PartialModel a -> Org -> Repo -> Maybe String -> Request Templates
getPipelineTemplates model org repository ref =
    get model.velaAPI (Endpoint.PipelineTemplates org repository ref) decodePipelineTemplates
        |> withAuth model.session


{-| restartBuild : restarts a build
-}
restartBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
restartBuild model org repository buildNumber =
    post model.velaAPI (Endpoint.Build org repository buildNumber) Http.emptyBody decodeBuild
        |> withAuth model.session


{-| cancelBuild : cancels a build
-}
cancelBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
cancelBuild model org repository buildNumber =
    delete model.velaAPI (Endpoint.CancelBuild org repository buildNumber) decodeBuild
        |> withAuth model.session


{-| getOrgBuilds : fetches vela builds by org
-}
getOrgBuilds : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Org -> Request Builds
getOrgBuilds model maybePage maybePerPage maybeEvent org =
    get model.velaAPI (Endpoint.OrgBuilds maybePage maybePerPage maybeEvent org) decodeBuilds
        |> withAuth model.session


{-| getBuilds : fetches vela builds by repository
-}
getBuilds : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Maybe Event -> Org -> Repo -> Request Builds
getBuilds model maybePage maybePerPage maybeEvent org repository =
    get model.velaAPI (Endpoint.Builds maybePage maybePerPage maybeEvent org repository) decodeBuilds
        |> withAuth model.session


{-| getBuild : fetches vela build by repository and build number
-}
getBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
getBuild model org repository buildNumber =
    get model.velaAPI (Endpoint.Build org repository buildNumber) decodeBuild
        |> withAuth model.session


{-| getAllSteps : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllSteps : PartialModel a -> Org -> Repo -> BuildNumber -> Request Step
getAllSteps model org repository buildNumber =
    -- we are using the max perPage setting of 100 to reduce the number of calls
    get model.velaAPI (Endpoint.Steps (Just 1) (Just 100) org repository buildNumber) decodeStep
        |> withAuth model.session


{-| getStepLogs : fetches vela build step log by repository, build number and step number
-}
getStepLogs : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> Request Log
getStepLogs model org repository buildNumber stepNumber =
    get model.velaAPI (Endpoint.StepLogs org repository buildNumber stepNumber) decodeLog
        |> withAuth model.session


{-| getAllServices : used in conjuction with 'tryAll', it retrieves all pages for a build service
-}
getAllServices : PartialModel a -> Org -> Repo -> BuildNumber -> Request Service
getAllServices model org repository buildNumber =
    get model.velaAPI (Endpoint.Services (Just 1) (Just 100) org repository buildNumber) decodeService
        |> withAuth model.session


{-| getServiceLogs : fetches vela build service log by repository, build number and service number
-}
getServiceLogs : PartialModel a -> Org -> Repo -> BuildNumber -> ServiceNumber -> Request Log
getServiceLogs model org repository buildNumber serviceNumber =
    get model.velaAPI (Endpoint.ServiceLogs org repository buildNumber serviceNumber) decodeLog
        |> withAuth model.session


{-| getHooks : fetches hooks for the given repository
-}
getHooks : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request Hooks
getHooks model maybePage maybePerPage org repository =
    get model.velaAPI (Endpoint.Hooks maybePage maybePerPage org repository) decodeHooks
        |> withAuth model.session


{-| getAllSecrets : fetches secrets for the given type org and key
-}
getAllSecrets : PartialModel a -> Engine -> Type -> Org -> Key -> Request Secret
getAllSecrets model engine type_ org key =
    get model.velaAPI (Endpoint.Secrets (Just 1) (Just 100) engine type_ org key) decodeSecret
        |> withAuth model.session


{-| getSecrets : fetches secrets for the given type org and key
-}
getSecrets : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Engine -> Type -> Org -> Key -> Request Secrets
getSecrets model maybePage maybePerPage engine type_ org key =
    get model.velaAPI (Endpoint.Secrets maybePage maybePerPage engine type_ org key) decodeSecrets
        |> withAuth model.session


{-| getSecret : fetches secret for the given type org key and name
-}
getSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Name -> Request Secret
getSecret model engine type_ org key name =
    get model.velaAPI (Endpoint.Secret engine type_ org key name) decodeSecret
        |> withAuth model.session


{-| updateSecret : updates a secret
-}
updateSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Name -> Http.Body -> Request Secret
updateSecret model engine type_ org key name body =
    put model.velaAPI (Endpoint.Secret engine type_ org key name) body decodeSecret
        |> withAuth model.session


{-| addSecret : adds a secret
-}
addSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Http.Body -> Request Secret
addSecret model engine type_ org key body =
    post model.velaAPI (Endpoint.Secrets Nothing Nothing engine type_ org key) body decodeSecret
        |> withAuth model.session


{-| getDeployments : fetches vela deployments by repository
-}
getDeployments : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request (List Deployment)
getDeployments model maybePage maybePerPage org repository =
    get model.velaAPI (Endpoint.Deployments maybePage maybePerPage org repository) decodeDeployments
        |> withAuth model.session


{-| getDeployment : fetches vela deployments by repository and deploymentId
-}
getDeployment : PartialModel a -> Org -> Repo -> Maybe DeploymentId -> Request Deployment
getDeployment model org repo deploymentId =
    get model.velaAPI (Endpoint.Deployment org repo deploymentId) decodeDeployment
        |> withAuth model.session


{-| addDeployment : adds a deployment
-}
addDeployment : PartialModel a -> Org -> Repo -> Http.Body -> Request Deployment
addDeployment model org key body =
    post model.velaAPI (Endpoint.Deployment org key Nothing) body decodeDeployment
        |> withAuth model.session


{-| deleteSecret : deletes a secret
-}
deleteSecret : PartialModel a -> Engine -> Type -> Org -> Key -> Name -> Request String
deleteSecret model engine type_ org key name =
    delete model.velaAPI (Endpoint.Secret engine type_ org key name) Json.Decode.string
        |> withAuth model.session
