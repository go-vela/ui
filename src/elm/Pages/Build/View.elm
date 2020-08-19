{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.View exposing
    ( statusToClass
    , statusToString
    , viewBuild
    , viewBuildHistory
    , viewPreview
    )

import Ansi.Log
import Array
import DateFormat.Relative exposing (relativeTime)
import FeatherIcons
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
        )
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Pages exposing (Page(..))
import Pages.Build.Logs
    exposing
        ( decodeAnsi
        , decodeLog
        , getStepLog
        , logEmpty
        , logFocusStyles
        , logRangeId
        , stepAndLineToFocusId
        , stepBottomTrackerFocusId
        , stepLogsFilename
        , stepToFocusId
        , stepTopTrackerFocusId
        )
import Pages.Build.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import String
import SvgBuilder exposing (buildStatusToIcon, recentBuildStatusToIcon, stepStatusToIcon)
import Time exposing (Posix, Zone, millisToPosix)
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , Builds
        , Log
        , LogFocus
        , Logs
        , Org
        , Repo
        , Status
        , Step
        , StepNumber
        , Steps
        )



-- VIEW


{-| viewBuild : renders entire build based on current application time
-}
viewBuild : PartialModel a -> Org -> Repo -> Html Msg
viewBuild { time, build, steps, logs, followingStep, autoExpandSteps, shift } org repo =
    let
        ( buildPreview, buildNumber ) =
            case build of
                RemoteData.Success bld ->
                    ( viewPreview time org repo (Just autoExpandSteps) bld, String.fromInt bld.number )

                RemoteData.Loading ->
                    ( Util.largeLoader, "" )

                _ ->
                    ( text "", "" )

        buildSteps =
            case steps of
                RemoteData.Success steps_ ->
                    viewSteps time org repo buildNumber steps_ logs followingStep shift

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


{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Posix -> Org -> Repo -> Maybe Bool -> Build -> Html Msg
viewPreview now org repo expanding build =
    let
        buildNumber =
            String.fromInt build.number

        status =
            [ buildStatusToIcon build.status ]

        commit =
            [ text <| String.replace "_" " " build.event
            , text " ("
            , a [ href build.source ] [ text <| trimCommitHash build.commit ]
            , text <| ")"
            ]

        branch =
            [ a [ href <| buildBranchUrl build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        message =
            [ text <| "- " ++ build.message ]

        id =
            [ a
                [ Util.testAttribute "build-number"
                , Routes.href <| Routes.Build org repo buildNumber Nothing
                ]
                [ text <| "#" ++ buildNumber ]
            ]

        age =
            [ text <| relativeTime now <| Time.millisToPosix <| Util.secondsToMillis build.created ]

        duration =
            [ text <| Util.formatRunTime now build.started build.finished ]

        statusClass =
            statusToClass build.status

        logActions =
            case expanding of
                Just e ->
                    [ collapseAllStepsButton
                    , expandAllStepsButton org repo buildNumber
                    , autoExpandStepsButton org repo buildNumber e
                    ]

                Nothing ->
                    [ text "" ]

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
                        [ div [ class "age" ] age
                        , span [ class "delimiter" ] [ text "/" ]
                        , div [ class "duration" ] duration
                        ]
                    ]
                , div [ class "row", class "" ]
                    [ viewError build
                    , div
                        [ class "buttons"
                        , class "log-actions"
                        , Util.testAttribute <| "log-actions-" ++ buildNumber
                        ]
                        logActions
                    ]
                ]
            ]
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ] <|
            buildStatusStyles markdown build.status build.number
        ]


{-| viewSteps : sorts and renders build steps
-}
viewSteps : Posix -> Org -> Repo -> BuildNumber -> Steps -> Logs -> Int -> Bool -> Html Msg
viewSteps now org repo buildNumber steps logs follow shift =
    div [ class "steps" ]
        [ div [ class "-items", Util.testAttribute "steps" ] <|
            List.map
                (\step ->
                    viewStep now org repo buildNumber step steps logs follow shift
                )
            <|
                steps
        ]


{-| viewStep : renders single build step
-}
viewStep : Posix -> Org -> Repo -> BuildNumber -> Step -> Steps -> Logs -> Int -> Bool -> Html Msg
viewStep now org repo buildNumber step steps logs follow shift =
    div [ stepClasses step steps, Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStepIcon step ] ]
        , viewStepDetails now org repo buildNumber step logs follow shift
        ]


{-| viewStepDetails : renders build steps detailed information
-}
viewStepDetails : Posix -> Org -> Repo -> BuildNumber -> Step -> Logs -> Int -> Bool -> Html Msg
viewStepDetails now org repo buildNumber step logs follow shift =
    let
        stepNumber =
            String.fromInt step.number

        stepSummary =
            [ summary
                [ class "summary"
                , Util.testAttribute <| "step-header-" ++ stepNumber
                , onClick <| ExpandStep org repo buildNumber stepNumber
                , id <| stepToFocusId stepNumber
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime now step.started step.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                ]
            , div [ class "logs-container" ] [ viewLogs org repo buildNumber step logs follow shift ]
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


{-| viewLogs : takes step and logs and renders step logs or step error
-}
viewLogs : Org -> Repo -> BuildNumber -> Step -> Logs -> Int -> Bool -> Html Msg
viewLogs org repo buildNumber step logs follow shiftDown =
    case step.status of
        Vela.Error ->
            stepError step

        Vela.Killed ->
            stepSkipped step

        _ ->
            viewLogLines org repo buildNumber (String.fromInt step.number) step.logFocus (getStepLog step logs) follow shiftDown


{-| viewLogLines : takes stepnumber linefocus log and clickAction shiftDown and renders logs for a build step
-}
viewLogLines : Org -> Repo -> BuildNumber -> StepNumber -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html Msg
viewLogLines org repo buildNumber stepNumber logFocus log following shiftDown =
    let
        content =
            case Maybe.withDefault RemoteData.NotAsked log of
                RemoteData.Success _ ->
                    viewLines org repo buildNumber stepNumber logFocus log following shiftDown

                RemoteData.Failure _ ->
                    code [ Util.testAttribute "logs-error" ] [ text "error" ]

                _ ->
                    div [ class "loading-logs" ] [ Util.smallLoaderWithText "loading logs..." ]
    in
    div [ class "logs", Util.testAttribute <| "logs-" ++ stepNumber ] [ content ]


{-| viewLines : takes step number, line focus information and click action and renders logs
-}
viewLines : Org -> Repo -> BuildNumber -> StepNumber -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html Msg
viewLines org repo buildNumber stepNumber logFocus log following shiftDown =
    let
        lines =
            if not <| logEmpty log then
                log
                    |> decodeAnsi
                    |> Array.indexedMap
                        (\idx line ->
                            Just <|
                                viewLine stepNumber
                                    (idx + 1)
                                    (Just line)
                                    stepNumber
                                    logFocus
                                    shiftDown
                        )
                    |> Array.toList

            else
                [ Just <|
                    viewLine stepNumber
                        1
                        Nothing
                        stepNumber
                        logFocus
                        shiftDown
                ]

        long =
            List.length lines > 25

        filename =
            stepLogsFilename org repo buildNumber stepNumber

        logs =
            topLogActions stepNumber following long filename (decodeLog log)
                :: lines
                ++ [ bottomLogActions stepNumber following long ]
                |> List.filterMap identity

        topTracker =
            tr [ class "line", class "opacity-0" ]
                [ button
                    -- auto page focus requires button role
                    [ id <|
                        stepTopTrackerFocusId stepNumber
                    , Html.Attributes.autofocus True
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "opacity-0" ]
                [ button
                    -- auto page focus requires button role
                    [ id <|
                        stepBottomTrackerFocusId stepNumber
                    , Html.Attributes.autofocus True
                    ]
                    []
                ]
    in
    table [ class "log-table" ] <| topTracker :: logs ++ [ bottomTracker ]


{-| viewLine : takes log line and focus information and renders line number button and log
-}
viewLine : String -> Int -> Maybe Ansi.Log.Line -> StepNumber -> LogFocus -> Bool -> Html Msg
viewLine id lineNumber line stepNumber logFocus shiftDown =
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
                    , Util.testAttribute <| String.join "-" [ "log", "line", stepNumber, String.fromInt lineNumber ]
                    , class <| logFocusStyles logFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton stepNumber logFocus lineNumber shiftDown ]
                    , td [ class "break-all", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "log", "data", stepNumber, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
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


{-| topLogActions : renders action buttons for the top of a step log
-}
topLogActions : StepNumber -> Int -> Bool -> String -> String -> Maybe (Html Msg)
topLogActions stepNumber following long filename logs =
    div
        [ class "line", class "-align-center" ]
        [ if String.isEmpty logs then
            code [ class "no-data" ] [ text "No data" ]

          else
            text ""
        , div
            [ class "wrapper"
            , class "buttons"
            , class "justify-flex-end"
            , Util.testAttribute <| "top-log-actions-" ++ stepNumber
            ]
            [ downloadButton stepNumber filename logs
            , jumpToBottomButton stepNumber long
            , stepFollowButton stepNumber following
            ]
        ]
        |> Just


{-| bottomLogActions : renders action buttons for the bottom of a step log
-}
bottomLogActions : StepNumber -> Int -> Bool -> Maybe (Html Msg)
bottomLogActions stepNumber following long =
    div
        [ class "line" ]
        [ div
            [ class "wrapper"
            , class "buttons"
            , class "justify-flex-end"
            , Util.testAttribute <| "bottom-log-actions-" ++ stepNumber
            ]
            [ jumpToTopButton stepNumber long
            , if long then
                stepFollowButton stepNumber following

              else
                text ""
            ]
        ]
        |> Just


{-| jumpToBottomButton : renders action button for jumping to the bottom of a step log
-}
jumpToBottomButton : StepNumber -> Bool -> Html Msg
jumpToBottomButton stepNumber long =
    if long then
        button
            [ attribute "data-tooltip" "jump to bottom"
            , class "tooltip-left"
            , class "button"
            , class "-icon"
            , Util.testAttribute <| "jump-to-bottom-" ++ stepNumber
            , onClick <| FocusOn <| stepBottomTrackerFocusId stepNumber
            ]
            [ FeatherIcons.arrowDownCircle |> FeatherIcons.toHtml [ attribute "role" "img" ] ]

    else
        text ""


{-| jumpToTopButton : renders action button for jumping to the top of a step log
-}
jumpToTopButton : StepNumber -> Bool -> Html Msg
jumpToTopButton stepNumber long =
    if long then
        button
            [ attribute "data-tooltip" "jump to top"
            , class "tooltip-left"
            , class "button"
            , class "-icon"
            , Util.testAttribute <| "jump-to-top-" ++ stepNumber
            , onClick <| FocusOn <| stepTopTrackerFocusId stepNumber
            ]
            [ FeatherIcons.arrowUpCircle |> FeatherIcons.toHtml [ attribute "role" "img" ] ]

    else
        text ""


{-| downloadButton : renders action button for downloading a step log
-}
downloadButton : String -> String -> String -> Html Msg
downloadButton stepNumber filename logs =
    if not <| String.isEmpty logs then
        button
            [ class "button"
            , class "-icon"
            , attribute "data-tooltip" "download logs"
            , class "tooltip-left"
            , Util.testAttribute <| "download-logs-" ++ stepNumber
            , onClick <| DownloadLogs filename logs
            ]
            [ FeatherIcons.download |> FeatherIcons.toHtml [ attribute "role" "img" ] ]

    else
        text ""


{-| stepFollowButton : renders button for following step logs
-}
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
    button
        [ class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , class "button"
        , class "-icon"
        , Util.testAttribute <| "follow-logs-" ++ stepNumber
        , onClick <| FollowStep toFollow
        ]
        [ icon |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


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

    NOTE: not used, but keeping around for future

-}
stepKilled : Step -> Html msg
stepKilled _ =
    div [ class "step-error", Util.testAttribute "step-error" ]
        [ span [ class "label" ] [ text "step was killed" ] ]


{-| stepSkipped : renders message for a skipped step
-}
stepSkipped : Step -> Html msg
stepSkipped _ =
    div [ class "step-skipped", Util.testAttribute "step-skipped" ]
        [ span [ class "label" ] [ text "step was skipped" ] ]


autoExpandStepsButton : Org -> Repo -> BuildNumber -> Bool -> Html Msg
autoExpandStepsButton org repo buildNumber expanding =
    let
        ( tooltip, icon ) =
            if expanding then
                ( "stop auto expanding steps", FeatherIcons.pauseCircle )

            else
                ( "start auto expanding steps", FeatherIcons.playCircle )
    in
    Html.button
        [ class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , class "button"
        , class "-icon"
        , Util.testAttribute <| "auto-expand-" ++ buildNumber
        , onClick <| FollowSteps org repo buildNumber expanding
        ]
        [ icon |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| collapseAllStepsButton : renders a button for collapsing all steps
-}
collapseAllStepsButton : Html Msg
collapseAllStepsButton =
    Html.button
        [ class "tooltip-left"
        , attribute "data-tooltip" "collapse all steps"
        , class "button"
        , class "-icon"
        , onClick CollapseAllSteps
        ]
        [ FeatherIcons.minusCircle |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| expandAllStepsButton : renders a button for expanding all steps
-}
expandAllStepsButton : Org -> Repo -> BuildNumber -> Html Msg
expandAllStepsButton org repo buildNumber =
    Html.button
        [ class "tooltip-left"
        , attribute "data-tooltip" "expand all steps"
        , class "button"
        , class "-icon"
        , onClick <| ExpandAllSteps org repo buildNumber
        ]
        [ FeatherIcons.plusCircle |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


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


{-| viewBuildHistory : takes the 10 most recent builds and renders icons/links back to them as a widget at the top of the Build page
-}
viewBuildHistory : Posix -> Zone -> Page -> Org -> Repo -> WebData Builds -> Int -> Html msg
viewBuildHistory now timezone page org repo builds limit =
    let
        ( show, buildNumber ) =
            case page of
                Pages.Build _ _ b _ ->
                    ( True, Maybe.withDefault -1 <| String.toInt b )

                _ ->
                    ( False, -1 )
    in
    if show then
        case builds of
            RemoteData.Success blds ->
                if List.length blds > 0 then
                    ul [ class "build-history", class "-no-pad", Util.testAttribute "build-history" ] <|
                        List.indexedMap (viewRecentBuild now timezone org repo buildNumber) <|
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


{-| viewRecentBuild : takes recent build and renders status and link to build as a small icon widget

    focusing or hovering the recent build icon will display a build info tooltip

-}
viewRecentBuild : Posix -> Zone -> Org -> Repo -> Int -> Int -> Build -> Html msg
viewRecentBuild now timezone org repo buildNumber idx build =
    li [ class "recent-build" ]
        [ recentBuildLink org repo buildNumber build idx
        , recentBuildTooltip now timezone build
        ]


{-| recentBuildLink : takes time info and build and renders line for redirecting to recent build

    focusing and hovering this element will display the tooltip

-}
recentBuildLink : Org -> Repo -> Int -> Build -> Int -> Html msg
recentBuildLink org repo buildNumber build idx =
    let
        icon =
            recentBuildStatusToIcon build.status idx

        currentBuildClass =
            if buildNumber == build.number then
                class "-current"

            else if buildNumber > build.number then
                class "-older"

            else
                class ""
    in
    a
        [ class "recent-build-link"
        , Util.testAttribute <| "recent-build-link-" ++ String.fromInt buildNumber
        , currentBuildClass
        , Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing
        , attribute "aria-label" <| "go to previous build number " ++ String.fromInt build.number
        ]
        [ icon
        ]


{-| recentBuildTooltip : takes time info and build and renders tooltip for viewing recent build info

    tooltip is visible when the recent build link is focused or hovered

-}
recentBuildTooltip : Posix -> Zone -> Build -> Html msg
recentBuildTooltip now timezone build =
    div [ class "recent-build-tooltip", Util.testAttribute "build-history-tooltip" ]
        [ ul [ class "info" ]
            [ li [ class "line" ]
                [ span [ class "number" ] [ text <| String.fromInt build.number ]
                , em [] [ text build.event ]
                ]
            , li [ class "line" ] [ span [] [ text "started:" ], text <| Util.dateToHumanReadable timezone build.started ]
            , li [ class "line" ] [ span [] [ text "finished:" ], text <| Util.dateToHumanReadable timezone build.finished ]
            , li [ class "line" ] [ span [] [ text "duration:" ], text <| Util.formatRunTime now build.started build.finished ]
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
