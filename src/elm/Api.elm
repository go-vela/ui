{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Api exposing
    ( Request(..)
    , addRepository
    , deleteRepo
    , getAllBuilds
    , getAllHooks
    , getAllRepositories
    , getBuild
    , getBuilds
    , getCurrentUser
    , getHooks
    , getRepo
    , getRepositories
    , getSourceRepositories
    , getStep
    , getStepLogs
    , getSteps
    , getUser
    , restartBuild
    , try
    , tryAll
    , updateCurrentUser
    , updateRepository
    )

import Api.Endpoint as Endpoint exposing (Endpoint(..))
import Api.Pagination as Pagination
import Http
import Http.Detailed
import Json.Decode exposing (Decoder)
import RemoteData exposing (RemoteData(..))
import Task exposing (Task)
import Vela
    exposing
        ( AuthParams
        , Build
        , BuildNumber
        , Builds
        , CurrentUser
        , Hook
        , Hooks
        , Log
        , Org
        , Repo
        , Repositories
        , Repository
        , Session
        , SourceRepositories
        , Step
        , StepNumber
        , Steps
        , User
        , decodeBuild
        , decodeBuilds
        , decodeCurrentUser
        , decodeHook
        , decodeHooks
        , decodeLog
        , decodeRepositories
        , decodeRepository
        , decodeSourceRepositories
        , decodeStep
        , decodeSteps
        , decodeUser
        , defaultSession
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
        , session : Maybe Session
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
    Http.task
        { body = config.body
        , headers = config.headers
        , method = config.method
        , resolver = Http.stringResolver <| Http.Detailed.responseToJson config.decoder
        , timeout = Nothing
        , url = config.url
        }


{-| toAllTask : like _toTask_ but attaches a custom resolver to use in conjunction with _tryAll_
-}
toAllTask : Request a -> Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a )
toAllTask (Request config) =
    Http.task
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
withAuth : Maybe Session -> Request a -> Request a
withAuth maybeSession (Request config) =
    let
        session : Session
        session =
            Maybe.withDefault defaultSession maybeSession
    in
    request { config | headers = Http.header "authorization" ("Bearer " ++ session.token) :: config.headers }



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
delete : String -> Endpoint -> Request String
delete api endpoint =
    request
        { method = "DELETE"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = Json.Decode.string
        }



-- ENTRYPOINT


{-| try : default way to request information from and endpoint

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



-- OPERATIONS


{-| getUser : fetches a user and token from the authentication endpoint
-}
getUser : PartialModel a -> AuthParams -> Request User
getUser model { code, state } =
    get model.velaAPI (Endpoint.Authenticate { code = code, state = state }) decodeUser


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


{-| getRepositories : fetches enabled repositories by user token
-}
getRepositories : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Request Repositories
getRepositories model maybePage maybePerPage =
    get model.velaAPI (Endpoint.Repositories maybePage maybePerPage) decodeRepositories
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
    delete model.velaAPI (Endpoint.Repository repository.org repository.name)
        |> withAuth model.session


{-| addRepository : adds a repository
-}
addRepository : PartialModel a -> Http.Body -> Request Repository
addRepository model body =
    post model.velaAPI (Endpoint.Repositories Nothing Nothing) body decodeRepository
        |> withAuth model.session


{-| updateRepository : updates a repository
-}
updateRepository : PartialModel a -> Org -> Repo -> Http.Body -> Request Repository
updateRepository model org repo body =
    put model.velaAPI (Endpoint.Repository org repo) body decodeRepository
        |> withAuth model.session


{-| restartBuild : restarts a build
-}
restartBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
restartBuild model org repository buildNumber =
    post model.velaAPI (Endpoint.Build org repository buildNumber) Http.emptyBody decodeBuild
        |> withAuth model.session


{-| getBuilds : fetches vela builds by repository
-}
getBuilds : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request Builds
getBuilds model maybePage maybePerPage org repository =
    get model.velaAPI (Endpoint.Builds maybePage maybePerPage org repository) decodeBuilds
        |> withAuth model.session


{-| getAllBuilds : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllBuilds : PartialModel a -> Org -> Repo -> Request Build
getAllBuilds model org repository =
    -- we using the max perPage setting of 100 to reduce the number of calls
    get model.velaAPI (Endpoint.Builds (Just 1) (Just 100) org repository) decodeBuild
        |> withAuth model.session


{-| getBuild : fetches vela build by repository and build number
-}
getBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
getBuild model org repository buildNumber =
    get model.velaAPI (Endpoint.Build org repository buildNumber) decodeBuild
        |> withAuth model.session


{-| getSteps : fetches vela build steps by repository and build number
-}
getSteps : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> BuildNumber -> Request Steps
getSteps model maybePage maybePerPage org repository buildNumber =
    get model.velaAPI (Endpoint.Steps maybePage maybePerPage org repository buildNumber) decodeSteps
        |> withAuth model.session


{-| getStep : fetches vela build steps by repository, build number and step number
-}
getStep : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> Request Step
getStep model org repository buildNumber stepNumber =
    get model.velaAPI (Endpoint.Step org repository buildNumber stepNumber) decodeStep
        |> withAuth model.session


{-| getStepLogs : fetches vela build step log by repository, build number and step number
-}
getStepLogs : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> Request Log
getStepLogs model org repository buildNumber stepNumber =
    get model.velaAPI (Endpoint.StepLogs org repository buildNumber stepNumber) decodeLog
        |> withAuth model.session


{-| getHooks : fetches hooks for the given repository
-}
getHooks : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request Hooks
getHooks model maybePage maybePerPage org repository =
    get model.velaAPI (Endpoint.Hooks maybePage maybePerPage org repository) decodeHooks
        |> withAuth model.session


{-| getAllHooks : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllHooks : PartialModel a -> Org -> Repo -> Request Hook
getAllHooks model org repository =
    -- we are using the max perPage setting of 100 to reduce the number of calls
    get model.velaAPI (Endpoint.Hooks (Just 1) (Just 100) org repository) decodeHook
        |> withAuth model.session
