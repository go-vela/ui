{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Search exposing
    ( Search
    , SimpleSearch
    , filterRepo
    , searchFilterGlobal
    , searchFilterLocal
    , shouldSearch
    , toLowerContains
    , viewHomeSearchBar
    , viewRepoSearchBarGlobal
    , viewRepoSearchBarLocal
    )

import Dict exposing (Dict)
import FeatherIcons
import Html exposing (Html, div, input)
import Html.Attributes
    exposing
        ( attribute
        , autofocus
        , class
        , id
        , placeholder
        , value
        )
import Html.Events exposing (onInput)
import Utils.Helpers as Util
import Vela



-- TYPES


{-| Search : takes org and repo and searches/filters based on user input.
-}
type alias Search msg =
    Vela.Org -> String -> msg


{-| SimpleSearch : takes input and searches/filters favorites displayed on the home page.
-}
type alias SimpleSearch msg =
    String -> msg



-- VIEW


{-| viewHomeSearchBar : renders an input bar for searching across all favorited repos.
-}
viewHomeSearchBar : String -> SimpleSearch msg -> Html msg
viewHomeSearchBar filter search =
    div [ class "form-control", class "-with-icon", class "-is-expanded", Util.testAttribute "home-search-bar" ]
        [ input
            [ Util.testAttribute "home-search-input"
            , autofocus True
            , placeholder "Type to filter all favorites..."
            , value <| filter
            , onInput search
            ]
            []
        , FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "aria-label" "filter" ]
        ]


{-| viewRepoSearchBarGlobal : renders an input bar for searching across all repos.
-}
viewRepoSearchBarGlobal : Dict Vela.Org String -> Search msg -> Html msg
viewRepoSearchBarGlobal searchFilters search =
    div [ class "form-control", class "-with-icon", class "-is-expanded", Util.testAttribute "global-search-bar" ]
        [ input
            [ Util.testAttribute "global-search-input"
            , placeholder "Type to filter all repositories..."
            , value <| searchFilterGlobal searchFilters
            , onInput <| search ""
            , id "global-search-input"
            ]
            []
        , FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "aria-label" "filter" ]
        ]


{-| viewRepoSearchBarLocal : takes filters and an org and renders a search bar for local repo filtering.
-}
viewRepoSearchBarLocal : Dict Vela.Org String -> Vela.Org -> Search msg -> Html msg
viewRepoSearchBarLocal searchFilters org search =
    div [ class "form-control", class "-with-icon", class "-is-expanded", Util.testAttribute "local-search-bar" ]
        [ input
            [ Util.testAttribute <| "local-search-input-" ++ org
            , placeholder <|
                "Type to filter repositories in "
                    ++ org
                    ++ "..."
            , value <| searchFilterLocal org searchFilters
            , onInput <| search org
            ]
            []
        , FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "aria-label" "filter" ]
        ]



-- HELPERS


{-| toLowerContains : lowercases user input to use for filter.
-}
toLowerContains : String -> String -> Bool
toLowerContains filterBy filterOn =
    let
        by =
            String.toLower filterBy

        on =
            String.toLower filterOn
    in
    String.contains by on


{-| filterRepo : takes org/repo display filters, the org and filters a single repo based on user-entered text.
-}
filterRepo : Dict Vela.Org String -> Maybe Vela.Org -> String -> Bool
filterRepo filters org filterOn =
    let
        org_ =
            Maybe.withDefault "" <| org

        filterBy =
            Maybe.withDefault "" <| Dict.get org_ filters
    in
    toLowerContains filterBy filterOn


{-| searchFilterGlobal : takes repo search filters and returns the global filter (org == "").
-}
searchFilterGlobal : Dict Vela.Org String -> String
searchFilterGlobal filters =
    Maybe.withDefault "" <| Dict.get "" filters


{-| searchFilterLocal : takes repo search filters and org and returns the local filter.
-}
searchFilterLocal : Vela.Org -> Dict Vela.Org String -> String
searchFilterLocal org filters =
    Maybe.withDefault "" <| Dict.get org filters


{-| shouldSearch : takes repo search filter and returns if results should be filtered.
-}
shouldSearch : String -> Bool
shouldSearch filter =
    String.length filter > 2
