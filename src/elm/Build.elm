{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Build exposing
    ( viewBuildHistory
    , viewBuildItem
    , viewFullBuild
    , viewRepositoryBuilds
    )

import Base64 exposing (decode)
import DateFormat.Relative exposing (relativeTime)
import Html exposing (Html, a, code, details, div, h1, p, span, summary, text)
import Html.Attributes exposing (attribute, class, classList, href)
import Http exposing (Error(..))
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (buildStatusToIcon, recentBuildStatusToIcon, stepStatusToIcon)
import Time exposing (Posix, Zone, millisToPosix)
import Util
import Vela
    exposing
        ( Build
        , Builds
        , Log
        , Logs
        , Org
        , Repo
        , Status
        , Step
        , Steps
        )



-- VIEW


{-| viewRepositoryBuilds : renders builds
-}
viewRepositoryBuilds : WebData Builds -> Posix -> String -> String -> Html msg
viewRepositoryBuilds model now org repo =
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
    case model of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <| List.map (\build -> viewBuildItem now org repo build) builds

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            div []
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
        icon =
            buildStatusToIcon build.status

        status =
            [ icon
                |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []
            ]

        commit =
            [ text "commit ", a [ href build.source ] [ text <| trimCommitHash build.commit ] ]

        branch =
            [ a [ href <| buildBranchUrl build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        id =
            [ a [ Util.testAttribute "build-number", Routes.href <| Routes.Build org repo <| String.fromInt build.number ] [ text <| "#" ++ String.fromInt build.number ] ]

        age =
            [ text <| relativeTime now <| Time.millisToPosix <| Util.secondsToMillis build.created ]

        duration =
            [ text <| formatRunTime now build.started build.finished ]

        statusClass =
            animationStatusClass build.status

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
viewFullBuild : Posix -> Org -> Repo -> WebData Build -> WebData Steps -> Logs -> Html msg
viewFullBuild now org repo build steps logs =
    let
        buildPreview =
            case build of
                RemoteData.Success bld ->
                    viewBuildItem now org repo bld

                _ ->
                    Util.largeLoader

        buildSteps =
            case steps of
                RemoteData.Success steps_ ->
                    viewSteps now steps_ logs

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
viewSteps : Posix -> Steps -> Logs -> Html msg
viewSteps now steps logs =
    div [ class "steps" ]
        [ div [ class "-items", Util.testAttribute "steps" ] <|
            List.map
                (\step ->
                    viewStep now step steps logs
                )
            <|
                List.sortBy (\step -> step.number) <|
                    steps
        ]


{-| viewStep : renders single build step
-}
viewStep : Posix -> Step -> Steps -> Logs -> Html msg
viewStep now step steps logs =
    div [ stepClasses step steps, Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ viewStepIcon step ] ]
        , div [ classList [ ( "-view", True ), ( "-running", step.status == Vela.Running ) ] ] [ viewStepDetails now step logs ]
        ]


{-| viewStepDetails : renders build steps detailed information
-}
viewStepDetails : Posix -> Step -> Logs -> Html msg
viewStepDetails now step logs =
    let
        stepSummary =
            [ summary [ class "summary", Util.testAttribute "step-header" ]
                [ div [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| formatRunTime now step.started step.finished ]
                    ]
                ]
            , viewStepLogs step logs
            ]
    in
    details [ class "details" ] stepSummary


{-| viewStepIcon : renders a build step status icon
-}
viewStepIcon : Step -> Html msg
viewStepIcon step =
    stepStatusToIcon step.status |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []


{-| viewStepLogs : takes step and logs and renders step logs or step error
-}
viewStepLogs : Step -> Logs -> Html msg
viewStepLogs step logs =
    case step.status of
        Vela.Error ->
            div [ class "log", class "error", Util.testAttribute "step-error" ]
                [ span [ class "label" ] [ text "error:" ]
                , span [ class "message" ]
                    [ text <|
                        if String.isEmpty step.error then
                            "no error msg"

                        else
                            step.error
                    ]
                ]

        _ ->
            viewLogs <| getStepLog step logs


{-| viewLogs : renders a build step logs
-}
viewLogs : Maybe Log -> Html msg
viewLogs log =
    let
        decoded =
            decodeLog log

        content =
            if logNotEmpty decoded then
                div [ Util.testAttribute "logs" ] <|
                    List.indexedMap
                        (\idx ->
                            \line ->
                                div []
                                    [ div [ class "-code" ]
                                        [ span [ class "-line-num" ]
                                            [ text <| toTwoDigits <| idx + 1 ]
                                        , code [] [ text line ]
                                        ]
                                    ]
                        )
                    <|
                        List.filter (\line -> not <| String.isEmpty line) <|
                            String.lines decoded

            else
                code [] [ text "No logs for this step." ]
    in
    div [ class "log" ] [ content ]


{-| viewBuildHistory : takes the 10 most recent builds and renders icons/links back to them as a widget at the top of the Build page
-}
viewBuildHistory : Posix -> Zone -> Page -> Org -> Repo -> WebData Builds -> Html msg
viewBuildHistory now timezone page org repo builds =
    let
        show =
            case page of
                Pages.Build _ _ _ ->
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
                            List.take 10 blds

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
        , Routes.href <| Routes.Build org repo <| String.fromInt build.number
        , attribute "aria-label" <| "go to previous build number " ++ String.fromInt build.number
        ]
        [ icon |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []
        , div [ class "-tooltip", Util.testAttribute "build-history-tooltip" ]
            [ div [ class "-info" ]
                [ div [ class "-line", class "-header" ]
                    [ span [ class "-number" ] [ text <| String.fromInt build.number ]
                    , span [ class "-event" ] [ text build.event ]
                    ]
                , div [ class "-line" ] [ span [ class "-label" ] [ text "started:" ], span [ class "-content" ] [ text <| Util.dateToHumanReadable timezone build.started ] ]
                , div [ class "-line" ] [ span [ class "-label" ] [ text "finished:" ], span [ class "-content" ] [ text <| Util.dateToHumanReadable timezone build.finished ] ]
                , div [ class "-line" ] [ span [ class "-label" ] [ text "duration:" ], span [ class "-content" ] [ text <| formatRunTime now build.started build.finished ] ]
                ]
            ]
        ]



-- HELPERS


{-| animationStatusClass : takes build status and returns the appropriate css class
-}
animationStatusClass : Status -> Html.Attribute msg
animationStatusClass status =
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
            class "-failure"


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
                    [ div [ class "build-animation", class "-not-running", animationStatusClass buildStatus ] []
                    ]
    in
    List.append animation markdown


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
    [ SvgBuilder.buildStatusAnimation "" y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-0", "-top", "-cover" ]
    , SvgBuilder.buildStatusAnimation "none" y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-0", "-top", "-start" ]
    , SvgBuilder.buildStatusAnimation dashes y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-1", "-top", "-running" ]
    , SvgBuilder.buildStatusAnimation dashes y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-2", "-top", "-running" ]
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
    [ SvgBuilder.buildStatusAnimation "" y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-0", "-bottom", "-cover" ]
    , SvgBuilder.buildStatusAnimation "none" y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-0", "-bottom", "-start" ]
    , SvgBuilder.buildStatusAnimation dashes y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-1", "-bottom", "-running" ]
    , SvgBuilder.buildStatusAnimation dashes y
        |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] [ "-frame-2", "-bottom", "-running" ]
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


{-| formatRunTime : calculates build runtime using current application time and build times
-}
formatRunTime : Posix -> Int -> Int -> String
formatRunTime now started finished =
    let
        runtime =
            buildRunTime now started finished

        minutes =
            runTimeMinutes runtime

        seconds =
            runTimeSeconds runtime
    in
    String.join ":" [ minutes, seconds ]


{-| buildRunTime : calculates build runtime using current application time and build times, returned in seconds
-}
buildRunTime : Posix -> Int -> Int -> Int
buildRunTime now started finished =
    let
        start =
            started

        end =
            if finished /= 0 then
                finished

            else if started == 0 then
                start

            else
                Util.millisToSeconds <| Time.posixToMillis now
    in
    end - start


{-| runTimeMinutes : takes runtime in seconds, extracts minutes, and pads with necessary 0's
-}
runTimeMinutes : Int -> String
runTimeMinutes seconds =
    toTwoDigits <| seconds // 60


{-| runTimeSeconds : takes runtime in seconds, extracts seconds, and pads with necessary 0's
-}
runTimeSeconds : Int -> String
runTimeSeconds seconds =
    toTwoDigits <| Basics.remainderBy 60 seconds


{-| toTwoDigits : takes an integer of time and pads with necessary 0's

    0  seconds -> "00"
    9  seconds -> "09"
    15 seconds -> "15"

-}
toTwoDigits : Int -> String
toTwoDigits int =
    String.padLeft 2 '0' <| String.fromInt int


{-| stepClasses : returns css classes for a particular step
-}
stepClasses : Step -> Steps -> Html.Attribute msg
stepClasses step steps =
    let
        last =
            case List.head steps of
                Just s ->
                    s.number

                Nothing ->
                    -1
    in
    classList [ ( "step", True ), ( "-line", True ), ( "-last", last == step.number ) ]


{-| decodeLog : returns a string from a Maybe Log and decodes it from base64
-}
decodeLog : Maybe Log -> String
decodeLog log =
    case decode <| toString log of
        Ok str ->
            str

        Err _ ->
            ""


{-| toString : returns a string from a Maybe Log
-}
toString : Maybe Log -> String
toString log =
    case log of
        Just log_ ->
            log_.data

        Nothing ->
            ""


{-| logNotEmpty : takes log string and returns True if content exists
-}
logNotEmpty : String -> Bool
logNotEmpty log =
    not << String.isEmpty <| String.replace " " "" log


{-| getStepLog : takes step and logs and returns the log corresponding to that step
-}
getStepLog : Step -> Logs -> Maybe Log
getStepLog step logs =
    List.head (List.filter (\log -> log.step_id == step.id) logs)
