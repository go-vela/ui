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
        , text
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
    , testLabel : String
    }


{-| view : renders data table
-}
view : Config data msg -> Html msg
view config =
    div [ class "table", class "table", Util.testAttribute <| config.testLabel ++ "-table" ] <| table config


{-| table : renders table rows
-}
table : Config a msg -> List (Html msg)
table { label, noRows, columns, rows, action, testLabel } =
    [ div [ class "table-label" ]
        [ text label
        , Maybe.withDefault (text "") action
        ]
    , headers columns
    ]
        ++ (if List.length rows > 0 then
                viewRows rows

            else
                [ div [ class "no-rows", Util.testAttribute <| testLabel ++ "-table-no-rows" ] [ text noRows ] ]
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
