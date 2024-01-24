{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Focus exposing
    ( FocusTarget
    , LineFocus
    , focusFragmentToFocusId
    , lineFocusStyles
    , lineRangeId
    , parseFocusFragment
    , resourceAndLineToFocusId
    , resourceFocusFragment
    , resourceToFocusId
    )

import Maybe.Extra


type alias LineFocus =
    ( Maybe Int, Maybe Int )


type alias FocusTarget =
    { target : Maybe String
    , resourceNumber : Maybe Int
    , lineA : Maybe Int
    , lineB : Maybe Int
    }


{-| resourceFocusFragment : takes resource tag and maybe line numbers and produces URL fragment for focusing line ranges
-}
resourceFocusFragment : String -> String -> List String -> String
resourceFocusFragment resource resourceId args =
    String.join ":" <| resource :: resourceId :: args


{-| resourceToFocusId : takes resource and id and returns the resource focus id for auto focusing on page load
-}
resourceToFocusId : String -> String -> String
resourceToFocusId resource resourceNumber =
    String.join "-" [ resource, resourceNumber ]


{-| resourceAndLineToFocusId : takes resource, id and line number and returns the line focus id for auto focusing on page load
-}
resourceAndLineToFocusId : String -> String -> Int -> String
resourceAndLineToFocusId resource resourceNumber lineNumber =
    String.join "-" [ resource, resourceNumber, "line", String.fromInt lineNumber ]


{-| focusFragmentToFocusId : takes URL fragment and parses it into appropriate line focus id for auto focusing on page load
-}
focusFragmentToFocusId : String -> Maybe String -> String
focusFragmentToFocusId resource focusFragment =
    let
        parsed =
            parseFocusFragment focusFragment
    in
    case ( parsed.resourceNumber, parsed.lineA, parsed.lineB ) of
        ( Just resourceNumber, Just lineA, Nothing ) ->
            resource ++ "-" ++ String.fromInt resourceNumber ++ "-line-" ++ String.fromInt lineA

        ( Just resourceNumber, Just lineA, Just lineB ) ->
            resource ++ "-" ++ String.fromInt resourceNumber ++ "-line-" ++ String.fromInt lineA ++ "-" ++ String.fromInt lineB

        ( Just resourceNumber, Nothing, Nothing ) ->
            resource ++ "-" ++ String.fromInt resourceNumber

        _ ->
            ""


{-| parseFocusFragment : takes URL fragment and parses it into appropriate line focus chunks
-}
parseFocusFragment : Maybe String -> FocusTarget
parseFocusFragment focusFragment =
    case String.split ":" (Maybe.withDefault "" focusFragment) of
        target :: resourceNumber :: lineA :: lineB :: _ ->
            { target = Just target, resourceNumber = String.toInt resourceNumber, lineA = String.toInt lineA, lineB = String.toInt lineB }

        target :: resourceNumber :: lineA :: _ ->
            { target = Just target, resourceNumber = String.toInt resourceNumber, lineA = String.toInt lineA, lineB = Nothing }

        target :: resourceNumber :: _ ->
            { target = Just target, resourceNumber = String.toInt resourceNumber, lineA = Nothing, lineB = Nothing }

        _ ->
            { target = Nothing, resourceNumber = Nothing, lineA = Nothing, lineB = Nothing }


{-| lineRangeId : takes resource, line, and focus information and returns the fragment for focusing a range of lines
-}
lineRangeId : String -> String -> Int -> Maybe LineFocus -> Bool -> String
lineRangeId resource resourceNumber lineNumber maybeLineFocus shiftDown =
    resourceFocusFragment resource resourceNumber <|
        List.map String.fromInt
            (List.sort <|
                case maybeLineFocus of
                    Just lineFocus ->
                        case ( shiftDown, lineFocus ) of
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

                    Nothing ->
                        [ lineNumber ]
            )


{-| lineFocusStyles : takes maybe linefocus and linenumber and returns the appropriate style for highlighting a focused line
-}
lineFocusStyles : Maybe LineFocus -> Int -> String
lineFocusStyles lineFocus lineNumber =
    lineFocus
        |> Maybe.Extra.unwrap ""
            (\focus ->
                case focus of
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
            )
