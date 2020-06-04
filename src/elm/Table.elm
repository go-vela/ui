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
    , headerElement : Maybe (Html msg)
    }


{-| view : renders data table
-}
view : Config data msg -> Html msg
view { label, noRows, columns, rows, headerElement } =
    let
        numRows =
            List.length rows
    in
    Html.table [ class "table-base" ]
        [ Html.caption []
            [ div []
                [ text label
                , Maybe.withDefault (text "") headerElement
                ]
            ]
        , thead [] [ tr [] <| List.map (\col -> th [ scope "col" ] [ text col ]) columns ]
        , footer noRows numRows
        , tbody [] <|
            if List.length rows > 0 then
                List.map (\row_ -> row_.display row_.data) rows

            else
                []
        ]


footer : String -> Int -> Html msg
footer noRows numRows =
    if numRows == 0 then
        Html.tfoot [ class "no-rows" ] [ tr [] [ td [ attribute "colspan" "5" ] [ text noRows ] ] ]

    else
        text ""
