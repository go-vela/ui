{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build exposing
    ( Msgs
    , PartialModel
    , clickLogLine
    , clickStep
    , statusToClass
    , statusToString
    , viewBuild
    , viewBuildHistory
    , viewPreview
    , viewingStep
    )

import Browser.Navigation as Navigation
import DateFormat.Relative exposing (relativeTime)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , details
        , div
        , em
        , li
        , span
        , summary
        , text
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
import List.Extra exposing (updateIf)
import Logs exposing (SetLogFocus, stepToFocusId)
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
    Org -> Repo -> BuildNumber -> StepNumber -> String -> msg


{-| FocusLogs : type alias for passing in url fragment to focus ranges of logs
-}
type alias FocusLogs msg =
    String -> msg


{-| PartialModel : type alias for passing in the main model with the navigation key for pushing log fragment urls
-}
type alias PartialModel =
    { navigationKey : Navigation.Key
    , time : Posix
    , build : WebData Build
    , steps : WebData Steps
    , logs : Logs
    , shift : Bool
    }


{-| Msgs : record for routing msg updates to Main.elm
-}
type alias Msgs msg =
    { expandAction : ExpandStep msg
    , logFocusAction : FocusLogs msg
    }



-- VIEW
--  , Pages.Build.viewBuild model.time org repo model.build model.steps model.logs ClickStep UpdateUrl model.shift


{-| viewBuild : renders entire build based on current application time
-}
viewBuild : PartialModel -> Org -> Repo -> Msgs msg -> Html msg
viewBuild { time, build, steps, logs, shift } org repo { expandAction, logFocusAction } =
    let
        ( buildPreview, buildNumber ) =
            case build of
                RemoteData.Success bld ->
                    ( viewPreview time org repo bld, Just <| String.fromInt bld.number )

                RemoteData.Loading ->
                    ( Util.largeLoader, Nothing )

                _ ->
                    ( text "", Nothing )

        buildSteps =
            case steps of
                RemoteData.Success steps_ ->
                    viewSteps time org repo buildNumber steps_ logs expandAction logFocusAction shift

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
viewPreview : Posix -> Org -> Repo -> Build -> Html msg
viewPreview now org repo build =
    let
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
                , viewError build
                ]
            ]
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ] <|
            buildStatusStyles markdown build.status build.number
        ]


{-| viewSteps : sorts and renders build steps
-}
viewSteps : Posix -> Org -> Repo -> Maybe BuildNumber -> Steps -> Logs -> ExpandStep msg -> SetLogFocus msg -> Bool -> Html msg
viewSteps now org repo buildNumber steps logs expandAction logFocusAction shift =
    div [ class "steps" ]
        [ div [ class "-items", Util.testAttribute "steps" ] <|
            List.map
                (\step ->
                    viewStep now org repo buildNumber step steps logs expandAction logFocusAction shift
                )
            <|
                steps
        ]


{-| viewStep : renders single build step
-}
viewStep : Posix -> Org -> Repo -> Maybe BuildNumber -> Step -> Steps -> Logs -> ExpandStep msg -> SetLogFocus msg -> Bool -> Html msg
viewStep now org repo buildNumber step steps logs expandAction logFocusAction shift =
    div [ stepClasses step steps, Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStepIcon step ] ]
        , viewStepDetails now org repo buildNumber step logs expandAction logFocusAction shift
        ]


{-| viewStepDetails : renders build steps detailed information
-}
viewStepDetails : Posix -> Org -> Repo -> Maybe BuildNumber -> Step -> Logs -> ExpandStep msg -> SetLogFocus msg -> Bool -> Html msg
viewStepDetails now org repo buildNumber step logs expandAction logFocusAction shift =
    let
        buildNum =
            Maybe.withDefault "" buildNumber

        stepNumber =
            String.fromInt step.number

        stepSummary =
            [ summary
                [ class "summary"
                , Util.testAttribute "step-header"
                , onClick <| expandAction org repo buildNum stepNumber ("#step:" ++ stepNumber)
                , id <| stepToFocusId <| String.fromInt step.number
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime now step.started step.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                ]
            , div [ class "logs-container" ] [ Logs.view step logs logFocusAction shift ]
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



-- UPDATE HELPERS


{-| clickStep : takes model org repo and step number and fetches step information from the api
-}
clickStep : WebData Steps -> StepNumber -> ( WebData Steps, Bool )
clickStep steps stepNumber =
    let
        ( stepsOut, action ) =
            case steps of
                RemoteData.Success steps_ ->
                    ( RemoteData.succeed <| toggleStepView steps_ stepNumber
                    , True
                    )

                _ ->
                    ( steps, False )
    in
    ( stepsOut
    , action
    )


{-| clickLogLine : takes model and line number and sets the focus on the log line
-}
clickLogLine : WebData Steps -> Navigation.Key -> StepNumber -> Maybe Int -> ( WebData Steps, Cmd msg )
clickLogLine steps navKey stepNumber lineNumber =
    let
        stepOpened =
            Maybe.withDefault False <|
                List.head <|
                    List.map (\step -> not step.viewing) <|
                        List.filter (\step -> String.fromInt step.number == stepNumber) <|
                            RemoteData.withDefault [] steps
    in
    ( steps
    , if stepOpened then
        Navigation.pushUrl navKey <|
            "#step:"
                ++ stepNumber
                ++ (case lineNumber of
                        Just line ->
                            ":"
                                ++ String.fromInt line

                        Nothing ->
                            ""
                   )

      else
        Cmd.none
    )


{-| toggleStepView : takes steps and step number and toggles that steps viewing state
-}
toggleStepView : Steps -> String -> Steps
toggleStepView steps stepNumber =
    List.Extra.updateIf
        (\step -> String.fromInt step.number == stepNumber)
        (\step -> { step | viewing = not step.viewing })
        steps


{-| viewingStep : takes steps and step number and returns the step viewing state
-}
viewingStep : WebData Steps -> StepNumber -> Bool
viewingStep steps stepNumber =
    Maybe.withDefault False <|
        List.head <|
            List.map (\step -> step.viewing) <|
                List.filter (\step -> String.fromInt step.number == stepNumber) <|
                    RemoteData.withDefault [] steps
