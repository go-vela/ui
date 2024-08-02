{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Api exposing
    ( Request(..)
    , delete
    , get
    , patch
    , post
    , put
    , try
    , tryAll
    , tryString
    , withAuth
    )

import Api.Endpoint as Endpoint exposing (Endpoint)
import Api.Header exposing (userAgent, userAgentString)
import Api.Pagination as Pagination
import Auth.Session exposing (Session(..))
import Http
import Http.Detailed
import Json.Decode exposing (Decoder)
import Task exposing (Task)



-- TYPES


{-| RequestConfig : basic configuration record for an API request.
-}
type alias RequestConfig a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , decoder : Decoder a
    }


{-| Request : wraps a configuration for an API request.
-}
type Request a
    = Request (RequestConfig a)


{-| ListResponse : custom response type to be used in conjunction
with API pagination response headers to discern between
a response that has more pages to fetch vs a response that has
no further pages.
-}
type ListResponse a
    = Partial (Request a) (List a)
    | Done (List a)



-- HELPERS


{-| request : turn a request configuration into a request.
-}
request : RequestConfig a -> Request a
request =
    Request


{-| toTask : turn a request config into an HTTP task.
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


{-| toStringTask : turn a request config into an HTTP task.
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


{-| toAllTask : like _toTask_ but attaches a custom resolver to use in conjunction with _tryAll_.
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


{-| listResponseToList : small helper that forwards the inital HTTP task to the recurse function.
-}
listResponseToList : Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a ) -> Task (Http.Detailed.Error String) ( Http.Metadata, List a )
listResponseToList task =
    task |> recurse


{-| listResponseResolver : turns a response from an HTTP request into a 'ListResponse' response.
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


{-| recurse : keeps firing off HTTP tasks if the response is of type Partial.

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


{-| update : aggregates the results from two responses as needed.
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


{-| withAuth : returns an auth header with given Bearer token.
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


{-| get : creates a GET request configuration.
-}
get : String -> Endpoint -> Decoder b -> Request b
get api endpoint decoder =
    request
        { method = "GET"
        , headers = [ userAgent userAgentString ]
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = decoder
        }


{-| post : creates a POST request configuration.
-}
post : String -> Endpoint -> Http.Body -> Decoder b -> Request b
post api endpoint body decoder =
    request
        { method = "POST"
        , headers = [ userAgent userAgentString ]
        , url = Endpoint.toUrl api endpoint
        , body = body
        , decoder = decoder
        }


{-| put : creates a PUT request configuration.
-}
put : String -> Endpoint -> Http.Body -> Decoder b -> Request b
put api endpoint body decoder =
    request
        { method = "PUT"
        , headers = [ userAgent userAgentString ]
        , url = Endpoint.toUrl api endpoint
        , body = body
        , decoder = decoder
        }


{-| delete : creates a DELETE request configuration.
-}
delete : String -> Endpoint -> Decoder b -> Request b
delete api endpoint decoder =
    request
        { method = "DELETE"
        , headers = [ userAgent userAgentString ]
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = decoder
        }


{-| patch : creates a PATCH request configuration.
-}
patch : String -> Endpoint -> Decoder b -> Request b
patch api endpoint decoder =
    request
        { method = "PATCH"
        , headers = [ userAgent userAgentString ]
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = decoder
        }



-- ENTRYPOINT


{-| try : default way to request information from an endpoint.

    example usage:
        Api.try UserResponse <| Api.getUser model authParams

-}
try : (Result (Http.Detailed.Error String) ( Http.Metadata, a ) -> msg) -> Request a -> Cmd msg
try msg request_ =
    toTask request_
        |> Task.attempt msg


{-| tryAll : will attempt to get all results for the endpoint based on pagination.

    example usage:
        Api.tryAll RepositoriesResponse <| Api.getAllRepositories model

-}
tryAll : (Result (Http.Detailed.Error String) ( Http.Metadata, List a ) -> msg) -> Request a -> Cmd msg
tryAll msg request_ =
    toAllTask request_
        |> listResponseToList
        |> Task.attempt msg


{-| tryString : way to request information from an endpoint with a string response.

    example usage:
        Api.tryString UserResponse <| Api.getUser model authParams

-}
tryString : (Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg) -> Request String -> Cmd msg
tryString msg request_ =
    toStringTask request_
        |> Task.attempt msg
