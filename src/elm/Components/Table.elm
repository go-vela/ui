{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Table exposing
    ( Column
    , Columns
    , Config
    , Row
    , Rows
    , view
    , viewIconCell
    , viewItemCell
    , viewListCell
    , viewListItemCell
    )

import Html
    exposing
        ( Html
        , caption
        , div
        , span
        , table
        , tbody
        , td
        , text
        , tfoot
        , th
        , thead
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , scope
        )
import String.Extra
import Utils.Helpers as Util



-- TYPES


{-| Column : string alias for table column headers
-}
type alias Column =
    ( Maybe String, String )


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
    { label : Maybe String
    , testLabel : String
    , noRows : Html msg
    , columns : Columns
    , rows : Rows data msg
    , headerElement : Maybe (Html msg)
    }



-- VIEW


{-| view : renders data table
-}
view : Config data msg -> Html msg
view { label, testLabel, noRows, columns, rows, headerElement } =
    let
        numRows =
            List.length rows

        numColumns =
            List.length columns
    in
    table [ class "table-base", Util.testAttribute <| testLabel ++ "-table" ]
        [ case label of
            Just l ->
                caption []
                    [ div []
                        [ text l
                        , Maybe.withDefault (text "") headerElement
                        ]
                    ]

            Nothing ->
                text ""
        , thead []
            [ tr [] <|
                List.map
                    (\( className, col ) ->
                        th
                            [ class <| Maybe.withDefault "" className
                            , scope "col"
                            ]
                            [ text <| String.Extra.toTitleCase col ]
                    )
                    columns
            ]
        , viewFooter noRows numRows numColumns
        , tbody [] <| List.map (\row_ -> row_.display row_.data) rows
        ]


{-| viewFooter : renders data table footer
-}
viewFooter : Html msg -> Int -> Int -> Html msg
viewFooter noRows numRows numColumns =
    if numRows == 0 then
        tfoot [ class "no-rows" ] [ tr [] [ td [ attribute "colspan" <| String.fromInt numColumns ] [ noRows ] ] ]

    else
        text ""


{-| viewListCell : takes list of items, text for none and className and renders a table cell
-}
viewListCell : { dataLabel : String, items : List String, none : String, itemWrapperClassList : List ( String, Bool ) } -> Html msg
viewListCell { dataLabel, items, none, itemWrapperClassList } =
    if List.length items == 0 then
        span
            [ class "single-item"
            , Util.testAttribute <| "cell-list-item-" ++ dataLabel
            ]
            [ text none ]

    else
        items
            |> List.sort
            |> List.map
                (\item ->
                    div
                        [ classList itemWrapperClassList
                        , Util.testAttribute <| "cell-list-item-" ++ dataLabel
                        ]
                        [ span
                            [ class "list-item" ]
                            [ text item ]
                        ]
                )
            |> div []


{-| viewListItemCell : takes classlist and children elements and renders a list item cell element
-}
viewListItemCell : { dataLabel : String, parentClassList : List ( String, Bool ), itemWrapperClassList : List ( String, Bool ), itemClassList : List ( String, Bool ), children : List (Html msg) } -> Html msg
viewListItemCell { dataLabel, parentClassList, itemWrapperClassList, itemClassList, children } =
    td
        [ attribute "data-label" dataLabel
        , class "break-word"
        , classList parentClassList
        , Util.testAttribute <| "cell-" ++ dataLabel
        ]
        [ div [ classList itemWrapperClassList ]
            [ span
                [ class "list-item"
                , classList itemClassList
                ]
                children
            ]
        ]


{-| viewItemCell : takes classlist and children elements and renders a cell element
-}
viewItemCell : { dataLabel : String, parentClassList : List ( String, Bool ), itemClassList : List ( String, Bool ), children : List (Html msg) } -> Html msg
viewItemCell { dataLabel, parentClassList, itemClassList, children } =
    td
        [ attribute "data-label" dataLabel
        , class "break-word"
        , classList parentClassList
        , Util.testAttribute <| "cell-" ++ dataLabel
        ]
        [ span
            [ class "single-item"
            , classList itemClassList
            ]
            children
        ]


{-| viewIconCell : takes classlist and children elements and renders a cell icon element
-}
viewIconCell : { dataLabel : String, parentClassList : List ( String, Bool ), itemWrapperClassList : List ( String, Bool ), itemClassList : List ( String, Bool ), children : List (Html msg) } -> Html msg
viewIconCell { dataLabel, parentClassList, itemWrapperClassList, itemClassList, children } =
    td
        [ attribute "data-label" dataLabel
        , class "break-word"
        , class "table-icon"
        , classList parentClassList
        , Util.testAttribute <| "cell-" ++ dataLabel
        ]
        [ div
            [ classList itemWrapperClassList
            ]
            [ div [ classList itemClassList ] children ]
        ]
