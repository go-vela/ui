{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Api.Pagination exposing
    ( Page
    , PerPage
    , defaultPage
    , defaultPerPage
    , get
    , maybeNextLink
    , toQueryParams
    )

import Api.Header as Header
import Dict exposing (Dict)
import LinkHeader exposing (WebLink, parse)
import Url.Builder as UB exposing (QueryParameter, string)


type alias Page =
    Int


type alias PerPage =
    Int



defaultPage : Page
defaultPage =
    1


defaultPerPage : PerPage
defaultPerPage =
    10


{-| get : turns a link header into a list of WebLinks
-}
get : Dict String String -> List WebLink
get headers =
    Header.get "link" headers
        |> Maybe.map parse
        |> Maybe.withDefault []


{-| maybeNextLink : returns any "next" links if available
-}
maybeNextLink : List WebLink -> Maybe String
maybeNextLink links =
    links
        |> List.filter
            (\link ->
                case link.rel of
                    LinkHeader.RelNext _ ->
                        True

                    _ ->
                        False
            )
        |> List.head
        |> Maybe.map .url


{-| toQueryParams : turns paging information into QueryParameters

    Note: absence of a parameter will default to server side defaults

-}
toQueryParams : Maybe Page -> Maybe PerPage -> List QueryParameter
toQueryParams maybePage maybePerPage =
    let
        page : QueryParameter
        page =
            UB.string "page" <| String.fromInt <| Maybe.withDefault defaultPage maybePage

        perPage : QueryParameter
        perPage =
            UB.string "per_page" <| String.fromInt <| Maybe.withDefault defaultPerPage maybePerPage
    in
    case ( maybePage, maybePerPage ) of
        ( Nothing, Nothing ) ->
            []

        ( Just _, Just _ ) ->
            [ page, perPage ]

        ( Just _, Nothing ) ->
            [ page ]

        ( Nothing, Just _ ) ->
            [ perPage ]
