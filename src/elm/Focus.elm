module Focus exposing (..)

import Vela exposing (FocusFragment, LogFocus)


type alias RefQuery =
    String


type alias ExpandTemplatesQuery =
    String


type alias Fragment =
    String


type alias Resource =
    String


type alias ResourceID =
    String

type alias FocusLineNumber msg =
    Int -> msg


{-| resourceFocusFragment : takes resource tag and maybe line numbers and produces URL fragment for focusing line ranges
-}
resourceFocusFragment : Resource -> ResourceID -> List String -> String
resourceFocusFragment resource resourceId args =
    String.join ":" <| [ "#" ++ resource, resourceId ] ++ args


{-| resourceToFocusId : takes resource and id and returns the resource focus id for auto focusing on page load
-}
resourceToFocusId : Resource -> ResourceID -> String
resourceToFocusId resource resourceID =
    String.join "-" [ resource, resourceID ]


{-| resourceAndLineToFocusId : takes resource, id and line number and returns the line focus id for auto focusing on page load
-}
resourceAndLineToFocusId : Resource -> ResourceID -> Int -> String
resourceAndLineToFocusId resource resourceID lineNumber =
    String.join "-" [ resource, resourceID, "line", String.fromInt lineNumber ]


{-| focusFragmentToFocusId : takes URL fragment and parses it into appropriate line focus id for auto focusing on page load
-}
focusFragmentToFocusId : Resource -> FocusFragment -> String
focusFragmentToFocusId resource focusFragment =
    let
        parsed =
            parseFocusFragment focusFragment
    in
    case ( parsed.resourceID, parsed.lineA, parsed.lineB ) of
        ( Just resourceID, Just lineA, Nothing ) ->
            "resource-" ++ String.fromInt resourceID ++ "-line-" ++ String.fromInt lineA

        ( Just resourceID, Just lineA, Just lineB ) ->
            "resource-" ++ String.fromInt resourceID ++ "-line-" ++ String.fromInt lineA ++ "-" ++ String.fromInt lineB

        ( Just resourceID, Nothing, Nothing ) ->
            "resource-" ++ String.fromInt resourceID

        _ ->
            ""


{-| parseFocusFragment : takes URL fragment and parses it into appropriate line focus chunks
-}
parseFocusFragment : FocusFragment -> { target : Maybe String, resourceID : Maybe Int, lineA : Maybe Int, lineB : Maybe Int }
parseFocusFragment focusFragment =
    case String.split ":" (Maybe.withDefault "" focusFragment) of
        target :: resourceID :: lineA :: lineB :: _ ->
            { target = Just target, resourceID = String.toInt resourceID, lineA = String.toInt lineA, lineB = String.toInt lineB }

        target :: resourceID :: lineA :: _ ->
            { target = Just target, resourceID = String.toInt resourceID, lineA = String.toInt lineA, lineB = Nothing }

        target :: resourceID :: _ ->
            { target = Just target, resourceID = String.toInt resourceID, lineA = Nothing, lineB = Nothing }

        _ ->
            { target = Nothing, resourceID = Nothing, lineA = Nothing, lineB = Nothing }


{-| lineRangeId : takes resource, line, and focus information and returns the fragment for focusing a range of lines
-}
lineRangeId : Resource -> ResourceID -> Int -> LogFocus -> Bool -> String
lineRangeId resource resourceID lineNumber lineFocus shiftDown =
    resourceFocusFragment resource resourceID <|
        List.map String.fromInt
            (List.sort <|
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
            )


{-| lineFocusStyles : takes maybe linefocus and linenumber and returns the appropriate style for highlighting a focused line
-}
lineFocusStyles : LogFocus -> Int -> String
lineFocusStyles logFocus lineNumber =
    case logFocus of
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
