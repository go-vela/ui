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
        , div
        , span
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
        , classList
        , scope
        )
import String.Extra
import Utils.Helpers as Util


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
    { label : String
    , testLabel : String
    , noRows : Html msg
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

        numColumns =
            List.length columns
    in
    Html.table [ class "table-base", Util.testAttribute <| testLabel ++ "-table" ]
        [ Html.caption []
            [ div []
                [ text label
                , Maybe.withDefault (text "") headerElement
                ]
            ]
        , thead [] [ tr [] <| List.map (\( className, col ) -> th [ class <| Maybe.withDefault "" className, scope "col" ] [ text <| String.Extra.toTitleCase col ]) columns ]
        , footer noRows numRows numColumns
        , tbody [] <| List.map (\row_ -> row_.display row_.data) rows
        ]


{-| footer : renders data table footer
-}
footer : Html msg -> Int -> Int -> Html msg
footer noRows numRows numColumns =
    if numRows == 0 then
        Html.tfoot [ class "no-rows" ] [ tr [] [ td [ attribute "colspan" <| String.fromInt numColumns ] [ noRows ] ] ]

    else
        text ""


{-| viewListCell : takes list of items, text for none and className and renders a table cell
-}
viewListCell : List String -> String -> List ( String, Bool ) -> Html msg
viewListCell items none itemWrapperClassList =
    if List.length items == 0 then
        span
            [ class "single-item"
            ]
            [ text none ]

    else
        items
            |> List.sort
            |> List.map
                (\item ->
                    div [ classList itemWrapperClassList ]
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
        , scope "row"
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
        , scope "row"
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
        ]
        [ div
            [ classList itemWrapperClassList
            ]
            [ div [ classList itemClassList ] children ]
        ]
