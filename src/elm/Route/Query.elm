{--
SPDX-License-Identifier: Apache-2.0
--}


module Route.Query exposing (fromString, fromUrl, toString)

import Dict exposing (Dict)
import Url exposing (Url)
import Url.Builder exposing (QueryParameter)
import Url.Parser exposing (query)


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


fromString : String -> Dict String String
fromString query =
    if String.isEmpty query then
        Dict.empty

    else
        query
            |> String.split "&"
            |> List.filterMap (String.split "=" >> queryPiecesToTuple)
            |> Dict.fromList


queryPiecesToTuple : List String -> Maybe ( String, String )
queryPiecesToTuple pieces =
    case pieces of
        [] ->
            Nothing

        key :: [] ->
            Just ( decodeQueryToken key, "" )

        key :: value :: _ ->
            Just ( decodeQueryToken key, decodeQueryToken value )


decodeQueryToken : String -> String
decodeQueryToken val =
    Url.percentDecode val
        |> Maybe.withDefault val


toString : Dict String String -> String
toString queryParameterList =
    queryParameterList
        |> Dict.toList
        |> List.map tupleToQueryPiece
        |> Url.Builder.toQuery


tupleToQueryPiece : ( String, String ) -> QueryParameter
tupleToQueryPiece ( key, value ) =
    Url.Builder.string key value
