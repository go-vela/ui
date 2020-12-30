{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.View exposing
    ( buildStatusStyles
    , statusToClass
    , statusToString
    , viewBuild
    , viewBuildServices
    , viewBuildSteps
    , viewError
    , viewLine
    , viewPreview
    , wrapWithBuildPreview
    )

-- TODO better imports

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
import Html.Lazy exposing (lazy4)
import Http exposing (Error(..))
import List.Extra exposing (unique)
import Nav exposing (viewBuildNav)
import Pages exposing (Page(..))
import Pages.Build.Logs
    exposing
        ( decodeAnsi
        , getDownloadLogsFileName
        , getServiceLog
        , getStepLog
        , logEmpty
        , resourceBottomTrackerFocusId
        , resourceTopTrackerFocusId
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
        , Service
        , ServiceNumber
        , Services
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
        case model.repo.build.steps.steps of
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


{-| viewBuildSteps : renders entire build based on current application time
-}
viewBuildServices : PartialModel a -> Msgs msg -> Org -> Repo -> Html msg
viewBuildServices model msgs org repo =
    wrapWithBuildPreview model org repo <|
        case model.repo.build.services.services of
            RemoteData.Success services_ ->
                if List.isEmpty services_ then
                    div [ class "no-services" ] [ small [] [ code [] [ text "This pipeline has no services." ] ] ]

                else
                    let
                        logActions =
                            div
                                [ class "buttons"
                                , class "log-actions"

                                -- , class "flowline-left"
                                , Util.testAttribute "log-actions"
                                ]
                                [ collapseAllButton msgs.collapseAllServices
                                , expandAllButton msgs.expandAllServices model.repo.org model.repo.name model.repo.build.buildNumber
                                ]
                    in
                    div []
                        [ logActions
                        , div [ class "steps" ]
                            [ div [ class "-items", Util.testAttribute "steps" ] <|
                                viewServices model msgs model.repo services_
                            ]
                        ]

            RemoteData.Failure _ ->
                div [] [ text "Error loading services... Please try again" ]

            _ ->
                -- Don't show two loaders
                if Util.isLoading model.repo.build.build then
                    text ""

                else
                    Util.smallLoader


{-| viewSteps : takes build/steps and renders steps
-}
viewServices : PartialModel a -> Msgs msg -> RepoModel -> Services -> List (Html msg)
viewServices model msgs rm services =
    List.map (\service -> viewService model msgs rm services service) <| services


{-| viewService : renders single build step
-}
viewService : PartialModel a -> Msgs msg -> RepoModel -> Services -> Service -> Html msg
viewService model msgs rm services service =
    div
        [ serviceClasses services service
        , Util.testAttribute "service"
        ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStatusIcon service.status ] ]
        , viewServiceDetails model msgs rm service
        ]


{-| serviceClasses : returns css classes for a particular service
-}
serviceClasses : Services -> Service -> Html.Attribute msg
serviceClasses services service =
    let
        last =
            case List.head <| List.reverse services of
                Just s ->
                    s.number

                Nothing ->
                    -1
    in
    classList [ ( "step", True ) ]


{-| viewServiceDetails : renders build steps detailed information
-}
viewServiceDetails : PartialModel a -> Msgs msg -> RepoModel -> Service -> Html msg
viewServiceDetails model msgs rm service =
    let
        serviceNumber =
            String.fromInt service.number

        serviceSummary =
            [ summary
                [ class "summary"
                , Util.testAttribute <| "step-header-" ++ serviceNumber
                , onClick <| msgs.expandService rm.org rm.name rm.build.buildNumber serviceNumber
                , id <| resourceToFocusId "service" serviceNumber
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text service.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime model.time service.started service.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                ]
            , div [ class "logs-container" ] [ lazy4 viewServiceLogs msgs.logsMsgs model.shift rm service ]
            ]
    in
    details
        (classList
            [ ( "details", True )
            , ( "-with-border", True )
            , ( "-running", service.status == Vela.Running )
            ]
            :: Util.open service.viewing
        )
        serviceSummary


{-| wrapWithBuildPreview : takes html content and wraps it with the build preview
-}
wrapWithBuildPreview : PartialModel a -> Org -> Repo -> Html msg -> Html msg
wrapWithBuildPreview model org repo content =
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
                , Routes.href <| Routes.Build org repo buildNumber Nothing
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
                [ collapseAllButton msgs.collapseAllSteps
                , expandAllButton msgs.expandAllSteps rm.org rm.name rm.build.buildNumber
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
            [ div [ class "-icon-container" ] [ viewStatusIcon step.status ] ]
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
            , div [ class "logs-container" ] [ viewStepLogs msgs.logsMsgs model.shift rm step ]
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


{-| viewStepLogs : takes step and logs and renders step logs or step error
-}
viewStepLogs : LogsMsgs msg -> Bool -> RepoModel -> Step -> Html msg
viewStepLogs msgs shift rm step =
    case step.status of
        Vela.Error ->
            stepError step

        Vela.Killed ->
            stepSkipped step

        _ ->
            viewLogLines msgs
                msgs.followStep
                rm.org
                rm.name
                rm.build.buildNumber
                "step"
                (String.fromInt step.number)
                step.logFocus
                (getStepLog step rm.build.steps.logs)
                rm.build.steps.followingStep
                shift


{-| viewServiceLogs : takes service and logs and renders step logs or step error
-}
viewServiceLogs : LogsMsgs msg -> Bool -> RepoModel -> Service -> Html msg
viewServiceLogs msgs shift rm service =
    case service.status of
        Vela.Error ->
            serviceError service

        Vela.Killed ->
            serviceSkipped service

        _ ->
            viewLogLines msgs
                msgs.followService
                rm.org
                rm.name
                rm.build.buildNumber
                "service"
                (String.fromInt service.number)
                service.logFocus
                (getServiceLog service rm.build.services.logs)
                rm.build.services.followingService
                shift


{-| viewLogLines : takes number linefocus log and clickAction shiftDown and renders logs for a build resource
-}
viewLogLines : LogsMsgs msg -> FollowResource msg -> Org -> Repo -> BuildNumber -> String -> ResourceID -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html msg
viewLogLines msgs followMsg org repo buildNumber resource resourceID logFocus maybeLog following shiftDown =
    let
        decodedLog =
            toString maybeLog

        fileName =
            getDownloadLogsFileName org repo buildNumber resource resourceID
    in
    div
        [ class "logs"
        , Util.testAttribute <| "logs-" ++ resourceID
        ]
    <|
        case Maybe.withDefault RemoteData.NotAsked maybeLog of
            RemoteData.Success _ ->
                if logEmpty decodedLog then
                    [ emptyLogs ]

                else
                    let
                        ( logs, numLines ) =
                            viewLines msgs.focusLine resource resourceID logFocus decodedLog shiftDown
                    in
                    [ logsHeader msgs resource resourceID fileName decodedLog
                    , logsSidebar msgs.focusOn followMsg resource resourceID following numLines
                    , logs
                    ]

            RemoteData.Failure err ->
                [ code [ Util.testAttribute "logs-error" ] [ text "error fetching logs" ] ]

            _ ->
                [ loadingLogs ]


{-| viewLines : takes number, line focus information and click action and renders logs
-}
viewLines : FocusLine msg -> Resource -> ResourceID -> LogFocus -> String -> Bool -> ( Html msg, Int )
viewLines focusLine resource resourceID logFocus decodedLog shiftDown =
    let
        lines =
            if not <| logEmpty decodedLog then
                decodedLog
                    |> decodeAnsi
                    |> Array.indexedMap
                        (\idx line ->
                            Just <|
                                viewLine focusLine
                                    resource
                                    resourceID
                                    (idx + 1)
                                    (Just line)
                                    logFocus
                                    shiftDown
                        )
                    |> Array.toList

            else
                [ Just <|
                    viewLine focusLine
                        resource
                        resourceID
                        1
                        Nothing
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
                        resourceTopTrackerFocusId resource resourceID
                    , Util.testAttribute <| "top-log-tracker-" ++ resourceID
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <|
                        resourceBottomTrackerFocusId resource resourceID
                    , Util.testAttribute <| "bottom-log-tracker-" ++ resourceID
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
viewLine : FocusLine msg -> Resource -> ResourceID -> Int -> Maybe Ansi.Log.Line -> LogFocus -> Bool -> Html msg
viewLine focusLine resource resourceID lineNumber line logFocus shiftDown =
    tr
        [ Html.Attributes.id <|
            resourceID
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
                        [ lineFocusButton focusLine resource resourceID logFocus lineNumber shiftDown ]
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
lineFocusButton : (String -> msg) -> Resource -> ResourceID -> LogFocus -> Int -> Bool -> Html msg
lineFocusButton focusLogs resource resourceID logFocus lineNumber shiftDown =
    button
        [ Util.onClickPreventDefault <|
            focusLogs <|
                lineRangeId resource resourceID lineNumber logFocus shiftDown
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", resourceID, String.fromInt lineNumber ]
        , id <| resourceAndLineToFocusId resource resourceID lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus " ++ resource ++ " " ++ resourceID
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]


{-| collapseAllButton : renders a button for collapsing all resources
-}
collapseAllButton : msg -> Html msg
collapseAllButton collapseAllSteps =
    Html.button
        [ class "button"
        , class "-link"
        , onClick collapseAllSteps
        , Util.testAttribute "collapse-all"
        ]
        [ small [] [ text "collapse all" ] ]


{-| expandAllButton : renders a button for expanding all resources
-}
expandAllButton : ExpandAll msg -> Org -> Repo -> BuildNumber -> Html msg
expandAllButton expandAll org repo buildNumber =
    Html.button
        [ class "button"
        , class "-link"
        , onClick <| expandAll org repo buildNumber
        , Util.testAttribute "expand-all"
        ]
        [ small [] [ text "expand all" ] ]


{-| logsHeader : takes number, filename and decoded log and renders logs header
-}
logsHeader : LogsMsgs msg -> String -> String -> String -> String -> Html msg
logsHeader msgs resource number fileName decodedLog =
    div [ class "logs-header", class "buttons", Util.testAttribute <| "logs-header-actions-" ++ number ]
        [ downloadLogsButton msgs.download resource number fileName decodedLog ]


{-| logsSidebar : takes number/following and renders the logs sidebar
-}
logsSidebar : FocusOn msg -> FollowResource msg -> String -> String -> Int -> Int -> Html msg
logsSidebar focusOn followMsg resource number following numLines =
    let
        long =
            numLines > 25
    in
    div [ class "logs-sidebar" ]
        [ div [ class "inner-container" ]
            [ div
                [ class "actions"
                , Util.testAttribute <| "logs-sidebar-actions-" ++ number
                ]
              <|
                (if long then
                    [ jumpToTopButton focusOn resource number
                    , jumpToBottomButton focusOn resource number
                    ]

                 else
                    []
                )
                    ++ [ followButton followMsg resource number following ]
            ]
        ]


{-| jumpToBottomButton : renders action button for jumping to the bottom of a log
-}
jumpToBottomButton : FocusOn msg -> String -> String -> Html msg
jumpToBottomButton focusOn resource number =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to bottom"
        , Util.testAttribute <| "jump-to-bottom-" ++ number
        , onClick <| focusOn <| resourceBottomTrackerFocusId resource number
        , attribute "aria-label" <| "jump to bottom of logs for " ++ resource ++ " " ++ number
        ]
        [ FeatherIcons.arrowDown |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| jumpToTopButton : renders action button for jumping to the top of a log
-}
jumpToTopButton : FocusOn msg -> String -> String -> Html msg
jumpToTopButton focusOn resource number =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to top"
        , Util.testAttribute <| "jump-to-top-" ++ number
        , onClick <| focusOn <| resourceTopTrackerFocusId resource number
        , attribute "aria-label" <| "jump to top of logs for " ++ resource ++ " " ++ number
        ]
        [ FeatherIcons.arrowUp |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| downloadLogsButton : renders action button for downloading a log
-}
downloadLogsButton : Download msg -> String -> String -> String -> String -> Html msg
downloadLogsButton download resource number fileName logs =
    button
        [ class "button"
        , class "-link"
        , Util.testAttribute <| "download-logs-" ++ number
        , onClick <| download fileName logs
        , attribute "aria-label" <| "download logs for " ++ resource ++ " " ++ number
        ]
        [ text <| "download " ++ resource ++ " logs" ]


{-| followButton : renders button for following logs
-}
followButton : FollowResource msg -> String -> String -> Int -> Html msg
followButton followStep resource number following =
    let
        num =
            Maybe.withDefault 0 <| String.toInt number

        ( tooltip, icon, toFollow ) =
            if following == 0 then
                ( "start following " ++ resource ++ " logs", FeatherIcons.play, num )

            else if following == num then
                ( "stop following " ++ resource ++ " logs", FeatherIcons.pause, 0 )

            else
                ( "start following " ++ resource ++ " logs", FeatherIcons.play, num )
    in
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , Util.testAttribute <| "follow-logs-" ++ number
        , onClick <| followStep toFollow
        , attribute "aria-label" <| tooltip ++ " for " ++ resource ++ " " ++ number
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


{-| serviceError : checks for build error and renders message
-}
serviceError : Service -> Html msg
serviceError service =
    div [ class "message", class "error", Util.testAttribute "service-error" ]
        [ span [] [ text "error:" ]
        , text <|
            if String.isEmpty service.error then
                "null"

            else
                service.error
        ]


{-| serviceSkipped : renders message for a skipped service
-}
serviceSkipped : Service -> Html msg
serviceSkipped _ =
    div [ class "message", class "error", Util.testAttribute "service-skipped" ]
        [ text "service was skipped" ]


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


{-| viewStatusIcon : renders a build step status icon
-}
viewStatusIcon : Status -> Html msg
viewStatusIcon status =
    stepStatusToIcon status


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
