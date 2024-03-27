{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Focus exposing
    ( Focus
    , canTarget
    , fromAttrId
    , fromString
    , fromStringNoGroup
    , lineNumberChanged
    , lineRangeStyles
    , toAttr
    , toDomTarget
    , toString
    , updateLineRange
    )

import Html
import Html.Attributes
import Maybe.Extra


{-| Focus : an object that represents a point of focus.
-}
type alias Focus =
    { group : Maybe Int
    , a : Maybe Int
    , b : Maybe Int
    }


{-| fromString : returns the Focus object from a (route) string,
where group is a placeholder for step or service.

example: octo/cat/3#1:5:7 (build 3, step 1, log lines 5 to 7)

{ group = 1
, a = 5
, b = 7
}

-}
fromString : Maybe String -> Focus
fromString =
    Maybe.Extra.unwrap
        { group = Nothing
        , a = Nothing
        , b = Nothing
        }
        (\str ->
            case String.split ":" str of
                a :: b :: c :: _ ->
                    { group = String.toInt a
                    , a = String.toInt b
                    , b = String.toInt c
                    }

                a :: b :: _ ->
                    { group = String.toInt a
                    , a = String.toInt b
                    , b = Nothing
                    }

                a :: _ ->
                    { group = String.toInt a
                    , a = Nothing
                    , b = Nothing
                    }

                _ ->
                    { group = String.toInt str
                    , a = Nothing
                    , b = Nothing
                    }
        )


{-| fromStringNoGroup : returns the Focus object from a (route) string,
where group doesn't exist.

example: octo/cat/3/pipeline#2:5 (build 3, pipeline lines 2 to 5)

{ group = nothing
, a = 2
, b = 5
}

-}
fromStringNoGroup : Maybe String -> Focus
fromStringNoGroup =
    Maybe.Extra.unwrap
        { group = Nothing
        , a = Nothing
        , b = Nothing
        }
        (\str ->
            case String.split ":" str of
                a :: b :: _ ->
                    { group = Nothing
                    , a = String.toInt a
                    , b = String.toInt b
                    }

                a :: _ ->
                    { group = Nothing
                    , a = String.toInt a
                    , b = Nothing
                    }

                _ ->
                    { group = Nothing
                    , a = String.toInt str
                    , b = Nothing
                    }
        )


{-| toString : converts a Focus object into a string.
-}
toString : Focus -> String
toString focus =
    [ focus.group, focus.a, focus.b ]
        |> List.filterMap identity
        |> List.map String.fromInt
        |> String.join ":"


{-| fromAttrId : returns the Focus object from an id.
-}
fromAttrId : String -> Focus
fromAttrId id_ =
    case String.split "-" id_ of
        _ :: a :: b :: c :: [] ->
            { group = String.toInt a
            , a = String.toInt b
            , b = String.toInt c
            }

        _ :: a :: b :: [] ->
            { group = String.toInt a
            , a = String.toInt b
            , b = Nothing
            }

        _ :: a :: [] ->
            { group = String.toInt a
            , a = Nothing
            , b = Nothing
            }

        _ ->
            { group = String.toInt id_
            , a = Nothing
            , b = Nothing
            }


{-| toDomTarget : converts a Focus object into a string.
-}
toDomTarget : Focus -> String
toDomTarget focus =
    (case ( focus.group, focus.a, focus.b ) of
        ( Just group, Just a, Just _ ) ->
            [ group, a ]

        ( Just group, Just a, _ ) ->
            [ group, a ]

        ( Just group, _, Just b ) ->
            [ group, b ]

        ( Just group, Nothing, Nothing ) ->
            [ group ]

        ( _, Just a, _ ) ->
            [ a ]

        _ ->
            []
    )
        |> List.map String.fromInt
        |> (::) "focus"
        |> String.join "-"


{-| toAttr : converts a Focus object into an Html.Attribute.
-}
toAttr : Focus -> Html.Attribute msg
toAttr focus =
    [ focus.group, focus.a, focus.b ]
        |> List.filterMap identity
        |> List.map String.fromInt
        |> (::) "focus"
        |> String.join "-"
        |> Html.Attributes.id


{-| canTarget : .
-}
canTarget : Focus -> Bool
canTarget focus =
    case ( focus.group, focus.a, focus.b ) of
        ( Just _, _, _ ) ->
            True

        ( _, Just _, _ ) ->
            True

        _ ->
            False


{-| updateLineRange : .
-}
updateLineRange : Bool -> Maybe Int -> Int -> Focus -> Focus
updateLineRange shiftKeyDown group lineNumber focus =
    (case ( shiftKeyDown, ( focus.a, focus.b ) ) of
        ( True, ( Just lineA, Just lineB ) ) ->
            if lineNumber < lineA then
                [ lineNumber, lineB ]

            else
                [ lineA, lineNumber ]

        ( True, ( Just lineA, _ ) ) ->
            if lineNumber < lineA then
                [ lineNumber, lineA ]

            else
                [ lineA, lineNumber ]

        _ ->
            [ lineNumber ]
    )
        |> List.sort
        |> (\range ->
                case range of
                    a :: b :: [] ->
                        { group = group
                        , a = Just a
                        , b = Just b
                        }

                    a :: [] ->
                        { group = group
                        , a = Just a
                        , b = Nothing
                        }

                    _ ->
                        { group = group
                        , a = Nothing
                        , b = Nothing
                        }
           )


{-| lineRangeStyles : .
-}
lineRangeStyles : Maybe Int -> Int -> Focus -> String
lineRangeStyles group lineNumber focus =
    case ( focus.group, focus.a, focus.b ) of
        ( _, Just lineA, Just lineB ) ->
            let
                ( a, b ) =
                    if lineA < lineB then
                        ( lineA, lineB )

                    else
                        ( lineB, lineA )
            in
            if group == focus.group && lineNumber >= a && lineNumber <= b then
                "-focus"

            else
                ""

        ( _, Just lineA, Nothing ) ->
            if group == focus.group && lineA == lineNumber then
                "-focus"

            else
                ""

        _ ->
            ""


{-| lineNumberChanged : .
-}
lineNumberChanged : Maybe Focus -> Focus -> Maybe Int
lineNumberChanged maybeBefore after =
    case maybeBefore of
        Just before ->
            case ( ( before.a, before.b ), ( after.a, after.b ) ) of
                ( ( Just a1, Just b1 ), ( Just a2, Just b2 ) ) ->
                    if a1 /= a2 then
                        Just a2

                    else if b1 /= b2 then
                        Just b2

                    else
                        Nothing

                ( ( Just _, Just _ ), ( Just a2, Nothing ) ) ->
                    Just a2

                ( ( Just _, Just _ ), ( Nothing, Nothing ) ) ->
                    Nothing

                ( ( Just a1, Nothing ), ( Just a2, Just b2 ) ) ->
                    if a1 /= a2 then
                        Just a2

                    else
                        Just b2

                ( ( Nothing, Nothing ), ( Just a2, Just _ ) ) ->
                    Just a2

                ( ( Nothing, Nothing ), ( Just a2, Nothing ) ) ->
                    Just a2

                ( ( Just _, Nothing ), ( Just a2, Nothing ) ) ->
                    Just a2

                _ ->
                    Nothing

        _ ->
            case ( after.a, after.b ) of
                ( Just a, _ ) ->
                    Just a

                _ ->
                    Nothing
