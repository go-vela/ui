{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Focus exposing
    ( Focus
    , canTarget
    , fromAttrId
    , fromString
    , fromStringNoGroup
    , lineRangeStyles
    , toAttr
    , toDomTarget
    , toString
    , updateLineRange
    )

import Html
import Html.Attributes
import Maybe.Extra
import Shared


type alias Focus =
    { group : Maybe Int
    , a : Maybe Int
    , b : Maybe Int
    }


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


toString : Focus -> String
toString focus =
    [ focus.group, focus.a, focus.b ]
        |> List.filterMap identity
        |> List.map String.fromInt
        |> String.join ":"


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


toAttr : Focus -> Html.Attribute msg
toAttr focus =
    [ focus.group, focus.a, focus.b ]
        |> List.filterMap identity
        |> List.map String.fromInt
        |> (::) "focus"
        |> String.join "-"
        |> Html.Attributes.id


canTarget : Focus -> Bool
canTarget focus =
    case ( focus.group, focus.a, focus.b ) of
        ( Just _, _, _ ) ->
            True

        ( _, Just _, _ ) ->
            True

        _ ->
            False


updateLineRange : Shared.Model -> Focus -> Int -> Focus
updateLineRange shared focus lineNumber =
    (case ( shared.shift, ( focus.a, focus.b ) ) of
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
                        { focus
                            | a = Just a
                            , b = Just b
                        }

                    a :: [] ->
                        { focus
                            | a = Just a
                            , b = Nothing
                        }

                    _ ->
                        { focus
                            | a = Nothing
                            , b = Nothing
                        }
           )


lineRangeStyles : Focus -> Int -> String
lineRangeStyles focus lineNumber =
    case ( focus.a, focus.b ) of
        ( Just lineA, Just lineB ) ->
            let
                ( a, b ) =
                    if lineA < lineB then
                        ( lineA, lineB )

                    else
                        ( lineB, lineA )
            in
            if lineNumber >= a && lineNumber <= b then
                "-focus"

            else
                ""

        ( Just lineA, Nothing ) ->
            if lineA == lineNumber then
                "-focus"

            else
                ""

        _ ->
            ""
