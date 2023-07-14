{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.View exposing
    ( viewBuild
    , viewBuildGraph
    , viewBuildServices
    , viewPreview
    , wrapWithBuildPreview
    )

import Ansi
import Ansi.Log
import Array
import DateFormat.Relative exposing (relativeTime)
import FeatherIcons
import Focus
    exposing
        ( ResourceID
        , ResourceType
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
        , style
        , title
        )
import Html.Events exposing (onClick)
import List.Extra exposing (unique)
import Nav exposing (viewBuildTabs)
import Pages.Build.Logs
    exposing
        ( bottomTrackerFocusId
        , defaultAnsiLogModel
        , downloadFileName
        , getLog
        , isEmpty
        , topTrackerFocusId
        )
import Pages.Build.Model
    exposing
        ( Download
        , ExpandAll
        , FocusLine
        , FocusOn
        , FollowResource
        , LogLine
        , LogsMsgs
        , Msgs
        , PartialModel
        )
import RemoteData exposing (WebData)
import Routes
import String
import Svg
import Svg.Attributes
import SvgBuilder exposing (buildStatusToIcon, stepStatusToIcon)
import Time exposing (Posix, Zone)
import Url
import Util exposing (getNameFromRef)
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
                    [ viewPreview msgs model.buildMenuOpen False model.time model.zone org repo rm.builds.showTimestamp bld
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


{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Msgs msgs -> List Int -> Bool -> Posix -> Zone -> Org -> Repo -> Bool -> Build -> Html msgs
viewPreview msgs openMenu showMenu now zone org repo showTimestamp build =
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
            [ attribute "role" "navigation", id "build-actions" ] ++ Util.open (List.member build.id openMenu)

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
                    [ summary [ class "summary", Util.onClickPreventDefault (msgs.toggle (Just build.id) Nothing), Util.testAttribute "build-menu" ]
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

        repoName =
            case repo of
                "" ->
                    List.head (List.drop 4 (String.split "/" build.link))

                _ ->
                    Nothing

        repoLink =
            case repoName of
                Just name ->
                    span []
                        [ a [ Routes.href <| Routes.RepositoryBuilds org name Nothing Nothing Nothing ] [ text name ]
                        , text ": "
                        ]

                _ ->
                    text ""

        buildNumber =
            String.fromInt build.number

        status =
            [ buildStatusToIcon build.status ]

        commit =
            case build.event of
                "pull_request" ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " "
                    , a [ href build.source ]
                        [ text "#"
                        , text (getNameFromRef build.ref)
                        ]
                    , text " ("
                    , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

                "tag" ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " "
                    , a [ href build.source ] [ text (getNameFromRef build.ref) ]
                    , text " ("
                    , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

                "deployment" ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " ("
                    , a [ href <| Util.buildRefURL build.clone build.commit ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

                _ ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " ("
                    , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

        branch =
            [ a [ href <| Util.buildRefURL build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        message =
            [ text <| "- " ++ build.message ]

        buildId =
            [ a
                [ Util.testAttribute "build-number"
                , href build.link
                ]
                [ text <| "#" ++ buildNumber ]
            ]

        buildCreatedPosix =
            Time.millisToPosix <| Util.secondsToMillis build.created

        age =
            relativeTime now <| buildCreatedPosix

        timestamp =
            Util.humanReadableDateTimeFormatter zone buildCreatedPosix

        displayTime =
            if showTimestamp then
                [ text <| timestamp ++ " " ]

            else
                [ text age ]

        hoverTime =
            if showTimestamp then
                age

            else
                timestamp

        -- calculate build runtime
        runtime =
            Util.formatRunTime now build.started build.finished

        -- mask completed/pending builds that have not finished
        duration =
            case build.status of
                Vela.Running ->
                    runtime

                _ ->
                    if build.started /= 0 && build.finished /= 0 then
                        runtime

                    else
                        "--:--"

        statusClass =
            statusToClass build.status
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ]
            [ div [ class "status", Util.testAttribute "build-status", statusClass ] status
            , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] buildId
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
                        [ div [ class "time-completed" ]
                            [ div [ class "age", title hoverTime ] displayTime
                            , span [ class "delimiter" ] [ text " /" ]
                            , div [ class "duration" ] [ text duration ]
                            ]
                        , actionsMenu
                        ]
                    ]
                , div [ class "row" ]
                    [ viewError build
                    ]
                ]
            , buildAnimation build.status build.number
            ]
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



-- VISUALIZE


{-| viewBuildGraph : renders build graph using graphviz and d3
-}
viewBuildGraph : PartialModel a -> Msgs msg -> Org -> Repo -> BuildNumber -> Html msg
viewBuildGraph model msgs org repo buildNumber =
    wrapWithBuildPreview model msgs org repo buildNumber <|
        case model.repo.build.build of
            RemoteData.Success b ->
                Html.div
                    [ class "build-graph-view"
                    , id "build-graph-container"

                    -- , Html.Attributes.style "display" "flex"
                    -- , Html.Attributes.style "flex-direction" "column"
                    -- , Html.Attributes.style "flex-grow" "1"
                    ]
                    [ Html.div
                        [ class "build-graph-content" ]
                        [ Svg.svg
                            [ Svg.Attributes.class "build-graph" ]
                            []
                        ]
                    ]

            RemoteData.Failure _ ->
                div [] [ text "Error loading build graph... Please try again" ]

            _ ->
                -- Don't show two loaders
                if Util.isLoading model.repo.build.build then
                    text ""

                else
                    Util.smallLoader



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
        [ class "service"
        , Util.testAttribute "service"
        ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStatusIcon service.status ] ]
        , viewServiceDetails model msgs rm service
        ]


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
viewLogLines : LogsMsgs msg -> FollowResource msg -> Org -> Repo -> BuildNumber -> ResourceType -> ResourceID -> LogFocus -> Maybe (WebData Log) -> Int -> Bool -> Html msg
viewLogLines msgs followMsg org repo buildNumber resourceType resourceID logFocus maybeLog following shiftDown =
    div
        [ class "logs"
        , Util.testAttribute <| "logs-" ++ resourceID
        ]
    <|
        case Maybe.withDefault RemoteData.NotAsked maybeLog of
            RemoteData.Success l ->
                let
                    fileName =
                        downloadFileName org repo buildNumber resourceType resourceID

                    ( logs, numLines ) =
                        viewLines msgs.focusLine resourceType resourceID logFocus l.decodedLogs shiftDown
                in
                [ logsHeader msgs resourceType resourceID fileName l
                , logsSidebar msgs.focusOn followMsg resourceType resourceID following numLines
                , logs
                ]

            RemoteData.Failure _ ->
                [ code [ Util.testAttribute "logs-error" ] [ text "error fetching logs" ] ]

            _ ->
                [ loadingLogs ]


{-| viewLines : takes number, line focus information and click action and renders logs
-}
viewLines : FocusLine msg -> ResourceType -> ResourceID -> LogFocus -> String -> Bool -> ( Html msg, Int )
viewLines focusLine resourceType resourceID logFocus decodedLog shiftDown =
    let
        lines =
            decodedLog
                -- this is where link parsing happens
                |> processLogLines
                |> List.indexedMap
                    (\idx logLine ->
                        Just <|
                            viewLine focusLine
                                resourceType
                                resourceID
                                (idx + 1)
                                logLine
                                logFocus
                                shiftDown
                    )

        logs =
            lines
                |> List.filterMap identity

        topTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <|
                        topTrackerFocusId resourceType resourceID
                    , Util.testAttribute <| "top-log-tracker-" ++ resourceID
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <|
                        bottomTrackerFocusId resourceType resourceID
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
viewLine : FocusLine msg -> ResourceType -> ResourceID -> Int -> LogLine msg -> LogFocus -> Bool -> Html msg
viewLine focusLine resourceType resourceID lineNumber logLine logFocus shiftDown =
    tr
        [ Html.Attributes.id <|
            resourceID
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ div
            [ class "wrapper"
            , Util.testAttribute <| String.join "-" [ "log", "line", resourceType, resourceID, String.fromInt lineNumber ]
            , class <| lineFocusStyles logFocus lineNumber
            ]
            [ td []
                [ lineFocusButton focusLine resourceType resourceID logFocus lineNumber shiftDown ]
            , td [ class "break-text", class "overflow-auto" ]
                [ code [ Util.testAttribute <| String.join "-" [ "log", "data", resourceType, resourceID, String.fromInt lineNumber ] ]
                    [ logLine.view
                    ]
                ]
            ]
        ]


{-| processLogLines : takes a log as string, splits it by newline, and processes it into a model that can render custom elements like timestamps and links
-}
processLogLines : String -> List (LogLine msg)
processLogLines log =
    log
        |> String.split "\n"
        |> List.map
            (\log_ ->
                let
                    -- first we convert the individual log line into an Ansi.Log.Model
                    -- this lets us preserve the original ANSI style while applying our own processing
                    -- we use List.head to ignore extra empty lines generated by Ansi.Log.update, since we already split by newline
                    ansiLogLine =
                        List.head <| Array.toList <| .lines <| Ansi.Log.update log_ defaultAnsiLogModel
                in
                -- next we take the decoded log line, run custom processing like link parsing, then render it to Html
                case ansiLogLine of
                    Just logLine ->
                        -- pack the log line into a struct to make it more flexible when rendering later
                        -- this is particularly useful for adding toggleable features like timestamps
                        -- we will most likely need to extend this to accept user preferences
                        -- for example, a user may choose to not render links or timestamps
                        -- per chunk render processing happens in processLogLine
                        processLogLine logLine

                    Nothing ->
                        LogLine (text "")
            )


{-| processLogLine : takes Ansi.Log.Line and renders it into Html after parsing and processing custom rendering rules
-}
processLogLine : Ansi.Log.Line -> LogLine msg
processLogLine ansiLogLine =
    let
        -- per-log line processing goes here
        ( chunks, _ ) =
            ansiLogLine

        -- a single div is rendered containing a styled span for each ansi "chunk"
        view =
            div [] <|
                List.foldl
                    (\c l ->
                        -- potential here to read metadata from "chunks" and store in LogLine
                        viewChunk c :: l
                    )
                    [ text "\n" ]
                    chunks
    in
    LogLine view


{-| viewChunk : takes Ansi.Log.Chunk and renders it into Html with ANSI styling
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been modified to allow custom processing
-}
viewChunk : Ansi.Log.Chunk -> Html msg
viewChunk chunk =
    chunk
        -- per-chunk processing goes here
        |> viewLogLinks
        |> viewAnsi chunk


{-| viewAnsi : takes Ansi.Log.Chunk and Html children and renders wraps them with ANSI styling
-}
viewAnsi : Ansi.Log.Chunk -> List (Html msg) -> Html msg
viewAnsi chunk children =
    span (styleAttributesAnsi chunk.style) children


{-| viewLogLinks : takes Ansi.Log.Chunk and performs additional processing to parse links
-}
viewLogLinks : Ansi.Log.Chunk -> List (Html msg)
viewLogLinks chunk =
    let
        -- list of string escape characters that delimit links.
        -- for example "<https://github.com"> should be split from the quotes, even though " is a valid URL character (see: see: <https://www.rfc-editor.org/rfc/rfc3986#section-2>)
        linkEscapeCharacters =
            [ "'", " ", "\"", "\t", "\n" ]

        -- its possible this will split a "valid" link containing quote characters, but its a willing risk
        splitIntersperseConcat : String -> List String -> List String
        splitIntersperseConcat sep list =
            list
                |> List.concatMap
                    (\x ->
                        x
                            |> String.split sep
                            |> List.intersperse sep
                    )

        -- split the "line" by escape characters
        split =
            List.foldl splitIntersperseConcat [ chunk.text ] linkEscapeCharacters
    in
    -- "process" each "split chunk" and check for link
    -- for example, this accounts for multiple links contained in a single ANSI background color "chunk"
    List.map
        (\chunk_ ->
            case Url.fromString chunk_ of
                Just link ->
                    viewLogLink link chunk_

                Nothing ->
                    text chunk_
        )
        split


{-| viewLogLink : takes a url and label and renders a link
-}
viewLogLink : Url.Url -> String -> Html msg
viewLogLink link txt =
    -- use toString in href to make the link safe
    a [ Util.testAttribute "log-line-link", href <| Url.toString link ] [ text txt ]


{-| lineFocusButton : renders button for focusing log line ranges
-}
lineFocusButton : (String -> msg) -> ResourceType -> ResourceID -> LogFocus -> Int -> Bool -> Html msg
lineFocusButton focusLogs resourceType resourceID logFocus lineNumber shiftDown =
    button
        [ Util.onClickPreventDefault <|
            focusLogs <|
                lineRangeId resourceType resourceID lineNumber logFocus shiftDown
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", resourceType, resourceID, String.fromInt lineNumber ]
        , id <| resourceAndLineToFocusId resourceType resourceID lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus " ++ resourceType ++ " " ++ resourceID
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
logsHeader : LogsMsgs msg -> ResourceType -> String -> String -> Log -> Html msg
logsHeader msgs resourceType number fileName log =
    div [ class "logs-header", class "buttons", Util.testAttribute <| "logs-header-actions-" ++ number ]
        [ downloadLogsButton msgs.download resourceType number fileName log ]


{-| logsSidebar : takes number/following and renders the logs sidebar
-}
logsSidebar : FocusOn msg -> FollowResource msg -> ResourceType -> String -> Int -> Int -> Html msg
logsSidebar focusOn followMsg resourceType number following numLines =
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
                    [ jumpToTopButton focusOn resourceType number
                    , jumpToBottomButton focusOn resourceType number
                    ]

                 else
                    []
                )
                    ++ [ followButton followMsg resourceType number following ]
            ]
        ]


{-| jumpToBottomButton : renders action button for jumping to the bottom of a log
-}
jumpToBottomButton : FocusOn msg -> ResourceType -> String -> Html msg
jumpToBottomButton focusOn resourceType number =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to bottom"
        , Util.testAttribute <| "jump-to-bottom-" ++ number
        , onClick <| focusOn <| bottomTrackerFocusId resourceType number
        , attribute "aria-label" <| "jump to bottom of logs for " ++ resourceType ++ " " ++ number
        ]
        [ FeatherIcons.arrowDown |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| jumpToTopButton : renders action button for jumping to the top of a log
-}
jumpToTopButton : FocusOn msg -> ResourceType -> String -> Html msg
jumpToTopButton focusOn resourceType number =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to top"
        , Util.testAttribute <| "jump-to-top-" ++ number
        , onClick <| focusOn <| topTrackerFocusId resourceType number
        , attribute "aria-label" <| "jump to top of logs for " ++ resourceType ++ " " ++ number
        ]
        [ FeatherIcons.arrowUp |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| downloadLogsButton : renders action button for downloading a log
-}
downloadLogsButton : Download msg -> ResourceType -> String -> String -> Log -> Html msg
downloadLogsButton download resourceType number fileName log =
    let
        logEmpty =
            isEmpty log
    in
    button
        [ class "button"
        , class "-link"
        , Html.Attributes.disabled logEmpty
        , Util.attrIf logEmpty <| class "-hidden"
        , Util.attrIf logEmpty <| Util.ariaHidden
        , Util.testAttribute <| "download-logs-" ++ number
        , onClick <| download fileName log.rawData
        , attribute "aria-label" <| "download logs for " ++ resourceType ++ " " ++ number
        ]
        [ text <| "download " ++ resourceType ++ " logs" ]


{-| followButton : renders button for following logs
-}
followButton : FollowResource msg -> ResourceType -> String -> Int -> Html msg
followButton followStep resourceType number following =
    let
        num =
            Maybe.withDefault 0 <| String.toInt number

        ( tooltip, icon, toFollow ) =
            if following == 0 then
                ( "start following " ++ resourceType ++ " logs", FeatherIcons.play, num )

            else if following == num then
                ( "stop following " ++ resourceType ++ " logs", FeatherIcons.pause, 0 )

            else
                ( "start following " ++ resourceType ++ " logs", FeatherIcons.play, num )
    in
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , Util.testAttribute <| "follow-logs-" ++ number
        , onClick <| followStep toFollow
        , attribute "aria-label" <| tooltip ++ " for " ++ resourceType ++ " " ++ number
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
            div [ class "error hidden-spacer", Util.testAttribute "build-spacer" ]
                [ span [ class "label" ] [ text "No Errors" ]
                , span [ class "message" ]
                    [ text "This div is hidden to occupy space for a consistent experience" ]
                ]



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


{-| buildAnimation : takes build info and returns div containing styled flair based on running status
-}
buildAnimation : Status -> Int -> Html msgs
buildAnimation buildStatus buildNumber =
    case buildStatus of
        Vela.Running ->
            div [ class "build-animation" ] <| topParticles buildNumber ++ bottomParticles buildNumber

        _ ->
            div [ class "build-animation", class "-not-running", statusToClass buildStatus ] []


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


{-| styleAttributesAnsi : takes Ansi.Log.Style and renders it into ANSI style Html attributes
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled in unmodified because elm-ansi does not expose it
-}
styleAttributesAnsi : Ansi.Log.Style -> List (Html.Attribute msg)
styleAttributesAnsi logStyle =
    [ style "font-weight"
        (if logStyle.bold then
            "bold"

         else
            "normal"
        )
    , style "text-decoration"
        (if logStyle.underline then
            "underline"

         else
            "none"
        )
    , style "font-style"
        (if logStyle.italic then
            "italic"

         else
            "normal"
        )
    , let
        fgClasses =
            colorClassesAnsi "-fg"
                logStyle.bold
                (if not logStyle.inverted then
                    logStyle.foreground

                 else
                    logStyle.background
                )

        bgClasses =
            colorClassesAnsi "-bg"
                logStyle.bold
                (if not logStyle.inverted then
                    logStyle.background

                 else
                    logStyle.foreground
                )

        fgbgClasses =
            List.map (\a -> (\b c -> ( b, c )) a True) (fgClasses ++ bgClasses)

        ansiClasses =
            [ ( "ansi-blink", logStyle.blink )
            , ( "ansi-faint", logStyle.faint )
            , ( "ansi-Fraktur", logStyle.fraktur )
            , ( "ansi-framed", logStyle.framed )
            ]
      in
      classList (fgbgClasses ++ ansiClasses)
    ]


{-| colorClassesAnsi : takes style parameters and renders it into ANSI styled color classes that can be used with the Html style attribute
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled unmodified in because elm-ansi does not expose it
-}
colorClassesAnsi : String -> Bool -> Maybe Ansi.Color -> List String
colorClassesAnsi suffix bold mc =
    let
        brightPrefix =
            "ansi-bright-"

        prefix =
            if bold then
                brightPrefix

            else
                "ansi-"
    in
    case mc of
        Nothing ->
            if bold then
                [ "ansi-bold" ]

            else
                []

        Just Ansi.Black ->
            [ prefix ++ "black" ++ suffix ]

        Just Ansi.Red ->
            [ prefix ++ "red" ++ suffix ]

        Just Ansi.Green ->
            [ prefix ++ "green" ++ suffix ]

        Just Ansi.Yellow ->
            [ prefix ++ "yellow" ++ suffix ]

        Just Ansi.Blue ->
            [ prefix ++ "blue" ++ suffix ]

        Just Ansi.Magenta ->
            [ prefix ++ "magenta" ++ suffix ]

        Just Ansi.Cyan ->
            [ prefix ++ "cyan" ++ suffix ]

        Just Ansi.White ->
            [ prefix ++ "white" ++ suffix ]

        Just Ansi.BrightBlack ->
            [ brightPrefix ++ "black" ++ suffix ]

        Just Ansi.BrightRed ->
            [ brightPrefix ++ "red" ++ suffix ]

        Just Ansi.BrightGreen ->
            [ brightPrefix ++ "green" ++ suffix ]

        Just Ansi.BrightYellow ->
            [ brightPrefix ++ "yellow" ++ suffix ]

        Just Ansi.BrightBlue ->
            [ brightPrefix ++ "blue" ++ suffix ]

        Just Ansi.BrightMagenta ->
            [ brightPrefix ++ "magenta" ++ suffix ]

        Just Ansi.BrightCyan ->
            [ brightPrefix ++ "cyan" ++ suffix ]

        Just Ansi.BrightWhite ->
            [ brightPrefix ++ "white" ++ suffix ]
