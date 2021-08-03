{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.View exposing
    ( viewBuild
    , viewBuildServices
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
import Html exposing (Html, a, button, code, details, div, li, small, span, strong, summary, table, td, text, tr, ul)
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
import List.Extra exposing (unique)
import Nav exposing (viewBuildTabs)
import Pages.Build.Logs
    exposing
        ( bottomTrackerFocusId
        , decodeAnsi
        , downloadFileName
        , getLog
        , logEmpty
        , toString
        , topTrackerFocusId
        )
import Pages.Build.Model
    exposing
        ( Download
        , ExpandAll
        , FocusLine
        , FocusOn
        , FollowResource
        , LogsMsgs
        , Msgs
        , PartialModel
        )
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import String
import SvgBuilder exposing (buildStatusToIcon, stepStatusToIcon)
import Time exposing (Posix, Zone)
import Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , Log
        , LogFocus
        , Org
        , Repo
        , RepoModel
        , Service
        , Status
        , Step
        , Steps
        , defaultStep
        )



-- VIEW


{-| viewBuild : renders entire build based on current application time
-}
viewBuild : PartialModel a -> Msgs msg -> Org -> Repo -> BuildNumber -> Html msg
viewBuild model msgs org repo buildNumber =
    wrapWithBuildPreview model msgs org repo buildNumber <|
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


{-| wrapWithBuildPreview : takes html content and wraps it with the build preview
-}
wrapWithBuildPreview : PartialModel a -> Msgs msgs -> Org -> Repo -> BuildNumber -> Html msgs -> Html msgs
wrapWithBuildPreview model msgs org repo buildNumber content =
    let
        rm =
            model.repo

        build =
            rm.build

        markdown =
            case build.build of
                RemoteData.Success bld ->
                    [ viewPreview msgs model.buildMenuOpen False model.time model.zone org repo bld
                    , viewBuildTabs model org repo buildNumber model.page
                    , content
                    ]

                RemoteData.Loading ->
                    [ Util.largeLoader ]

                _ ->
                    [ div
                        [ class "build-preview-error" ]
                        [ text <| "Error loading " ++ String.join "/" [ org, repo, buildNumber ] ++ " ... Please try again" ]
                    ]
    in
    div [ Util.testAttribute "full-build" ] markdown


{-| restartBuildButton : takes org repo and build number and renders button to restart a build
-}
restartBuildButton : Org -> Repo -> Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
restartBuildButton org repo build restartBuild =
    button
        [ classList
            [ ( "button", True )
            , ( "-outline", True )
            ]
        , onClick <| restartBuild org repo <| String.fromInt build.number
        , Util.testAttribute "restart-build"
        ]
        [ text "Restart Build"
        ]


{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Msgs msgs -> List Int -> Bool -> Posix -> Zone -> Org -> Repo -> Build -> Html msgs
viewPreview msgs openMenu showMenu now zone org repo build =
    let
        buildMenuBaseClassList : Html.Attribute msg
        buildMenuBaseClassList =
            classList
                [ ( "details", True )
                , ( "-marker-right", True )
                , ( "-no-pad", True )
                , ( "build-toggle", True )
                ]

        buildMenuAttributeList : List (Html.Attribute msg)
        buildMenuAttributeList =
            attribute "role" "navigation" :: Util.open (List.member build.id openMenu)

        restartBuild : Html msgs
        restartBuild =
            li [ class "build-menu-item" ]
                [ a
                    [ href "#"
                    , class "menu-item"
                    , Util.onClickPreventDefault <| msgs.restartBuild org repo <| String.fromInt build.number
                    , Util.testAttribute "restart-build"
                    ]
                    [ text "Restart Build"
                    ]
                ]

        cancelBuild : Html msgs
        cancelBuild =
            case build.status of
                Vela.Running ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <| msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                _ ->
                    text ""

        actionsMenu =
            if showMenu then
                details (buildMenuBaseClassList :: buildMenuAttributeList)
                    [ summary [ class "summary", Util.onClickPreventDefault (msgs.toggle build.id Nothing), Util.testAttribute "build-menu" ]
                        [ text "Actions"
                        , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                        ]
                    , ul [ class "build-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                        [ restartBuild
                        , cancelBuild
                        ]
                    ]

            else
                div [] []

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

        -- calculate build runtime
        runtime =
            Util.formatRunTime now build.started build.finished

        -- mask completed/pending builds that have not finished
        duration =
            case build.status of
                Vela.Running ->
                    runtime

                _ ->
                    if build.finished /= 0 then
                        runtime

                    else
                        "--:--"

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
                        [ div [ class "age", title timestamp ] age
                        , span [ class "delimiter" ] [ text "/" ]
                        , div [ class "duration" ] [ text duration ]
                        , actionsMenu
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



-- STEPS


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
    List.map (\step -> viewStep model msgs rm step) <| steps


{-| viewStep : renders single build step
-}
viewStep : PartialModel a -> Msgs msg -> RepoModel -> Step -> Html msg
viewStep model msgs rm step =
    div [ stepClasses, Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStatusIcon step.status ] ]
        , viewStepDetails model msgs rm step
        ]


{-| stepClasses : returns css classes for a particular step
-}
stepClasses : Html.Attribute msg
stepClasses =
    classList [ ( "step", True ), ( "flowline-left", True ) ]


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
                    |> List.filter
                        (\step ->
                            (stage == "init" && (step.stage == "init" || step.stage == "clone"))
                                || (stage /= "clone" && step.stage == stage)
                        )
                    |> viewStage model msgs rm stage
            )


{-| viewStage : takes model, build model and stage and renders the stage steps
-}
viewStage : PartialModel a -> Msgs msg -> RepoModel -> String -> Steps -> Html msg
viewStage model msgs rm stage steps =
    div
        [ class "stage", Util.testAttribute <| "stage" ]
        [ viewStageDivider stage
        , steps
            |> List.map (\step -> viewStep model msgs rm step)
            |> div [ Util.testAttribute <| "stage-" ++ stage ]
        ]


{-| viewStageDivider : renders divider between stage
-}
viewStageDivider : String -> Html msg
viewStageDivider stage =
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
            viewResourceError step

        Vela.Killed ->
            div [ class "message", class "error", Util.testAttribute "step-skipped" ]
                [ text "step was skipped" ]

        _ ->
            viewLogLines msgs
                msgs.followStep
                rm.org
                rm.name
                rm.build.buildNumber
                "step"
                (String.fromInt step.number)
                step.logFocus
                (getLog step .step_id rm.build.steps.logs)
                rm.build.steps.followingStep
                shift



-- SERVICES


{-| viewBuildServices : renders build services
-}
viewBuildServices : PartialModel a -> Msgs msg -> Org -> Repo -> BuildNumber -> Html msg
viewBuildServices model msgs org repo buildNumber =
    wrapWithBuildPreview model msgs org repo buildNumber <|
        case model.repo.build.services.services of
            RemoteData.Success services ->
                if List.isEmpty services then
                    div [ class "no-services" ] [ small [] [ code [] [ text "No services found for this pipeline." ] ] ]

                else
                    let
                        logActions =
                            div
                                [ class "buttons"
                                , class "log-actions"
                                , Util.testAttribute "log-actions"
                                ]
                                [ collapseAllButton msgs.collapseAllServices
                                , expandAllButton msgs.expandAllServices model.repo.org model.repo.name model.repo.build.buildNumber
                                ]
                    in
                    div []
                        [ logActions
                        , div [ class "steps" ]
                            [ div [ class "-items", Util.testAttribute "services" ] <|
                                List.map (\service -> viewService model msgs model.repo service) <|
                                    services
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


{-| viewService : renders single build service
-}
viewService : PartialModel a -> Msgs msg -> RepoModel -> Service -> Html msg
viewService model msgs rm service =
    div
        [ serviceClasses
        , Util.testAttribute "service"
        ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStatusIcon service.status ] ]
        , viewServiceDetails model msgs rm service
        ]


{-| serviceClasses : returns css classes for a particular service
-}
serviceClasses : Html.Attribute msg
serviceClasses =
    classList [ ( "service", True ) ]


{-| viewServiceDetails : renders build services detailed information
-}
viewServiceDetails : PartialModel a -> Msgs msg -> RepoModel -> Service -> Html msg
viewServiceDetails model msgs rm service =
    let
        serviceNumber =
            String.fromInt service.number

        serviceSummary =
            [ summary
                [ class "summary"
                , Util.testAttribute <| "service-header-" ++ serviceNumber
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
            , div [ class "logs-container" ] [ viewServiceLogs msgs.logsMsgs model.shift rm service ]
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


{-| viewServiceLogs : renders service logs
-}
viewServiceLogs : LogsMsgs msg -> Bool -> RepoModel -> Service -> Html msg
viewServiceLogs msgs shift rm service =
    case service.status of
        Vela.Error ->
            viewResourceError service

        Vela.Killed ->
            div [ class "message", class "error", Util.testAttribute "service-skipped" ]
                [ text "service was skipped" ]

        _ ->
            viewLogLines msgs
                msgs.followService
                rm.org
                rm.name
                rm.build.buildNumber
                "service"
                (String.fromInt service.number)
                service.logFocus
                (getLog service .service_id rm.build.services.logs)
                rm.build.services.followingService
                shift



-- LOGS


{-| viewLogLines : takes number linefocus log and clickAction shiftDown and renders logs for a build resource
-}
viewLogLines : LogsMsgs msg -> FollowResource msg -> Org -> Repo -> BuildNumber -> String -> ResourceID -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html msg
viewLogLines msgs followMsg org repo buildNumber resource resourceID logFocus maybeLog following shiftDown =
    let
        decodedLog =
            toString maybeLog

        fileName =
            downloadFileName org repo buildNumber resource resourceID
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

            RemoteData.Failure _ ->
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
                        topTrackerFocusId resource resourceID
                    , Util.testAttribute <| "top-log-tracker-" ++ resourceID
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <|
                        bottomTrackerFocusId resource resourceID
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
                    , Util.testAttribute <| String.join "-" [ "log", "line", resource, resourceID, String.fromInt lineNumber ]
                    , class <| lineFocusStyles logFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton focusLine resource resourceID logFocus lineNumber shiftDown ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "log", "data", resource, resourceID, String.fromInt lineNumber ] ]
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
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", resource, resourceID, String.fromInt lineNumber ]
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
        , onClick <| focusOn <| bottomTrackerFocusId resource number
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
        , onClick <| focusOn <| topTrackerFocusId resource number
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


{-| viewResourceError : checks for build error and renders message
-}
viewResourceError : Vela.Resource a -> Html msg
viewResourceError resource =
    div [ class "message", class "error", Util.testAttribute "resource-error" ]
        [ text <|
            "error: "
                ++ (if String.isEmpty resource.error then
                        "null"

                    else
                        resource.error
                   )
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

        Vela.Canceled ->
            div [ class "error", Util.testAttribute "build-canceled" ]
                [ text "build was canceled"
                ]

        _ ->
            div [] []



-- HELPERS


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

        Vela.Canceled ->
            class "-failure"

        Vela.Error ->
            class "-error"


{-| buildStatusStyles : takes build markdown and adds styled flair based on running status
-}
buildStatusStyles : List (Html msgs) -> Status -> Int -> List (Html msgs)
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
