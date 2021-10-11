{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Api.Header exposing (contentLength, get)

import Dict exposing (Dict)


{-| get : looks for the specified header key and returns the value

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


{-| contentLength : looks for the 'Content-Length' header key and returns the value

    we return a maybe int because not all responses contain the header

-}
contentLength : Dict String String -> Maybe Int
contentLength headers =
    headers
        |> get "content-length"
        |> Maybe.withDefault ""
        |> String.toInt
