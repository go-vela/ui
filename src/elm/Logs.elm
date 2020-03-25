{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Logs exposing
    ( SetLogFocus
    , focusFragmentToFocusId
    , focusLogs
    , focusStep
    , logFocusExists
    , logFocusFragment
    , stepAndLineToFocusId
    , stepToFocusId
    , view
    )

import Base64 exposing (decode)
import Html
    exposing
        ( Html
        , button
        , code
        , div
        , span
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , id
        )
import List.Extra exposing (updateIf)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Util
import Vela
    exposing
        ( BuildNumber
        , FocusFragment
        , Log
        , LogFocus
        , Logs
        , Org
        , Repo
        , Step
        , StepNumber
        , Steps
        )



-- TYPES


{-| FocusFragment : update action for focusing a log line
-}
type alias SetLogFocus msg =
    String -> msg


type alias GetLogsFromSteps a msg =
    a -> Org -> Repo -> BuildNumber -> WebData Steps -> FocusFragment -> Cmd msg



-- VIEW


{-| view : takes step and logs and renders step logs or step error
-}
view : Step -> Logs -> SetLogFocus msg -> Bool -> Html msg
view step logs clickAction shiftDown =
    case step.status of
        Vela.Error ->
            stepError step

        _ ->
            viewLogs (String.fromInt step.number) step.logFocus (getStepLog step logs) clickAction shiftDown


{-| viewLogs : takes stepnumber linefocus log and clickAction shiftDown and renders logs for a build step
-}
viewLogs : StepNumber -> LogFocus -> Maybe (WebData Log) -> SetLogFocus msg -> Bool -> Html msg
viewLogs stepNumber logFocus log clickAction shiftDown =
    let
        content =
            case Maybe.withDefault RemoteData.NotAsked log of
                RemoteData.Success _ ->
                    if logNotEmpty <| decodeLog log then
                        viewLines stepNumber logFocus log clickAction shiftDown

                    else
                        code [] [ span [ class "no-logs" ] [ text "No logs for this step." ] ]

                RemoteData.Failure _ ->
                    code [ Util.testAttribute "logs-error" ] [ text "error" ]

                _ ->
                    div [ class "loading-logs" ] [ Util.smallLoaderWithText "loading logs..." ]
    in
    div [ class "logs", Util.testAttribute <| "logs-" ++ stepNumber ] [ content ]


{-| viewLines : takes step number, line focus information and click action and renders logs
-}
viewLines : StepNumber -> LogFocus -> Maybe (WebData Log) -> SetLogFocus msg -> Bool -> Html msg
viewLines stepNumber logFocus log clickAction shiftDown =
    div [ class "lines" ] <|
        List.indexedMap
            (\idx -> \line -> viewLine stepNumber line logFocus (idx + 1) clickAction shiftDown)
        <|
            decodeLogLine log


{-| viewLine : takes step number, line focus information, and click action and renders a log line
-}
viewLine : StepNumber -> String -> LogFocus -> Int -> SetLogFocus msg -> Bool -> Html msg
viewLine stepNumber line logFocus lineNumber clickAction shiftDown =
    div [ class "line" ]
        [ div
            [ Util.testAttribute <| "log-line-" ++ String.fromInt lineNumber
            , class "wrapper"
            , logFocusStyles logFocus lineNumber
            ]
            [ lineFocusButton stepNumber logFocus lineNumber clickAction shiftDown
            , code [] [ text line ]
            ]
        ]


{-| lineFocusButton : renders button for focusing log line ranges
-}
lineFocusButton : StepNumber -> LogFocus -> Int -> SetLogFocus msg -> Bool -> Html msg
lineFocusButton stepNumber logFocus lineNumber clickAction shiftDown =
    button
        [ Util.onClickPreventDefault <|
            clickAction <|
                logRangeId stepNumber lineNumber logFocus shiftDown
        , Util.testAttribute <| "log-line-num-" ++ String.fromInt lineNumber
        , id <| stepAndLineToFocusId stepNumber lineNumber
        , class "line-number"
        , attribute "aria-label" <| "focus step " ++ stepNumber
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]


{-| stepError : checks for build error and renders message
-}
stepError : Step -> Html msg
stepError step =
    div [ class "step-error", Util.testAttribute "step-error" ]
        [ span [ class "label" ] [ text "error:" ]
        , span [ class "message" ]
            [ text <|
                if String.isEmpty step.error then
                    "no error msg"

                else
                    step.error
            ]
        ]



-- HELPERS


{-| getStepLog : takes step and logs and returns the log corresponding to that step
-}
getStepLog : Step -> Logs -> Maybe (WebData Log)
getStepLog step logs =
    List.head
        (List.filter
            (\log ->
                case log of
                    RemoteData.Success log_ ->
                        log_.step_id == step.id

                    _ ->
                        False
            )
            logs
        )


{-| logFocusFragment : takes step number and maybe line numbers and produces URL fragment for focusing log ranges
-}
logFocusFragment : StepNumber -> List String -> String
logFocusFragment stepNumber args =
    String.join ":" <| [ "#step", stepNumber ] ++ args


{-| stepToFocusId : takes step number and returns the step focus id for auto focusing on page load
-}
stepToFocusId : StepNumber -> String
stepToFocusId stepNumber =
    "step-" ++ stepNumber


{-| stepAndLineToFocusId : takes step number and line number and returns the line focus id for auto focusing on page load
-}
stepAndLineToFocusId : StepNumber -> Int -> String
stepAndLineToFocusId stepNumber lineNumber =
    "step-" ++ stepNumber ++ "-line-" ++ String.fromInt lineNumber


{-| focusFragmentToFocusId : takes URL fragment and parses it into appropriate line focus id for auto focusing on page load
-}
focusFragmentToFocusId : FocusFragment -> String
focusFragmentToFocusId focusFragment =
    let
        parsed =
            parseFocusFragment focusFragment
    in
    case ( parsed.stepNumber, parsed.lineA, parsed.lineB ) of
        ( Just step, Just lineA, Nothing ) ->
            "step-" ++ String.fromInt step ++ "-line-" ++ String.fromInt lineA

        ( Just step, Just lineA, Just lineB ) ->
            "step-" ++ String.fromInt step ++ "-line-" ++ String.fromInt lineA ++ "-" ++ String.fromInt lineB

        ( Just step, Nothing, Nothing ) ->
            "step-" ++ String.fromInt step

        _ ->
            ""


{-| logRangeId : takes step, line, and focus information and returns the fragment for focusing a range of logs
-}
logRangeId : StepNumber -> Int -> LogFocus -> Bool -> String
logRangeId stepNumber lineNumber logFocus shiftDown =
    logFocusFragment stepNumber <|
        List.map String.fromInt
            (List.sort <|
                case ( shiftDown, logFocus ) of
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


{-| focusStep : takes FocusFragment URL fragment and expands the appropriate step to automatically view
-}
focusStep : FocusFragment -> Steps -> Steps
focusStep focusFragment steps =
    let
        parsed =
            parseFocusFragment focusFragment
    in
    case Maybe.withDefault "" parsed.target of
        "step" ->
            case parsed.stepNumber of
                Just n ->
                    updateIf (\step -> step.number == n)
                        (\step ->
                            { step | viewing = True, logFocus = ( parsed.lineA, parsed.lineB ) }
                        )
                        steps

                Nothing ->
                    steps

        _ ->
            steps


{-| focusLogs : takes model org, repo, build number and log line fragment and loads the appropriate build with focus set on the appropriate log line.
-}
focusLogs : a -> WebData Steps -> Org -> Repo -> BuildNumber -> FocusFragment -> GetLogsFromSteps a msg -> ( Page, WebData Steps, Cmd msg )
focusLogs model steps org repo buildNumber focusFragment getLogs =
    let
        ( stepsOut, action ) =
            case steps of
                RemoteData.Success steps_ ->
                    let
                        focusedSteps =
                            RemoteData.succeed <| updateStepLogFocus steps_ focusFragment
                    in
                    ( focusedSteps
                    , Cmd.batch
                        [ getLogs model org repo buildNumber focusedSteps focusFragment
                        ]
                    )

                _ ->
                    ( steps
                    , Cmd.none
                    )
    in
    ( Pages.Build org repo buildNumber focusFragment
    , stepsOut
    , action
    )


{-| updateStepLogFocus : takes steps and line focus and sets a new log line focus
-}
updateStepLogFocus : Steps -> FocusFragment -> Steps
updateStepLogFocus steps focusFragment =
    let
        parsed =
            parseFocusFragment focusFragment

        ( target, stepNumber ) =
            ( parsed.target, parsed.stepNumber )
    in
    case Maybe.withDefault "" target of
        "step" ->
            case stepNumber of
                Just n ->
                    List.map
                        (\step ->
                            if step.number == n then
                                { step | viewing = True, logFocus = ( parsed.lineA, parsed.lineB ) }

                            else
                                clearStepLogFocus step
                        )
                    <|
                        steps

                Nothing ->
                    steps

        _ ->
            steps


{-| parseFocusFragment : takes URL fragment and parses it into appropriate line focus chunks
-}
parseFocusFragment : FocusFragment -> { target : Maybe String, stepNumber : Maybe Int, lineA : Maybe Int, lineB : Maybe Int }
parseFocusFragment focusFragment =
    case String.split ":" (Maybe.withDefault "" focusFragment) of
        target :: step :: lineA :: lineB :: _ ->
            { target = Just target, stepNumber = String.toInt step, lineA = String.toInt lineA, lineB = String.toInt lineB }

        target :: step :: lineA :: _ ->
            { target = Just target, stepNumber = String.toInt step, lineA = String.toInt lineA, lineB = Nothing }

        target :: step :: _ ->
            { target = Just target, stepNumber = String.toInt step, lineA = Nothing, lineB = Nothing }

        _ ->
            { target = Nothing, stepNumber = Nothing, lineA = Nothing, lineB = Nothing }


{-| clearStepLogFocus : takes step and clears all log line focus
-}
clearStepLogFocus : Step -> Step
clearStepLogFocus step =
    { step | logFocus = ( Nothing, Nothing ) }


{-| logFocusStyles : takes maybe linefocus and linenumber and returns the appropriate style for highlighting a focused line
-}
logFocusStyles : LogFocus -> Int -> Html.Attribute msg
logFocusStyles logFocus lineNumber =
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
                class "-focus"

            else
                class ""

        ( Just lineA, Nothing ) ->
            if lineA == lineNumber then
                class "-focus"

            else
                class ""

        _ ->
            class ""


{-| logFocusExists : takes steps and returns if a line or range has already been focused
-}
logFocusExists : WebData Steps -> Bool
logFocusExists steps =
    (Maybe.withDefault ( Nothing, Nothing ) <|
        List.head <|
            List.map (\step -> step.logFocus) <|
                List.filter
                    (\step -> step.logFocus /= ( Nothing, Nothing ))
                <|
                    RemoteData.withDefault [] steps
    )
        /= ( Nothing, Nothing )


{-| decodeLogLine : takes maybe log and decodes it based on
-}
decodeLogLine : Maybe (WebData Log) -> List String
decodeLogLine log =
    List.filter (\line -> not <| String.isEmpty line) <|
        List.map String.trim <|
            String.lines <|
                decodeLog log


{-| decodeLog : returns a string from a Maybe Log and decodes it from base64
-}
decodeLog : Maybe (WebData Log) -> String
decodeLog log =
    case decode <| toString log of
        Ok str ->
            str

        Err _ ->
            ""


{-| logNotEmpty : takes log string and returns True if content exists
-}
logNotEmpty : String -> Bool
logNotEmpty log =
    not << String.isEmpty <| String.replace " " "" log


{-| toString : returns a string from a Maybe Log
-}
toString : Maybe (WebData Log) -> String
toString log =
    case log of
        Just log_ ->
            case log_ of
                RemoteData.Success l ->
                    l.data

                _ ->
                    ""

        Nothing ->
            ""
