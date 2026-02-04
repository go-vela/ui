{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Errors exposing (Error, addError, addErrorString, detailedErrorToString, showAlertAlways, showAlertNon401, showAlertNon404, toFailure)

import Http
import Http.Detailed
import Json.Decode as Decode
import RemoteData exposing (WebData)
import Task exposing (perform, succeed)



-- TYPES


{-| Error : alias for string error messages.
-}
type alias Error =
    String



-- HELPERS


{-| errorDecoder : decodes error field from json.
-}
errorDecoder : Decode.Decoder String
errorDecoder =
    Decode.at [ "error" ] Decode.string


{-| detailedErrorToString : extract metadata and convert a Http.Detailed.Error to string value.
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


{-| detailedErrorToError : convert a Http.Detailed.Error to a default Http.Error.
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


{-| errorBodyToString : extracts/converts the "error" field from an api json error message to string.
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


{-| toFailure : maps a detailed error into a WebData Failure value.
-}
toFailure : Http.Detailed.Error String -> WebData a
toFailure error =
    RemoteData.Failure <| detailedErrorToError error


{-| addError : takes a detailed http error and produces a Cmd Msg that invokes an action in the Errors module.
-}
addError : (String -> msg) -> Http.Detailed.Error String -> Cmd msg
addError m error =
    succeed
        (m <| detailedErrorToString error)
        |> perform identity


{-| addErrorString : takes a string and produces a Cmd Msg that invokes an action in the Errors module.
-}
addErrorString : String -> (String -> msg) -> Cmd msg
addErrorString error m =
    succeed
        (m <| error)
        |> perform identity


{-| showAlertAlways : returns an http error predicate that always returns true.
-}
showAlertAlways : Http.Detailed.Error String -> Bool
showAlertAlways error =
    True


{-| showAlertNon401 : returns an http error predicate that returns true when the error status code anything but 401.
-}
showAlertNon401 : Http.Detailed.Error String -> Bool
showAlertNon401 error =
    case error of
        Http.Detailed.BadStatus meta _ ->
            case meta.statusCode of
                401 ->
                    False

                _ ->
                    True

        _ ->
            True


{-| showAlertNon404 : returns an http error predicate that returns true when the error status code anything but 404.
-}
showAlertNon404 : Http.Detailed.Error String -> Bool
showAlertNon404 error =
    case error of
        Http.Detailed.BadStatus meta _ ->
            case meta.statusCode of
                404 ->
                    False

                _ ->
                    True

        _ ->
            True
