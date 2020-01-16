{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Errors exposing (detailedErrorToError, detailedErrorToString)

import Http exposing (Error(..))
import Http.Detailed
import Json.Decode as Decode


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
