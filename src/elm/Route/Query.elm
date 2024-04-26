{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Query exposing (fromUrl, toString)

import Dict exposing (Dict)
import Url exposing (Url)
import Url.Builder exposing (QueryParameter)
import Url.Parser exposing (query)


{-| fromUrl : takes in a url and returns a dictionary of query parameters.
-}
fromUrl : Url -> Dict String String
fromUrl url =
    case url.query of
        Nothing ->
            Dict.empty

        Just query ->
            if String.isEmpty query then
                Dict.empty

            else
                query
                    |> String.split "&"
                    |> List.filterMap (String.split "=" >> queryPiecesToTuple)
                    |> Dict.fromList


{-| queryPiecesToTuple : takes in a list of strings and returns a tuple of two strings.
-}
queryPiecesToTuple : List String -> Maybe ( String, String )
queryPiecesToTuple pieces =
    case pieces of
        [] ->
            Nothing

        key :: [] ->
            Just ( decodeQueryToken key, "" )

        key :: value :: _ ->
            Just ( decodeQueryToken key, decodeQueryToken value )


{-| decodeQueryToken : takes in a string and returns a percent decoded string.
-}
decodeQueryToken : String -> String
decodeQueryToken val =
    Url.percentDecode val
        |> Maybe.withDefault val


{-| toString : takes in a dictionary of query parameters and returns a query string.
-}
toString : Dict String String -> String
toString queryParameterList =
    queryParameterList
        |> Dict.toList
        |> List.map tupleToQueryPiece
        |> Url.Builder.toQuery


{-| tupleToQueryPiece : takes in a tuple of two strings and returns a query parameter.
-}
tupleToQueryPiece : ( String, String ) -> QueryParameter
tupleToQueryPiece ( key, value ) =
    Url.Builder.string key value
