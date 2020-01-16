{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Build exposing
    ( clickLogLine
    , clickStep
    , expandBuildLineFocus
    , lineFocusToFocusID
    , parseLineFocus
    , setLogLineFocus
    , statusToClass
    , statusToString
    , viewBuildHistory
    , viewBuildItem
    , viewFullBuild
    , viewRepositoryBuilds
    )

import Base64 exposing (decode)
import Browser.Navigation as Navigation
import DateFormat.Relative exposing (relativeTime)
import Html
    exposing
        ( Html
        , a
        , code
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , href
        , id
        )
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import List.Extra exposing (updateIf)
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (buildStatusToIcon, recentBuildStatusToIcon, stepStatusToIcon)
import Time exposing (Posix, Zone, millisToPosix)
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , Builds
        , BuildsModel
        , LineFocus
        , Log
        , Logs
        , Org
        , Repo
        , Status
        , Step
        , StepNumber
        , Steps
        )



-- TYPES


{-| ExpandStep : update action for expanding a build step
-}
type alias ExpandStep msg =
    Org -> Repo -> Maybe BuildNumber -> Maybe StepNumber -> msg


{-| LineFocus : update action for focusing a log line
-}
type alias SetLineFocus msg =
    StepNumber -> Maybe Int -> msg


{-| GetLogs : type alias for passing in logs fetch function from Main.elm
-}
type alias GetLogsFromBuild a msg =
    a -> Org -> Repo -> BuildNumber -> StepNumber -> LineFocus -> Cmd msg


type alias GetLogsFromSteps a msg =
    a -> Org -> Repo -> BuildNumber -> WebData Steps -> LineFocus -> Cmd msg



-- VIEW


{-| viewRepositoryBuilds : renders builds
-}
viewRepositoryBuilds : BuildsModel -> Posix -> String -> String -> Html msg
viewRepositoryBuilds buildsModel now org repo =
    let
        none =
            div []
                [ h1 []
                    [ text "No Builds Found"
                    ]
                , p []
                    [ text <|
                        "Builds sent to Vela will show up here."
                    ]
                ]
    in
    case buildsModel.builds of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <| List.map (viewBuildItem now org repo) builds

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            div [ Util.testAttribute "builds-error" ]
                [ p []
                    [ text <|
                        "There was an error fetching builds for this repository, please try again later!"
                    ]
                ]


{-| viewBuildItem : renders single build item preview based on current application time
-}
viewBuildItem : Posix -> Org -> Repo -> Build -> Html msg
viewBuildItem now org repo build =
    let
        status =
            [ buildStatusToIcon build.status ]

        commit =
            [ text "commit ", a [ href build.source ] [ text <| trimCommitHash build.commit ] ]

        branch =
            [ a [ href <| buildBranchUrl build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        id =
            [ a
                [ Util.testAttribute "build-number"
                , Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing
                ]
                [ text <| "#" ++ String.fromInt build.number ]
            ]

        age =
            [ text <| relativeTime now <| Time.millisToPosix <| Util.secondsToMillis build.created ]

        duration =
            [ text <| Util.formatRunTime now build.started build.finished ]

        statusClass =
            statusToClass build.status

        markdown =
            [ div [ class "status", Util.testAttribute "build-status", statusClass ] status
            , div [ class "info" ]
                [ div [ class "row" ]
                    [ div [ class "id" ] id
                    ]
                , div [ class "row" ]
                    [ div [ class "git-info" ]
                        [ div [ class "commit" ] commit
                        , text "on"
                        , div [ class "branch" ] branch
                        , text "by"
                        , div [ class "sender" ] sender
                        ]
                    , div [ class "time-info" ]
                        [ div [ class "age" ] age
                        , span [ class "delimiter" ] [ text "/" ]
                        , div [ class "duration" ] duration
                        ]
                    ]
                , buildError build
                ]
            ]
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ] <|
            buildStatusStyles markdown build.status build.number
        ]


{-| buildError : checks for build error and renders message
-}
buildError : Build -> Html msg
buildError build =
    case build.status of
        Vela.Error ->
            div [ class "row" ]
                [ div [ class "error", Util.testAttribute "build-error" ]
                    [ span [ class "label" ] [ text "error:" ]
                    , span [ class "message" ]
                        [ text <|
                            if String.isEmpty build.error then
                                "no error msg"

                            else
                                build.error
                        ]
                    ]
                ]

        _ ->
            text ""


{-| viewFullBuild : renders entire build based on current application time
-}
viewFullBuild : Posix -> Org -> Repo -> WebData Build -> WebData Steps -> Logs -> ExpandStep msg -> SetLineFocus msg -> Html msg
viewFullBuild now org repo build steps logs expandAction lineFocusAction =
    let
        ( buildPreview, buildNumber ) =
            case build of
                RemoteData.Success bld ->
                    ( viewBuildItem now org repo bld, Just <| String.fromInt bld.number )

                _ ->
                    ( Util.largeLoader, Nothing )

        buildSteps =
            case steps of
                RemoteData.Success steps_ ->
                    viewSteps now org repo buildNumber steps_ logs expandAction lineFocusAction

                RemoteData.Failure _ ->
                    div [] [ text "Error loading steps... Please try again" ]

                _ ->
                    -- Don't show two loaders
                    if Util.isLoading build then
                        text ""

                    else
                        Util.smallLoader

        markdown =
            [ buildPreview, buildSteps ]
    in
    div [ Util.testAttribute "full-build" ] markdown


{-| viewSteps : sorts and renders build steps
-}
viewSteps : Posix -> Org -> Repo -> Maybe BuildNumber -> Steps -> Logs -> ExpandStep msg -> SetLineFocus msg -> Html msg
viewSteps now org repo buildNumber steps logs expandAction lineFocusAction =
    div [ class "steps" ]
        [ div [ class "-items", Util.testAttribute "steps" ] <|
            List.map
                (\step ->
                    viewStep now org repo buildNumber step steps logs expandAction lineFocusAction
                )
            <|
                steps
        ]


{-| viewStep : renders single build step
-}
viewStep : Posix -> Org -> Repo -> Maybe BuildNumber -> Step -> Steps -> Logs -> ExpandStep msg -> SetLineFocus msg -> Html msg
viewStep now org repo buildNumber step steps logs expandAction lineFocusAction =
    div [ stepClasses step steps, Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStepIcon step ] ]
        , div [ classList [ ( "-view", True ), ( "-running", step.status == Vela.Running ) ] ]
            [ viewStepDetails now org repo buildNumber step logs expandAction lineFocusAction ]
        ]


{-| viewStepDetails : renders build steps detailed information
-}
viewStepDetails : Posix -> Org -> Repo -> Maybe BuildNumber -> Step -> Logs -> ExpandStep msg -> SetLineFocus msg -> Html msg
viewStepDetails now org repo buildNumber step logs expandAction lineFocusAction =
    let
        stepSummary =
            [ summary
                [ class "summary"
                , Util.testAttribute "step-header"
                , onClick (expandAction org repo buildNumber <| Just <| String.fromInt step.number)
                , id <| stepToFocusID <| String.fromInt step.number
                ]
                [ div
                    [ class "-info"
                    , onClick <| lineFocusAction (String.fromInt step.number) Nothing
                    ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime now step.started step.finished ]
                    ]
                ]
            , div [ class "logs-container" ] [ viewStepLogs step logs lineFocusAction ]
            ]
    in
    details [ class "details", Util.open step.viewing ] stepSummary


{-| viewStepLogs : takes step and logs and renders step logs or step error
-}
viewStepLogs : Step -> Logs -> SetLineFocus msg -> Html msg
viewStepLogs step logs clickAction =
    case step.status of
        Vela.Error ->
            stepError step

        _ ->
            viewLogs (String.fromInt step.number) step.lineFocus (getStepLog step logs) clickAction


{-| viewLogs : takes stepnumber linefocus log and clickaction and renders logs for a build step
-}
viewLogs : StepNumber -> Maybe Int -> Maybe (WebData Log) -> SetLineFocus msg -> Html msg
viewLogs stepNumber lineFocus log clickAction =
    let
        content =
            case Maybe.withDefault RemoteData.NotAsked log of
                RemoteData.Success _ ->
                    if logNotEmpty <| decodeLog log then
                        logLines stepNumber lineFocus log clickAction

                    else
                        code [] [ span [ class "no-logs" ] [ text "No logs for this step." ] ]

                RemoteData.Failure _ ->
                    code [ Util.testAttribute "logs-error" ] [ text "error" ]

                _ ->
                    div [ class "loading-logs" ] [ Util.smallLoaderWithText "loading logs..." ]
    in
    div [ class "logs", Util.testAttribute <| "logs-" ++ stepNumber ] [ content ]


{-| logLines : takes step number, line focus information and click action and renders logs
-}
logLines : StepNumber -> Maybe Int -> Maybe (WebData Log) -> SetLineFocus msg -> Html msg
logLines stepNumber lineFocus log clickAction =
    div [ class "lines" ] <|
        List.indexedMap
            (\idx -> \line -> logLine stepNumber line lineFocus (idx + 1) clickAction)
        <|
            decodeLogLine log


{-| logLine : takes step number, line focus information, and click action and renders a log line
-}
logLine : StepNumber -> String -> Maybe Int -> Int -> SetLineFocus msg -> Html msg
logLine stepNumber line lineFocus lineNumber clickAction =
    div [ class "line" ]
        [ span
            [ Util.testAttribute <| "log-line-" ++ String.fromInt lineNumber
            , class "wrapper"
            , lineFocusStyle lineFocus lineNumber
            ]
            [ span [ class "-line-num" ]
                [ a
                    [ logLineHref stepNumber lineNumber
                    , onClick <| clickAction stepNumber <| Just lineNumber
                    , Util.testAttribute <| "log-line-num-" ++ String.fromInt lineNumber
                    , id <| stepAndLineToFocusID stepNumber lineNumber
                    ]
                    [ text <| Util.toTwoDigits <| lineNumber ]
                ]
            , code [] [ text <| String.trim line ]
            ]
        ]


{-| decodeLogLine : takes maybe log and decodes it based on
-}
decodeLogLine : Maybe (WebData Log) -> List String
decodeLogLine log =
    List.filter (\line -> not <| String.isEmpty line) <|
        String.lines <|
            decodeLog log


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


{-| viewStepIcon : renders a build step status icon
-}
viewStepIcon : Step -> Html msg
viewStepIcon step =
    stepStatusToIcon step.status


{-| lineFocusStyle : takes maybe linefocus and linenumber and returns the appropriate style for highlighting a focused line
-}
lineFocusStyle : Maybe Int -> Int -> Html.Attribute msg
lineFocusStyle lineFocus lineNumber =
    case lineFocus of
        Just line ->
            if line == lineNumber then
                class "-focus"

            else
                class ""

        Nothing ->
            class ""


{-| viewBuildHistory : takes the 10 most recent builds and renders icons/links back to them as a widget at the top of the Build page
-}
viewBuildHistory : Posix -> Zone -> Page -> Org -> Repo -> WebData Builds -> Int -> Html msg
viewBuildHistory now timezone page org repo builds limit =
    let
        show =
            case page of
                Pages.Build _ _ _ _ ->
                    True

                _ ->
                    False
    in
    if show then
        case builds of
            RemoteData.Success blds ->
                if List.length blds > 0 then
                    div [ class "build-history", Util.testAttribute "build-history" ] <|
                        List.indexedMap (\idx -> \build -> recentBuild now timezone org repo build idx) <|
                            List.take limit blds

                else
                    text ""

            RemoteData.Loading ->
                div [ class "build-history" ] [ Util.smallLoader ]

            RemoteData.NotAsked ->
                div [ class "build-history" ] [ Util.smallLoader ]

            _ ->
                text ""

    else
        text ""


{-| recentBuild : takes recent build and renders status and link to build as a small icon widget
-}
recentBuild : Posix -> Zone -> Org -> Repo -> Build -> Int -> Html msg
recentBuild now timezone org repo build idx =
    let
        icon =
            recentBuildStatusToIcon build.status idx
    in
    a
        [ class "-build"
        , Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing
        , attribute "aria-label" <| "go to previous build number " ++ String.fromInt build.number
        ]
        [ icon
        , div [ class "-tooltip", Util.testAttribute "build-history-tooltip" ]
            [ div [ class "-info" ]
                [ div [ class "-line", class "-header" ]
                    [ span [ class "-number" ] [ text <| String.fromInt build.number ]
                    , span [ class "-event" ] [ text build.event ]
                    ]
                , div [ class "-line" ] [ span [ class "-label" ] [ text "started:" ], span [ class "-content" ] [ text <| Util.dateToHumanReadable timezone build.started ] ]
                , div [ class "-line" ] [ span [ class "-label" ] [ text "finished:" ], span [ class "-content" ] [ text <| Util.dateToHumanReadable timezone build.finished ] ]
                , div [ class "-line" ] [ span [ class "-label" ] [ text "duration:" ], span [ class "-content" ] [ text <| Util.formatRunTime now build.started build.finished ] ]
                ]
            ]
        ]



-- HELPERS


{-| statusToString : takes build status and returns string
-}
statusToString : Status -> String
statusToString status =
    case status of
        Vela.Pending ->
            "pending"

        Vela.Running ->
            "running"

        Vela.Success ->
            "success"

        Vela.Error ->
            "server error"

        Vela.Failure ->
            "failed"


{-| statusToClass : takes build status and returns css class
-}
statusToClass : Status -> Html.Attribute msg
statusToClass status =
    case status of
        Vela.Pending ->
            class "-pending"

        Vela.Running ->
            class "-running"

        Vela.Success ->
            class "-success"

        Vela.Failure ->
            class "-failure"

        Vela.Error ->
            class "-error"


{-| buildStatusStyles : takes build markdown and adds styled flair based on running status
-}
buildStatusStyles : List (Html msg) -> Status -> Int -> List (Html msg)
buildStatusStyles markdown buildStatus buildNumber =
    let
        animation =
            case buildStatus of
                Vela.Running ->
                    List.append (topParticles buildNumber) (bottomParticles buildNumber)

                _ ->
                    [ div [ class "build-animation", class "-not-running", statusToClass buildStatus ] []
                    ]
    in
    markdown ++ animation


{-| topParticles : returns an svg frame to parallax scroll on a running build, set to the top of the build
-}
topParticles : Int -> List (Html msg)
topParticles buildNumber =
    let
        -- Use the build number to dynamically set the dash particles, this way builds wont always have the same particle effects
        dashes =
            topBuildNumberDashes buildNumber

        y =
            "0%"
    in
    [ SvgBuilder.buildStatusAnimation "" y [ "-frame-0", "-top", "-cover" ]
    , SvgBuilder.buildStatusAnimation "none" y [ "-frame-0", "-top", "-start" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-1", "-top", "-running" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-2", "-top", "-running" ]
    ]


{-| bottomParticles : returns an svg frame to parallax scroll on a running build, set to the bottom of the build
-}
bottomParticles : Int -> List (Html msg)
bottomParticles buildNumber =
    let
        -- Use the build number to dynamically set the dash particles, this way builds wont always have the same particle effects
        dashes =
            bottomBuildNumberDashes buildNumber

        y =
            "100%"
    in
    [ SvgBuilder.buildStatusAnimation "" y [ "-frame-0", "-bottom", "-cover" ]
    , SvgBuilder.buildStatusAnimation "none" y [ "-frame-0", "-bottom", "-start" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-1", "-bottom", "-running" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-2", "-bottom", "-running" ]
    ]


{-| topBuildNumberDashes : returns a different particle effect based on a module of the build number
-}
topBuildNumberDashes : Int -> String
topBuildNumberDashes buildNumber =
    case modBy 3 buildNumber of
        1 ->
            "-animation-dashes-1"

        2 ->
            "-animation-dashes-2"

        _ ->
            "-animation-dashes-3"


{-| bottomBuildNumberDashes : returns a different particle effect based on a module of the build number
-}
bottomBuildNumberDashes : Int -> String
bottomBuildNumberDashes buildNumber =
    case modBy 3 buildNumber of
        1 ->
            "-animation-dashes-3"

        2 ->
            "-animation-dashes-1"

        _ ->
            "-animation-dashes-2"


{-| buildBranchUrl : drops '.git' off the clone url and concatenates tree + branch ref
-}
buildBranchUrl : String -> String -> String
buildBranchUrl clone branch =
    String.dropRight 4 clone ++ "/tree/" ++ branch


{-| trimCommitHash : takes the first 7 characters of the full commit hash
-}
trimCommitHash : String -> String
trimCommitHash commit =
    String.left 7 commit


{-| stepClasses : returns css classes for a particular step
-}
stepClasses : Step -> Steps -> Html.Attribute msg
stepClasses step steps =
    let
        last =
            case List.head <| List.reverse steps of
                Just s ->
                    s.number

                Nothing ->
                    -1
    in
    classList [ ( "step", True ), ( "-line", True ), ( "-last", last == step.number ) ]


{-| decodeLog : returns a string from a Maybe Log and decodes it from base64
-}
decodeLog : Maybe (WebData Log) -> String
decodeLog log =
    case decode <| toString log of
        Ok str ->
            str

        Err _ ->
            ""


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


{-| logNotEmpty : takes log string and returns True if content exists
-}
logNotEmpty : String -> Bool
logNotEmpty log =
    not << String.isEmpty <| String.replace " " "" log


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


{-| clickStep : takes model org repo and step number and fetches step information from the api
-}
clickStep : a -> WebData Steps -> Org -> Repo -> Maybe BuildNumber -> Maybe StepNumber -> GetLogsFromBuild a msg -> ( WebData Steps, Cmd msg )
clickStep model steps org repo buildNumber stepNumber getLogs =
    case stepNumber of
        Nothing ->
            ( steps
            , Cmd.none
            )

        Just stepNum ->
            let
                ( stepsOut, action ) =
                    case steps of
                        RemoteData.Success steps_ ->
                            ( RemoteData.succeed <| toggleStepView steps_ stepNum
                            , case buildNumber of
                                Just buildNum ->
                                    getLogs model org repo buildNum stepNum Nothing

                                Nothing ->
                                    Cmd.none
                            )

                        _ ->
                            ( steps, Cmd.none )
            in
            ( stepsOut
            , action
            )


{-| toggleStepView : takes steps and step number and toggles that steps viewing state
-}
toggleStepView : Steps -> String -> Steps
toggleStepView steps stepNumber =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = not step.viewing })
        steps


{-| clickLogLine : takes model and line number and sets the focus on the log line
-}
clickLogLine : WebData Steps -> Navigation.Key -> Org -> Repo -> BuildNumber -> StepNumber -> Maybe Int -> ( WebData Steps, Cmd msg )
clickLogLine steps navKey org repo buildNumber stepNumber lineNumber =
    ( steps
    , Navigation.replaceUrl navKey <|
        Routes.routeToUrl
            (Routes.Build org repo buildNumber <|
                Just <|
                    "#step:"
                        ++ stepNumber
                        ++ (case lineNumber of
                                Just line ->
                                    ":"
                                        ++ String.fromInt line

                                Nothing ->
                                    ""
                           )
            )
    )


{-| setLogLineFocus : takes model org, repo, build number and log line fragment and loads the appropriate build with focus set on the appropriate log line.
-}
setLogLineFocus : a -> WebData Steps -> Org -> Repo -> BuildNumber -> LineFocus -> GetLogsFromSteps a msg -> ( Page, WebData Steps, Cmd msg )
setLogLineFocus model steps org repo buildNumber lineFocus getLogs =
    let
        ( stepsOut, action ) =
            case steps of
                RemoteData.Success steps_ ->
                    let
                        focusedSteps =
                            RemoteData.succeed <| setLineFocus steps_ lineFocus
                    in
                    ( focusedSteps
                    , Cmd.batch
                        [ getLogs model org repo buildNumber focusedSteps lineFocus
                        ]
                    )

                _ ->
                    ( steps
                    , Cmd.none
                    )
    in
    ( Pages.Build org repo buildNumber lineFocus
    , stepsOut
    , action
    )


{-| setLineFocus : takes steps and line focus and sets a new log line focus
-}
setLineFocus : Steps -> LineFocus -> Steps
setLineFocus steps lineFocus =
    let
        ( target, stepNumber, lineNumber ) =
            parseLineFocus lineFocus
    in
    case Maybe.withDefault "" target of
        "step" ->
            case stepNumber of
                Just n ->
                    updateIf (\step -> step.number == n) (\step -> { step | viewing = True, lineFocus = lineNumber }) <| clearLineFocus steps

                Nothing ->
                    steps

        _ ->
            steps


{-| clearLineFocus : takes steps and clears all log line focus
-}
clearLineFocus : Steps -> Steps
clearLineFocus steps =
    List.map (\step -> { step | lineFocus = Nothing }) steps


{-| expandBuildLineFocus : takes LineFocus URL fragment and expands the appropriate step to automatically view
-}
expandBuildLineFocus : LineFocus -> Steps -> Steps
expandBuildLineFocus lineFocus steps =
    let
        ( target, number, line ) =
            parseLineFocus lineFocus
    in
    case Maybe.withDefault "" target of
        "step" ->
            case number of
                Just n ->
                    updateIf (\step -> step.number == n) (\step -> { step | viewing = True, lineFocus = line }) steps

                Nothing ->
                    steps

        _ ->
            steps


{-| parseLineFocus : takes URL fragment and parses it into appropriate line focus chunks
-}
parseLineFocus : LineFocus -> ( Maybe String, Maybe Int, Maybe Int )
parseLineFocus lineFocus =
    case String.split ":" (Maybe.withDefault "" lineFocus) of
        target :: step :: line :: _ ->
            ( Just target, String.toInt step, String.toInt line )

        target :: step :: _ ->
            ( Just target, String.toInt step, Nothing )

        _ ->
            ( Nothing, Nothing, Nothing )


{-| lineFocusToFocusID : takes URL fragment and parses it into appropriate line focus ID for auto focusing on page load
-}
lineFocusToFocusID : LineFocus -> String
lineFocusToFocusID lineFocus =
    let
        parsed =
            parseLineFocus lineFocus
    in
    case parsed of
        ( _, Just step, Just line ) ->
            "step-" ++ String.fromInt step ++ "-line-" ++ String.fromInt line

        ( _, Just step, Nothing ) ->
            "step-" ++ String.fromInt step

        _ ->
            ""


{-| stepToFocusID : takes URL fragment and parses it into appropriate step focus ID for auto focusing on page load
-}
stepToFocusID : StepNumber -> String
stepToFocusID stepNumber =
    "step-" ++ stepNumber


{-| stepAndLineToFocusID : takes URL fragment and parses it into appropriate line focus ID for auto focusing on page load
-}
stepAndLineToFocusID : StepNumber -> Int -> String
stepAndLineToFocusID stepNumber lineNumber =
    "step-" ++ stepNumber ++ "-line-" ++ String.fromInt lineNumber


{-| logLineHref : takes stepnumber and line number and renders the link href for clicking a log line without redirecting
-}
logLineHref : StepNumber -> Int -> Html.Attribute msg
logLineHref stepNumber lineNumber =
    href <| "#step:" ++ stepNumber ++ ":" ++ (String.fromInt <| lineNumber)


{-| stepHref : takes stepnumber and renders the link href for clicking a log line without redirecting
-}
stepHref : StepNumber -> Html.Attribute msg
stepHref stepNumber =
    href <| "#step:" ++ stepNumber
