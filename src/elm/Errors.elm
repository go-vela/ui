{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Errors exposing (addError, addErrorString, detailedErrorToError, detailedErrorToString, errorToString, toFailure, viewResourceError)

import Html exposing (Html, div, p, text)
import Http exposing (Error(..))
import Http.Detailed
import Json.Decode as Decode
import RemoteData exposing (RemoteData(..), WebData)
import Task exposing (perform, succeed)
import Util


{-| errorDecoder : decodes error field from json
-}
errorDecoder : Decode.Decoder String
errorDecoder =
    Decode.map (\error -> error) <|
        Decode.at [ "error" ] Decode.string


{-| detailedErrorToString : extract metadata and convert a Http.Detailed.Error to string value
-}
detailedErrorToString : Http.Detailed.Error String -> String
detailedErrorToString error =
    case error of
        Http.Detailed.BadUrl url ->
            "Bad URL" ++ wrapErrorContent url

        Http.Detailed.Timeout ->
            "Network timeout reached"

        Http.Detailed.NetworkError ->
            "Unknown network error"

        Http.Detailed.BadStatus metadata body ->
            "Status " ++ badStatusToString metadata.statusCode body

        Http.Detailed.BadBody _ _ str ->
            "Invalid Body" ++ wrapErrorContent str


{-| detailedErrorToError : convert a Http.Detailed.Error to a default Http.Error
-}
detailedErrorToError : Http.Detailed.Error String -> Http.Error
detailedErrorToError error =
    case error of
        Http.Detailed.BadUrl url ->
            Http.BadUrl url

        Http.Detailed.Timeout ->
            Http.Timeout

        Http.Detailed.NetworkError ->
            Http.NetworkError

        Http.Detailed.BadStatus metadata _ ->
            Http.BadStatus metadata.statusCode

        Http.Detailed.BadBody _ _ body ->
            Http.BadBody body


{-| errorToString : convert a Http.Error to a string
-}
errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "bad URL: " ++ url

        Http.Timeout ->
            "timeout"

        Http.NetworkError ->
            "network error"

        Http.BadStatus metadata ->
            String.fromInt metadata

        Http.BadBody body ->
            errorBodyToString body


{-| errorBodyToString : extracts/converts the "error" field from an api json error message to string
-}
errorBodyToString : String -> String
errorBodyToString body =
    case Decode.decodeString errorDecoder body of
        Ok error ->
            error

        _ ->
            ""


{-| badStatusToString : wraps non-200 status code and error body, used for UI consistency.
-}
badStatusToString : Int -> String -> String
badStatusToString statusCode body =
    String.fromInt statusCode ++ (wrapErrorContent <| errorBodyToString body)


{-| wrapErrorContent : wraps the optional string content included with an error, used for UI consistency.
-}
wrapErrorContent : String -> String
wrapErrorContent content =
    if String.isEmpty content then
        ""

    else
        " (" ++ content ++ ")"


{-| viewResourceError : renders generic error message when there is a problem fetching a resource from Vela.
-}
viewResourceError : { resourceLabel : String, testLabel : String } -> Html msg
viewResourceError { resourceLabel, testLabel } =
    div [ Util.testAttribute <| testLabel ++ "-error" ]
        [ p []
            [ text <|
                "There was an error fetching "
                    ++ resourceLabel
                    ++ ", please refresh or try again later!"
            ]
        ]


{-| toFailure : maps a detailed error into a WebData Failure value
-}
toFailure : Http.Detailed.Error String -> WebData a
toFailure error =
    Failure <| detailedErrorToError error


{-| addError : takes a detailed http error and produces a Cmd Msg that invokes an action in the Errors module
-}
addError : Http.Detailed.Error String -> (String -> msg) -> Cmd msg
addError error m =
    succeed
        (m <| detailedErrorToString error)
        |> perform identity


{-| addErrorString : takes a string and produces a Cmd Msg that invokes an action in the Errors module
-}
addErrorString : String -> (String -> msg) -> Cmd msg
addErrorString error m =
    succeed
        (m <| error)
        |> perform identity
