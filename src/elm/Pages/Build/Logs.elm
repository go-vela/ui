{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Logs exposing
    ( SetLogFocus
    , decodeAnsi
    , focusFragmentToFocusId
    , focusLogs
    , focusStep
    , getCurrentStep
    , getDownloadLogsFileName
    , getStepLog
    , logEmpty
    , logFocusExists
    , logFocusFragment
    , logFocusStyles
    , logRangeId
    , stepAndLineToFocusId
    , stepBottomTrackerFocusId
    , stepToFocusId
    , stepTopTrackerFocusId
    , toString
    )

import Ansi.Log
import Array
import List.Extra exposing (updateIf)
import Pages exposing (Page)
import Pages.Build.Model exposing (Msg(..))
import RemoteData exposing (WebData)
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
    a -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd msg



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


{-| getCurrentStep : takes steps and returns the newest running or pending step
-}
getCurrentStep : Steps -> Int
getCurrentStep steps =
    let
        step =
            steps
                |> List.filter (\s -> s.status == Vela.Pending || s.status == Vela.Running)
                |> List.map .number
                |> List.sort
                |> List.head
                |> Maybe.withDefault 0
    in
    step


{-| focusLogs : takes model org, repo, build number and log line fragment and loads the appropriate build with focus set on the appropriate log line.
-}
focusLogs : a -> Steps -> Org -> Repo -> BuildNumber -> FocusFragment -> GetLogsFromSteps a msg -> ( Page, Steps, Cmd msg )
focusLogs model steps org repo buildNumber focusFragment getLogs =
    let
        ( stepsOut, action ) =
            let
                focusedSteps =
                    updateStepLogFocus steps focusFragment
            in
            ( focusedSteps
            , Cmd.batch
                [ getLogs model org repo buildNumber focusedSteps focusFragment False
                ]
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
logFocusStyles : LogFocus -> Int -> String
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


{-| logEmpty : takes log string and returns True if content does not exist
-}
logEmpty : String -> Bool
logEmpty log =
    String.isEmpty <| String.replace " " "" log


{-| toString : returns a string from a Maybe Log
-}
toString : Maybe (WebData Log) -> String
toString log =
    case log of
        Just log_ ->
            case log_ of
                RemoteData.Success l ->
                    l.decodedLogs

                _ ->
                    ""

        Nothing ->
            ""


{-| stepTopTrackerFocusId : takes step number and returns the line focus id for auto focusing on log follow
-}
stepTopTrackerFocusId : StepNumber -> String
stepTopTrackerFocusId stepNumber =
    "step-" ++ stepNumber ++ "-line-tracker-top"


{-| stepBottomTrackerFocusId : takes step number and returns the line focus id for auto focusing on log follow
-}
stepBottomTrackerFocusId : StepNumber -> String
stepBottomTrackerFocusId stepNumber =
    "step-" ++ stepNumber ++ "-line-tracker-bottom"


{-| getDownloadLogsFileName : takes step information and produces a filename for downloading logs
-}
getDownloadLogsFileName : Org -> Repo -> BuildNumber -> String -> String -> String
getDownloadLogsFileName org repo buildNumber resourceType resourceNumber =
    String.join "-" [ org, repo, buildNumber, resourceType, resourceNumber ]



-- ANSI


{-| defaultLogModel : struct to represent default model required by ANSI parser
-}
defaultLogModel : Ansi.Log.Model
defaultLogModel =
    { lineDiscipline = Ansi.Log.Cooked
    , lines = Array.empty
    , position = defaultPosition
    , savedPosition = Nothing
    , style = defaultLogStyle
    , remainder = ""
    }


{-| defaultLogStyle : struct to represent default style required by ANSI model
-}
defaultLogStyle : Ansi.Log.Style
defaultLogStyle =
    { foreground = Nothing
    , background = Nothing
    , bold = False
    , faint = False
    , italic = False
    , underline = False
    , blink = False
    , inverted = False
    , fraktur = False
    , framed = False
    }


{-| defaultPosition : default ANSI cursor position
-}
defaultPosition : Ansi.Log.CursorPosition
defaultPosition =
    { row = 0
    , column = 0
    }


{-| decodeAnsi : takes maybe log parses into ansi decoded log line array
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
-}
decodeAnsi : String -> Array.Array Ansi.Log.Line
decodeAnsi log =
    .lines <| Ansi.Log.update log defaultLogModel
