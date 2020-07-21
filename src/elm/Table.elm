{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Table exposing
    ( Config
    , Row
    , Rows
    , view
    )

import Html
    exposing
        ( Html
        , div
        , table
        , tbody
        , td
        , text
        , th
        , thead
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , scope
        )
import String.Extra
import Util


{-| Column : string alias for table column headers
-}
type alias Column =
    String


{-| Columns : list of columns
-}
type alias Columns =
    List Column


{-| Rows : object containing render data and msg
-}
type alias Row data msg =
    { data : data
    , display : data -> Html msg
    }


{-| Rows : list of rows with render data and msg
-}
type alias Rows data msg =
    List (Row data msg)


{-| Config : configurations for rendering the data table
-}
type alias Config data msg =
    { label : String
    , testLabel : String
    , noRows : String
    , columns : Columns
    , rows : Rows data msg
    , headerElement : Maybe (Html msg)
    }


{-| view : renders data table
-}
view : Config data msg -> Html msg
view { label, testLabel, noRows, columns, rows, headerElement } =
    let
        numRows =
            List.length rows
    in
    Html.table [ class "table-base", Util.testAttribute <| testLabel ++ "-table" ]
        [ Html.caption []
            [ div []
                [ text label
                , Maybe.withDefault (text "") headerElement
                ]
            ]
        , thead [] [ tr [] <| List.map (\col -> th [ scope "col" ] [ text <| String.Extra.toTitleCase col ]) columns ]
        , footer noRows numRows
        , tbody [] <| List.map (\row_ -> row_.display row_.data) rows
        ]


{-| footer : renders data table footer
-}
footer : String -> Int -> Html msg
footer noRows numRows =
    if numRows == 0 then
        Html.tfoot [ class "no-rows" ] [ tr [] [ td [ attribute "colspan" "5" ] [ text noRows ] ] ]

    else
        text ""
