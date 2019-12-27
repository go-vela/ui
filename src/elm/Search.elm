{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Search exposing
    ( filterRepo
    , repoSearchBarGlobal
    , repoSearchBarLocal
    , searchFilterGlobal
    , searchFilterLocal
    , shouldSearch
    )

import Dict
import FeatherIcons
import Html exposing (Html, div, input)
import Html.Attributes
    exposing
        ( attribute
        , class
        , placeholder
        , value
        )
import Html.Events exposing (onInput)
import Util
import Vela exposing (Org, RepoSearchFilters, Search, SearchFilter)


{-| repoSearchBarGlobal : renders a input bar for searching across all repos
-}
repoSearchBarGlobal : RepoSearchFilters -> Search msg -> Html msg
repoSearchBarGlobal searchFilters search =
    div [ class "-filter", Util.testAttribute "global-search-bar" ]
        [ FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "role" "img" ]
        , input
            [ Util.testAttribute "global-search-input"
            , placeholder "Type to filter all repositories..."
            , value <| searchFilterGlobal searchFilters
            , onInput <| search ""
            ]
            []
        ]


{-| repoSearchBarLocal : takes an org and placeholder text and renders a search bar for local repo filtering
-}
repoSearchBarLocal : RepoSearchFilters -> Org -> Search msg -> Html msg
repoSearchBarLocal searchFilters org search =
    div [ class "-filter", Util.testAttribute "local-search-bar" ]
        [ FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "role" "img" ]
        , input
            [ Util.testAttribute <| "local-search-input-" ++ org
            , placeholder <|
                "Type to filter repositories in "
                    ++ org
                    ++ "..."
            , value <| searchFilterLocal org searchFilters
            , onInput <| search org
            ]
            []
        ]


{-| filterRepo : takes org/repo display filters, the org and filters a single repo based on user-entered text
-}
filterRepo : RepoSearchFilters -> Maybe Org -> String -> Bool
filterRepo filters org filterOn =
    let
        org_ =
            Maybe.withDefault "" <| org

        filterBy =
            Maybe.withDefault "" <| Dict.get org_ filters

        by =
            String.toLower filterBy

        on =
            String.toLower filterOn
    in
    String.contains by on


{-| searchFilterGlobal : takes repo search filters and returns the global filter (org == "")
-}
searchFilterGlobal : RepoSearchFilters -> SearchFilter
searchFilterGlobal filters =
    Maybe.withDefault "" <| Dict.get "" filters


{-| searchFilterLocal : takes repo search filters and org and returns the local filter
-}
searchFilterLocal : Org -> RepoSearchFilters -> SearchFilter
searchFilterLocal org filters =
    Maybe.withDefault "" <| Dict.get org filters


{-| shouldSearch : takes repo search filter and returns if results should be filtered
-}
shouldSearch : SearchFilter -> Bool
shouldSearch filter =
    String.length filter > 2
