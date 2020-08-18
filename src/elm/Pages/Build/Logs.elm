{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Logs exposing
    ( SetLogFocus
    , expandSteps
    , focusFragmentToFocusId
    , focusLogs
    , focusStep
    , getCurrentStep
    , latestTracker
    , logEmpty
    , logFocusExists
    , logFocusFragment
    , stepAndLineToFocusId
    , stepBottomTrackerFocusId
    , stepFollowButton
    , stepLogFocus
    , stepToFocusId
    , updateSteps
    , view
    , viewingStep
    )

import Ansi.Log
import Array
import Base64 exposing (decode)
import FeatherIcons
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
import Html.Events exposing (onClick)
import List.Extra exposing (updateIf)
import Pages exposing (Page)
import Pages.Build.Model exposing (Msg(..))
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
    a -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd msg



-- VIEW


{-| view : takes step and logs and renders step logs or step error
-}
view : Step -> Logs -> Int -> Bool -> Html Msg
view step logs follow shiftDown =
    case step.status of
        Vela.Error ->
            stepError step

        Vela.Killed ->
            stepKilled step

        _ ->
            viewLogs (String.fromInt step.number) step.logFocus (getStepLog step logs) follow shiftDown


{-| viewLogs : takes stepnumber linefocus log and clickAction shiftDown and renders logs for a build step
-}
viewLogs : StepNumber -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html Msg
viewLogs stepNumber logFocus log following shiftDown =
    let
        content =
            case Maybe.withDefault RemoteData.NotAsked log of
                RemoteData.Success _ ->
                    if not <| logEmpty log then
                        viewLines stepNumber logFocus log following shiftDown

                    else
                        code []
                            [ span [ class "no-logs" ]
                                [ text "No logs for this step."
                                , stepFollowButton stepNumber following
                                ]
                            ]

                RemoteData.Failure _ ->
                    code [ Util.testAttribute "logs-error" ] [ text "error" ]

                _ ->
                    div [ class "loading-logs" ] [ Util.smallLoaderWithText "loading logs..." ]
    in
    div [ class "logs", Util.testAttribute <| "logs-" ++ stepNumber ] [ content ]


{-| viewLines : takes step number, line focus information and click action and renders logs
-}
viewLines : StepNumber -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html Msg
viewLines stepNumber logFocus log following shiftDown =
    let
        lines =
            log
                |> decodeAnsi
                |> Array.indexedMap
                    (\idx line ->
                        Just <|
                            viewLine stepNumber
                                (idx + 1)
                                line
                                stepNumber
                                logFocus
                                shiftDown
                    )
                |> Array.toList

        long =
            List.length lines > 25

        topActions =
            Just <|
                Html.tr
                    [ class "line" ]
                    [ div [ class "wrapper", class "justify-flex-end" ]
                        [ button [ class "button", class "-icon", attribute "data-tooltip" "download logs", class "tooltip-left" ]
                            [ FeatherIcons.download |> FeatherIcons.toHtml [ attribute "role" "img" ] ]
                        , stepFollowButton stepNumber following
                        , if long then
                            button
                                [ attribute "data-tooltip" "jump to bottom"
                                , class "tooltip-left"
                                , class "button"
                                , class "-icon"
                                , onClick <| FocusOn <| stepBottomTrackerFocusId stepNumber
                                ]
                                [ FeatherIcons.arrowDownCircle |> FeatherIcons.toHtml [ attribute "role" "img" ] ]

                          else
                            text ""
                        ]
                    ]

        bottomActions =
            Just <|
                Html.tr
                    [ class "line" ]
                    [ div [ class "wrapper", class "justify-flex-end" ] <|
                        if long then
                            [ stepFollowButton stepNumber following
                            , button
                                [ attribute "data-tooltip" "jump to top"
                                , class "tooltip-left"
                                , class "button"
                                , class "-icon"
                                , onClick <| FocusOn <| stepTopTrackerFocusId stepNumber
                                ]
                                [ FeatherIcons.arrowUpCircle |> FeatherIcons.toHtml [ attribute "role" "img" ] ]
                            ]

                        else
                            [ text "" ]
                    ]

        logs =
            topActions
                :: lines
                ++ [ bottomActions ]
                |> List.filterMap identity

        topTracker =
            Html.tr [ class "line", class "tracker" ]
                [ button
                    [ id <|
                        stepTopTrackerFocusId stepNumber
                    , Html.Attributes.autofocus True
                    ]
                    []
                ]

        bottomTracker =
            Html.tr [ class "line", class "tracker" ]
                [ button
                    [ id <|
                        stepBottomTrackerFocusId stepNumber
                    , Html.Attributes.autofocus True
                    ]
                    []
                ]
    in
    Html.table [ class "log-table" ] <| topTracker :: logs ++ [ bottomTracker ]


stepFollowButton : StepNumber -> Int -> Html Msg
stepFollowButton stepNumber following =
    let
        stepNum =
            Maybe.withDefault 0 <| String.toInt stepNumber

        ( tooltip, icon, toFollow ) =
            if following == 0 then
                ( "start following step logs", FeatherIcons.playCircle, stepNum )

            else if following == (Maybe.withDefault 0 <| String.toInt stepNumber) then
                ( "stop following step logs", FeatherIcons.pauseCircle, 0 )

            else
                ( "start following step logs", FeatherIcons.playCircle, stepNum )
    in
    Html.button
        [ class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , class "button"
        , class "-icon"
        , class "follow"
        , onClick <| FollowStep toFollow
        ]
        [ icon |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| stepTopTrackerFocusId : takes step number and returns the line focus id for auto focusing on log follow
-}
stepTopTrackerFocusId : StepNumber -> String
stepTopTrackerFocusId stepNumber =
    "step-" ++ stepNumber ++ "-line-tracker-top"


{-| stepBottomTrackerFocusId : takes step number and returns the line focus id for auto focusing on log follow
-}
stepBottomTrackerFocusId : StepNumber -> String
stepBottomTrackerFocusId stepNumber =
    "step-" ++ stepNumber ++ "-line-tracker"


{-| viewLine : takes log line and focus information and renders line number button and log
-}
viewLine : String -> Int -> Ansi.Log.Line -> StepNumber -> LogFocus -> Bool -> Html Msg
viewLine id lineNumber line stepNumber logFocus shiftDown =
    Html.tr
        [ Html.Attributes.id <|
            id
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ div
            [ class "wrapper"
            , Util.testAttribute <| String.join "-" [ "log", "line", stepNumber, String.fromInt lineNumber ]
            , logFocusStyles logFocus lineNumber
            ]
            [ Html.td []
                [ lineFocusButton stepNumber logFocus lineNumber shiftDown ]
            , Html.td [ class "break-all", class "overflow-auto" ]
                [ code [ Util.testAttribute <| String.join "-" [ "log", "data", stepNumber, String.fromInt lineNumber ] ]
                    [ Ansi.Log.viewLine line ]
                ]
            ]
        ]


{-| lineFocusButton : renders button for focusing log line ranges
-}
lineFocusButton : StepNumber -> LogFocus -> Int -> Bool -> Html Msg
lineFocusButton stepNumber logFocus lineNumber shiftDown =
    button
        [ Util.onClickPreventDefault <|
            FocusLogs <|
                logRangeId stepNumber lineNumber logFocus shiftDown
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", stepNumber, String.fromInt lineNumber ]
        , id <| stepAndLineToFocusId stepNumber lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
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


{-| stepKilled : renders message for a killed step
-}
stepKilled : Step -> Html msg
stepKilled _ =
    div [ class "step-error", Util.testAttribute "step-error" ]
        [ span [ class "label" ] [ text "step was killed" ] ]



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


updateSteps : Maybe String -> Bool -> Bool -> WebData Steps -> Steps -> Steps
updateSteps logFocus isRefresh autoExpand currentSteps incomingSteps =
    let
        updatedSteps =
            case currentSteps of
                RemoteData.Success steps ->
                    List.map
                        (\incomingStep ->
                            Util.overwriteById
                                { incomingStep
                                    | viewing =
                                        (viewingStep currentSteps <| String.fromInt incomingStep.number)
                                            || (autoExpand && incomingStep.status /= Vela.Pending)
                                    , logFocus = stepLogFocus currentSteps <| String.fromInt incomingStep.number
                                }
                                steps
                        )
                        incomingSteps
                        |> List.filterMap identity

                _ ->
                    incomingSteps
    in
    if isRefresh then
        updatedSteps

    else
        focusStep logFocus updatedSteps


expandSteps : WebData Steps -> Steps -> Steps
expandSteps currentSteps incomingSteps =
    case currentSteps of
        RemoteData.Success steps ->
            List.map
                (\incomingStep ->
                    Util.overwriteById
                        { incomingStep
                            | viewing =
                                (viewingStep currentSteps <| String.fromInt incomingStep.number)
                                    || incomingStep.status
                                    /= Vela.Pending
                            , logFocus = stepLogFocus currentSteps <| String.fromInt incomingStep.number
                        }
                        steps
                )
                incomingSteps
                |> List.filterMap identity

        _ ->
            incomingSteps


{-| viewingStep : takes steps and step number and returns the step viewing state
-}
viewingStep : WebData Steps -> StepNumber -> Bool
viewingStep steps stepNumber =
    Maybe.withDefault False <|
        List.head <|
            List.map (\step -> step.viewing) <|
                List.filter (\step -> String.fromInt step.number == stepNumber) <|
                    RemoteData.withDefault [] steps


{-| stepLogFocus : takes steps and step number and returns the log focus for that step
-}
stepLogFocus : WebData Steps -> StepNumber -> ( Maybe Int, Maybe Int )
stepLogFocus steps stepNumber =
    Maybe.withDefault ( Nothing, Nothing ) <|
        List.head <|
            List.map (\step -> step.logFocus) <|
                List.filter (\step -> String.fromInt step.number == stepNumber) <|
                    RemoteData.withDefault [] steps


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


{-| getCurrentStep : takes steps and returns the newest running or pending step
-}
getCurrentStep : Steps -> Int
getCurrentStep steps =
    let
        step =
            steps
                |> List.filter (\s -> s.status == Vela.Pending || s.status == Vela.Running)
                |> List.map (\s -> s.number)
                |> List.sort
                |> List.head
                |> Maybe.withDefault 0
    in
    step


{-| latestTracker : takes steps and returns the focus id for the latest running or pending build
-}
latestTracker : Int -> String
latestTracker following =
    stepBottomTrackerFocusId <| String.fromInt following


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


{-| decodeLog : returns a string from a Maybe Log and decodes it from base64
-}
decodeLog : Maybe (WebData Log) -> String
decodeLog log =
    case decode <| toString log of
        Ok str ->
            str

        Err _ ->
            ""


{-| logEmpty : takes log string and returns True if content does not exist
-}
logEmpty : Maybe (WebData Log) -> Bool
logEmpty log =
    String.isEmpty <| String.replace " " "" <| decodeLog log


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
decodeAnsi : Maybe (WebData Log) -> Array.Array Ansi.Log.Line
decodeAnsi log =
    .lines <| Ansi.Log.update (decodeLog log) defaultLogModel
