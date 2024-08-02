{--
SPDX-License-Identifier: Apache-2.0
--}


module Api.Header exposing (get, velaVersionHeader)

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


{-| velaVersionHeader creates a User-Agent header with the specified value.

TODO: allow this to be controlled via flags/config

-}
velaVersionHeader : Http.Header
velaVersionHeader =
    Http.header "x-vela-ui-version" "vela/ui"
