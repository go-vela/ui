{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Header exposing (get)

import Dict exposing (Dict)
import Http


{-| get : looks for the specified header key and returns the value.

    we lower case they keys because different browsers may return them in diff cases

-}
get : String -> Dict String String -> Maybe String
get key headers =
    let
        key_ =
            String.toLower key

        headers_ =
            Dict.toList headers
                |> List.map (\( k, v ) -> ( String.toLower k, v ))
                |> Dict.fromList
    in
    Dict.get key_ headers_
