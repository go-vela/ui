{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Logs exposing
    ( SetLogFocus
    , decodeAnsi
    , focusService
    , focusServiceLogs
    , focusStep
    , focusStepLogs
    , getCurrentResource
    , getDownloadLogsFileName
    , getServiceLog
    , getStepLog
    , logEmpty
    , logFocusExists
    , stepBottomTrackerFocusId
    , stepTopTrackerFocusId
    , toString
    )

import Ansi.Log
import Array
import Focus exposing (parseFocusFragment, resourceFocusFragment)
import List.Extra exposing (updateIf)
import Pages exposing (Page)
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
        , Service
        , Services
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


type alias GetLogsFromServices a msg =
    a -> Org -> Repo -> BuildNumber -> Services -> FocusFragment -> Bool -> Cmd msg



-- HELPERS


{-| getServiceLog : takes step and logs and returns the log corresponding to that step
-}
getServiceLog : Service -> Logs -> Maybe (WebData Log)
getServiceLog service logs =
    List.head
        (List.filter
            (\log ->
                case log of
                    RemoteData.Success log_ ->
                        log_.service_id == service.id

                    _ ->
                        False
            )
            logs
        )


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
            case parsed.resourceID of
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


{-| focusService : takes FocusFragment URL fragment and expands the appropriate step to automatically view
-}
focusService : FocusFragment -> Services -> Services
focusService focusFragment services =
    let
        parsed =
            parseFocusFragment focusFragment
    in
    case Maybe.withDefault "" parsed.target of
        "service" ->
            case parsed.resourceID of
                Just n ->
                    updateIf (\service -> service.number == n)
                        (\service ->
                            { service | viewing = True, logFocus = ( parsed.lineA, parsed.lineB ) }
                        )
                        services

                Nothing ->
                    services

        _ ->
            services


{-| getCurrentResource : takes steps and returns the newest running or pending step
-}
getCurrentResource : List { a | status : Vela.Status, number : Int } -> Int
getCurrentResource resources =
    let
        resource =
            resources
                |> List.filter (\s -> s.status == Vela.Pending || s.status == Vela.Running)
                |> List.map .number
                |> List.sort
                |> List.head
                |> Maybe.withDefault 0
    in
    resource


{-| focusStepLogs : takes model org, repo, build number and log line fragment and loads the appropriate build with focus set on the appropriate log line.
-}
focusStepLogs : a -> Steps -> Org -> Repo -> BuildNumber -> FocusFragment -> GetLogsFromSteps a msg -> ( Steps, Cmd msg )
focusStepLogs model steps org repo buildNumber focusFragment getLogs =
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
    ( stepsOut
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
            ( parsed.target, parsed.resourceID )
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


{-| clearStepLogFocus : takes step and clears all log line focus
-}
clearStepLogFocus : Step -> Step
clearStepLogFocus step =
    { step | logFocus = ( Nothing, Nothing ) }


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



-- SERVICES


{-| focusServiceLogs : takes model org, repo, build number and log line fragment and loads the appropriate build with focus set on the appropriate log line.
-}
focusServiceLogs : a -> Services -> Org -> Repo -> BuildNumber -> FocusFragment -> GetLogsFromServices a msg -> ( Services, Cmd msg )
focusServiceLogs model services org repo buildNumber focusFragment getLogs =
    let
        ( servicesOut, action ) =
            let
                focusedServices =
                    updateServiceLogFocus services focusFragment
            in
            ( focusedServices
            , Cmd.batch
                [ getLogs model org repo buildNumber focusedServices focusFragment False
                ]
            )
    in
    ( servicesOut
    , action
    )


{-| updateServiceLogFocus : takes services and line focus and sets a new log line focus
-}
updateServiceLogFocus : Services -> FocusFragment -> Services
updateServiceLogFocus services focusFragment =
    let
        parsed =
            parseFocusFragment focusFragment

        ( target, serviceNumber ) =
            ( parsed.target, parsed.resourceID )
    in
    case Maybe.withDefault "" target of
        "service" ->
            case serviceNumber of
                Just n ->
                    List.map
                        (\service ->
                            if service.number == n then
                                { service | viewing = True, logFocus = ( parsed.lineA, parsed.lineB ) }

                            else
                                clearServiceLogFocus service
                        )
                    <|
                        services

                Nothing ->
                    services

        _ ->
            services


{-| clearServiceLogFocus : takes service and clears all log line focus
-}
clearServiceLogFocus : Service -> Service
clearServiceLogFocus service =
    { service | logFocus = ( Nothing, Nothing ) }
