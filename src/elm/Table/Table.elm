{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Table.Table exposing
    ( Config
    , Row
    , Rows
    , arrayCell
    , cell
    , customCell
    , view
    )

import Html
    exposing
        ( Html
        , code
        , div
        , span
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
        ( class
        )
import Util


type alias Column =
    String


type alias Columns =
    List Column


type alias Row data msg =
    { data : data
    , display : data -> Html msg
    }


type alias Rows data msg =
    List (Row data msg)


type alias Config data msg =
    { label : String
    , noRows : String
    , columns : Columns
    , rows : Rows data msg
    , action : Maybe (Html msg)
    }


{-| view : renders data table
-}
view : Config data msg -> Html msg
view { label, noRows, columns, rows, action } =
    div []
        [ Html.h2 []
            [ text label
            , Maybe.withDefault (text "") action
            ]
        , table [ class "table-base" ]
            [ thead [] [ tr [] <| List.map (\col -> td [] [ text col ]) columns ]
            , tbody [] <|
                if List.length rows > 0 then
                    List.map (\row_ -> row_.display row_.data) rows

                else
                    [ div [ class "no-rows" ] [ text noRows ] ]
            ]
        ]


{-| table\_ : renders table rows
-}
table_ : Config a msg -> List (Html msg)
table_ { label, noRows, columns, rows, action } =
    [ div [ class "table-label" ]
        [ text label
        , Maybe.withDefault (text "") action
        ]
    , headers columns
    ]
        ++ (if List.length rows > 0 then
                viewRows rows

            else
                [ div [ class "no-rows" ] [ text noRows ] ]
           )


{-| headers : renders table headers
-}
headers : Columns -> Html msg
headers columns =
    div [ class "headers" ] <|
        List.map (\col -> div [ class "header", class "column-width" ] [ text col ]) columns


{-| viewRows : renders data table rows
-}
viewRows : Rows a msg -> List (Html msg)
viewRows rows =
    List.map viewRow rows


{-| viewRow : renders hooks table row wrapped in details element
-}
viewRow : Row a msg -> Html msg
viewRow row =
    div [ class "details", class "-no-pad", class "row-container", Util.testAttribute "row" ]
        [ div [ class "row-display" ]
            [ row.display row.data ]
        ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute msg -> Html msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


{-| customCell : takes html and maybe attributes and renders cell data for hooks table row
-}
customCell : Html msg -> Html.Attribute msg -> Html msg
customCell element cls =
    div [ class "cell", cls ]
        [ span [] [ element ] ]


{-| arrayCell : takes string array and renders cell
-}
arrayCell : List String -> String -> Html msg
arrayCell items default =
    div [ class "cell", class "column-width" ] <|
        List.intersperse (text ",") <|
            if List.length items > 0 then
                List.map (\item -> code [ class "text" ] [ text item ]) items

            else
                [ code [ class "text" ] [ text default ] ]
