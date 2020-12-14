{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.View exposing
    ( buildStatusStyles
    , statusToClass
    , statusToString
    , viewBuild
    , viewBuildSteps
    , viewError
    , viewLine
    , viewPreview
    , wrapWithBuildPreview
    )

import Ansi.Log
import Array
import DateFormat.Relative exposing (relativeTime)
import FeatherIcons
import Focus
    exposing
        ( Resource
        , ResourceID
        , lineFocusStyles
        , lineRangeId
        , resourceAndLineToFocusId
        , resourceToFocusId
        )
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , details
        , div
        , em
        , li
        , p
        , small
        , span
        , strong
        , summary
        , table
        , td
        , text
        , tr
        , ul
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , href
        , id
        , title
        )
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import List.Extra exposing (unique)
import Nav exposing (viewBuildNav)
import Pages exposing (Page(..), onPage)
import Pages.Build.Logs
    exposing
        ( decodeAnsi
        , getDownloadLogsFileName
        , getStepLog
        , logEmpty
        , stepBottomTrackerFocusId
        , stepTopTrackerFocusId
        , toString
        )
import Pages.Build.Model exposing (..)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import String
import SvgBuilder exposing (buildStatusToIcon, stepStatusToIcon)
import Time exposing (Posix, Zone, millisToPosix)
import Util
import Vela
    exposing
        ( Build
        , BuildModel
        , BuildNumber
        , Builds
        , Log
        , LogFocus
        , Logs
        , Org
        , Repo
        , RepoModel
        , Status
        , Step
        , StepNumber
        , Steps
        , defaultStep
        )



-- VIEW


{-| viewBuild : renders entire build based on current application time
-}
viewBuild : PartialModel a -> Msgs msg -> Org -> Repo -> Html msg
viewBuild model msgs org repo =
    wrapWithBuildPreview model org repo <|
        case model.repo.build.steps of
            RemoteData.Success steps_ ->
                viewBuildSteps model
                    msgs
                    model.repo
                    steps_

            RemoteData.Failure _ ->
                div [] [ text "Error loading steps... Please try again" ]

            _ ->
                -- Don't show two loaders
                if Util.isLoading model.repo.build.build then
                    text ""

                else
                    Util.smallLoader


{-| wrapWithBuildPreview : takes html content and wraps it with the build preview
-}
wrapWithBuildPreview : PartialModel a  -> Org -> Repo -> Html msg -> Html msg
wrapWithBuildPreview model   org repo content =
    let
        rm =
            model.repo

        build =
            rm.build

        ( buildPreview, buildNumber ) =
            case build.build of
                RemoteData.Success bld ->
                    ( viewPreview model.time model.zone org repo bld, String.fromInt bld.number )

                RemoteData.Loading ->
                    ( Util.largeLoader, "" )

                _ ->
                    ( text "", "" )

        navTabs =
            case build.build of
                RemoteData.Success bld ->
                    viewBuildNav model org repo bld model.page

                RemoteData.Loading ->
                    Util.largeLoader

                _ ->
                    text ""

        markdown =
            [ buildPreview
            , navTabs
            , content
            ]
    in
    div [ Util.testAttribute "full-build" ] markdown


{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Posix -> Zone -> Org -> Repo -> Build -> Html msg
viewPreview now zone org repo build =
    let
        buildNumber =
            String.fromInt build.number

        status =
            [ buildStatusToIcon build.status ]

        commit =
            [ text <| String.replace "_" " " build.event
            , text " ("
            , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
            , text <| ")"
            ]

        branch =
            [ a [ href <| Util.buildBranchUrl build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        message =
            [ text <| "- " ++ build.message ]

        id =
            [ a
                [ Util.testAttribute "build-number"
                , Routes.href <| Routes.Build org repo buildNumber Nothing Nothing
                ]
                [ text <| "#" ++ buildNumber ]
            ]

        age =
            [ text <| relativeTime now <| Time.millisToPosix <| Util.secondsToMillis build.created ]

        buildCreatedPosix =
            Time.millisToPosix <| Util.secondsToMillis build.created

        timestamp =
            Util.humanReadableDateTimeFormatter zone buildCreatedPosix

        duration =
            [ text <| Util.formatRunTime now build.started build.finished ]

        statusClass =
            statusToClass build.status

        markdown =
            [ div [ class "status", Util.testAttribute "build-status", statusClass ] status
            , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] id
                    , div [ class "commit-msg" ] [ strong [] message ]
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
                        [ div
                            [ class "age"
                            , title timestamp
                            ]
                            age
                        , span [ class "delimiter" ] [ text "/" ]
                        , div [ class "duration" ] duration
                        ]
                    ]
                , div [ class "row" ]
                    [ viewError build
                    ]
                ]
            ]
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ] <|
            buildStatusStyles markdown build.status build.number
        ]


{-| viewBuildSteps : takes build/steps and renders pipeline
-}
viewBuildSteps : PartialModel a -> Msgs msg -> RepoModel -> Steps -> Html msg
viewBuildSteps model msgs rm steps =
    let
        logActions =
            div
                [ class "buttons"
                , class "log-actions"
                , class "flowline-left"
                , Util.testAttribute "log-actions"
                ]
                [ collapseAllStepsButton msgs.collapseAllSteps
                , expandAllStepsButton msgs.expandAllSteps rm.org rm.name rm.build.buildNumber
                ]
    in
    div []
        [ logActions
        , div [ class "steps" ]
            [ div [ class "-items", Util.testAttribute "steps" ] <|
                if hasStages steps then
                    viewStages model msgs rm steps

                else
                    viewSteps model msgs rm steps
            ]
        ]


{-| viewSteps : takes build/steps and renders steps
-}
viewSteps : PartialModel a -> Msgs msg -> RepoModel -> Steps -> List (Html msg)
viewSteps model msgs rm steps =
    List.map (\step -> viewStep model msgs rm steps step) <| steps


{-| viewStep : renders single build step
-}
viewStep : PartialModel a -> Msgs msg -> RepoModel -> Steps -> Step -> Html msg
viewStep model msgs rm steps step =
    div [ stepClasses steps step, Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStepIcon step ] ]
        , viewStepDetails model msgs rm step
        ]


{-| viewStepDetails : renders build steps detailed information
-}
viewStepDetails : PartialModel a -> Msgs msg -> RepoModel -> Step -> Html msg
viewStepDetails model msgs rm step =
    let
        stepNumber =
            String.fromInt step.number

        stepSummary =
            [ summary
                [ class "summary"
                , Util.testAttribute <| "step-header-" ++ stepNumber
                , onClick <| msgs.expandStep rm.org rm.name rm.build.buildNumber stepNumber
                , id <| resourceToFocusId "step" stepNumber
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime model.time step.started step.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                ]
            , div [ class "logs-container" ] [ viewLogs msgs.logsMsgs model rm step ]
            ]
    in
    details
        (classList
            [ ( "details", True )
            , ( "-with-border", True )
            , ( "-running", step.status == Vela.Running )
            ]
            :: Util.open step.viewing
        )
        stepSummary


{-| viewStages : takes model and build model and renders steps grouped by stages
-}
viewStages : PartialModel a -> Msgs msg -> RepoModel -> Steps -> List (Html msg)
viewStages model msgs rm steps =
    steps
        |> List.map .stage
        |> unique
        |> List.map
            (\stage ->
                steps
                    |> List.filter (\step -> step.stage == stage)
                    |> viewStage model msgs rm stage
            )


{-| viewStage : takes model, build model and stage and renders the stage steps
-}
viewStage : PartialModel a -> Msgs msg -> RepoModel -> String -> Steps -> Html msg
viewStage model msgs rm stage steps =
    div
        [ class "stage", Util.testAttribute <| "stage" ]
        [ viewStageDivider model stage
        , steps
            |> List.map (\step -> viewStep model msgs rm steps step)
            |> div [ Util.testAttribute <| "stage-" ++ stage ]
        ]


{-| viewStageDivider : renders divider between stage
-}
viewStageDivider : PartialModel a -> String -> Html msg
viewStageDivider model stage =
    if stage /= "init" && stage /= "clone" then
        div [ class "divider", Util.testAttribute <| "stage-divider-" ++ stage ]
            [ div [] [ text stage ] ]

    else
        text ""


{-| hasStages : takes steps and returns true if the pipeline contain stages
-}
hasStages : Steps -> Bool
hasStages steps =
    steps
        |> List.filter (\s -> s.stage /= "")
        |> List.head
        |> Maybe.withDefault defaultStep
        |> (\step -> step.stage /= "")


{-| viewLogs : takes step and logs and renders step logs or step error
-}
viewLogs : LogsMsgs msg -> PartialModel a -> RepoModel -> Step -> Html msg
viewLogs msgs model rm step =
    case step.status of
        Vela.Error ->
            stepError step

        Vela.Killed ->
            stepSkipped step

        _ ->
            viewLogLines msgs rm.org rm.name rm.build.buildNumber (String.fromInt step.number) step.logFocus (getStepLog step rm.build.logs) rm.build.followingStep model.shift


{-| viewLogLines : takes stepnumber linefocus log and clickAction shiftDown and renders logs for a build step
-}
viewLogLines : LogsMsgs msg -> Org -> Repo -> BuildNumber -> StepNumber -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html msg
viewLogLines msgs org repo buildNumber stepNumber logFocus maybeLog following shiftDown =
    let
        decodedLog =
            toString maybeLog

        fileName =
            getDownloadLogsFileName org repo buildNumber "step" stepNumber
    in
    div
        [ class "logs"
        , Util.testAttribute <| "logs-" ++ stepNumber
        ]
    <|
        case Maybe.withDefault RemoteData.NotAsked maybeLog of
            RemoteData.Success _ ->
                if logEmpty decodedLog then
                    [ emptyLogs ]

                else
                    let
                        ( logs, numLines ) =
                            viewLines msgs.focusLine stepNumber logFocus decodedLog shiftDown
                    in
                    [ logsHeader msgs stepNumber fileName decodedLog
                    , logsSidebar msgs stepNumber following numLines
                    , logs
                    ]

            RemoteData.Failure err ->
                [ code [ Util.testAttribute "logs-error" ] [ text "error fetching logs" ] ]

            _ ->
                [ loadingLogs ]


{-| viewLines : takes step number, line focus information and click action and renders logs
-}
viewLines : FocusLine msg -> StepNumber -> LogFocus -> String -> Bool -> ( Html msg, Int )
viewLines focusLine stepNumber logFocus decodedLog shiftDown =
    let
        lines =
            if not <| logEmpty decodedLog then
                decodedLog
                    |> decodeAnsi
                    |> Array.indexedMap
                        (\idx line ->
                            Just <|
                                viewLine focusLine
                                    stepNumber
                                    (idx + 1)
                                    (Just line)
                                    stepNumber
                                    logFocus
                                    shiftDown
                        )
                    |> Array.toList

            else
                [ Just <|
                    viewLine focusLine
                        stepNumber
                        1
                        Nothing
                        stepNumber
                        logFocus
                        shiftDown
                ]

        -- update resource filename when adding stages/services
        logs =
            lines
                |> List.filterMap identity

        topTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <|
                        stepTopTrackerFocusId stepNumber
                    , Util.testAttribute <| "top-log-tracker-" ++ stepNumber
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <|
                        stepBottomTrackerFocusId stepNumber
                    , Util.testAttribute <| "bottom-log-tracker-" ++ stepNumber
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]
    in
    ( table [ class "logs-table", class "scrollable" ] <|
        topTracker
            :: logs
            ++ [ bottomTracker ]
    , List.length lines
    )


{-| viewLine : takes log line and focus information and renders line number button and log
-}
viewLine : FocusLine msg -> ResourceID -> Int -> Maybe Ansi.Log.Line -> Resource -> LogFocus -> Bool -> Html msg
viewLine focusLine id lineNumber line resource logFocus shiftDown =
    tr
        [ Html.Attributes.id <|
            id
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ case line of
            Just l ->
                div
                    [ class "wrapper"
                    , Util.testAttribute <| String.join "-" [ "log", "line", resource, String.fromInt lineNumber ]
                    , class <| lineFocusStyles logFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton focusLine resource logFocus lineNumber shiftDown ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "log", "data", resource, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]


{-| lineFocusButton : renders button for focusing log line ranges
-}
lineFocusButton : (String -> msg) -> StepNumber -> LogFocus -> Int -> Bool -> Html msg
lineFocusButton focusLogs stepNumber logFocus lineNumber shiftDown =
    button
        [ Util.onClickPreventDefault <|
            focusLogs <|
                lineRangeId "step" stepNumber lineNumber logFocus shiftDown
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", stepNumber, String.fromInt lineNumber ]
        , id <| resourceAndLineToFocusId "step" stepNumber lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus step " ++ stepNumber
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]


{-| collapseAllStepsButton : renders a button for collapsing all steps
-}
collapseAllStepsButton : msg -> Html msg
collapseAllStepsButton collapseAllSteps =
    Html.button
        [ class "button"
        , class "-link"
        , onClick collapseAllSteps
        , Util.testAttribute "collapse-all"
        ]
        [ small [] [ text "collapse all" ] ]


{-| expandAllStepsButton : renders a button for expanding all steps
-}
expandAllStepsButton : ExpandAllSteps msg -> Org -> Repo -> BuildNumber -> Html msg
expandAllStepsButton expandAllSteps org repo buildNumber =
    Html.button
        [ class "button"
        , class "-link"
        , onClick <| expandAllSteps org repo buildNumber
        , Util.testAttribute "expand-all"
        ]
        [ small [] [ text "expand all" ] ]


{-| logsHeader : takes step number, filename and decoded log and renders logs header
-}
logsHeader : LogsMsgs msg -> StepNumber -> String -> String -> Html msg
logsHeader msgs stepNumber fileName decodedLog =
    div [ class "logs-header", class "buttons", Util.testAttribute <| "logs-header-actions-" ++ stepNumber ]
        [ downloadStepLogsButton msgs.download stepNumber fileName decodedLog ]


{-| logsSidebar : takes step number/following and renders the logs sidebar
-}
logsSidebar : LogsMsgs msg -> StepNumber -> Int -> Int -> Html msg
logsSidebar msgs stepNumber following numSteps =
    let
        long =
            numSteps > 25
    in
    div [ class "logs-sidebar" ]
        [ div [ class "inner-container" ]
            [ div
                [ class "actions"
                , Util.testAttribute <| "logs-sidebar-actions-" ++ stepNumber
                ]
              <|
                (if long then
                    [ jumpToTopButton msgs.focusOn stepNumber
                    , jumpToBottomButton msgs.focusOn stepNumber
                    ]

                 else
                    []
                )
                    ++ [ stepFollowButton msgs.followStep stepNumber following ]
            ]
        ]


{-| jumpToBottomButton : renders action button for jumping to the bottom of a step log
-}
jumpToBottomButton : FocusOn msg -> StepNumber -> Html msg
jumpToBottomButton focusOn stepNumber =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to bottom"
        , Util.testAttribute <| "jump-to-bottom-" ++ stepNumber
        , onClick <| focusOn <| stepBottomTrackerFocusId stepNumber
        , attribute "aria-label" <| "jump to bottom of logs for step " ++ stepNumber
        ]
        [ FeatherIcons.arrowDown |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| jumpToTopButton : renders action button for jumping to the top of a step log
-}
jumpToTopButton : FocusOn msg -> StepNumber -> Html msg
jumpToTopButton focusOn stepNumber =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to top"
        , Util.testAttribute <| "jump-to-top-" ++ stepNumber
        , onClick <| focusOn <| stepTopTrackerFocusId stepNumber
        , attribute "aria-label" <| "jump to top of logs for step " ++ stepNumber
        ]
        [ FeatherIcons.arrowUp |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| downloadStepLogsButton : renders action button for downloading a step log
-}
downloadStepLogsButton : Download msg -> String -> String -> String -> Html msg
downloadStepLogsButton download stepNumber fileName logs =
    button
        [ class "button"
        , class "-link"
        , Util.testAttribute <| "download-logs-" ++ stepNumber
        , onClick <| download fileName logs
        , attribute "aria-label" <| "download logs for step " ++ stepNumber
        ]
        [ text "download step logs" ]


{-| stepFollowButton : renders button for following step logs
-}
stepFollowButton : FollowStep msg -> StepNumber -> Int -> Html msg
stepFollowButton followStep stepNumber following =
    let
        stepNum =
            Maybe.withDefault 0 <| String.toInt stepNumber

        ( tooltip, icon, toFollow ) =
            if following == 0 then
                ( "start following step logs", FeatherIcons.play, stepNum )

            else if following == (Maybe.withDefault 0 <| String.toInt stepNumber) then
                ( "stop following step logs", FeatherIcons.pause, 0 )

            else
                ( "start following step logs", FeatherIcons.play, stepNum )
    in
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , Util.testAttribute <| "follow-logs-" ++ stepNumber
        , onClick <| followStep toFollow
        , attribute "aria-label" <| tooltip ++ " for step " ++ stepNumber
        ]
        [ icon |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| stepError : checks for build error and renders message
-}
stepError : Step -> Html msg
stepError step =
    div [ class "message", class "error", Util.testAttribute "step-error" ]
        [ span [] [ text "error:" ]
        , text <|
            if String.isEmpty step.error then
                "null"

            else
                step.error
        ]


{-| loadingLogs : renders message for loading logs
-}
loadingLogs : Html msg
loadingLogs =
    div [ class "message" ]
        [ Util.smallLoaderWithText "loading..." ]


{-| emptyLogs : renders message for empty logs
-}
emptyLogs : Html msg
emptyLogs =
    div [ class "message" ]
        [ text "the build has not written logs to this step yet" ]


{-| stepKilled : renders message for a killed step

    NOTE: not used, but keeping around for future

-}
stepKilled : Step -> Html msg
stepKilled _ =
    div [ class "message", class "error", Util.testAttribute "step-error" ]
        [ text "step was killed" ]


{-| stepSkipped : renders message for a skipped step
-}
stepSkipped : Step -> Html msg
stepSkipped _ =
    div [ class "message", class "error", Util.testAttribute "step-skipped" ]
        [ text "step was skipped" ]


{-| viewStepIcon : renders a build step status icon
-}
viewStepIcon : Step -> Html msg
viewStepIcon step =
    stepStatusToIcon step.status


{-| viewError : checks for build error and renders message
-}
viewError : Build -> Html msg
viewError build =
    case build.status of
        Vela.Error ->
            div [ class "error", Util.testAttribute "build-error" ]
                [ span [ class "label" ] [ text "error:" ]
                , span [ class "message" ]
                    [ text <|
                        if String.isEmpty build.error then
                            "no error msg"

                        else
                            build.error
                    ]
                ]

        _ ->
            div [] []



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

        Vela.Failure ->
            "failed"

        Vela.Killed ->
            "killed"

        Vela.Error ->
            "server error"


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

        Vela.Killed ->
            class "-failure"

        Vela.Error ->
            class "-error"


{-| stepClasses : returns css classes for a particular step
-}
stepClasses : Steps -> Step -> Html.Attribute msg
stepClasses steps step =
    let
        last =
            case List.head <| List.reverse steps of
                Just s ->
                    s.number

                Nothing ->
                    -1
    in
    classList [ ( "step", True ), ( "flowline-left", True ) ]


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
