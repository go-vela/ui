{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Build exposing (view, viewActionsMenu, viewApproveButton, viewCancelButton, viewRestartButton)

import Components.Svgs
import DateFormat.Relative
import FeatherIcons
import Html exposing (Html, a, button, details, div, label, li, span, strong, summary, text, ul)
import Html.Attributes exposing (attribute, class, classList, href, id, title)
import Html.Events exposing (onClick)
import List.Extra
import RemoteData exposing (WebData)
import Route.Path
import Shared
import Time
import Utils.Helpers as Util
import Vela


type alias Props msg =
    { build : WebData Vela.Build
    , showFullTimestamps : Bool
    , actionsMenu : Html msg
    }


view : Shared.Model -> Props msg -> Html msg
view shared props =
    case props.build of
        RemoteData.Success build ->
            let
                ( org, repo ) =
                    Util.orgRepoFromBuildLink build.link

                repoLink =
                    span []
                        [ a
                            [ Route.Path.href <|
                                Route.Path.Org_Repo_
                                    { org = org
                                    , repo = repo
                                    }
                            ]
                            [ text repo ]
                        , text ": "
                        ]

                commit =
                    case build.event of
                        "pull_request" ->
                            [ repoLink
                            , text <| String.replace "_" " " build.event
                            , text " "
                            , a [ href build.source ]
                                [ text "#"
                                , text (Util.getNameFromRef build.ref)
                                ]
                            , text " ("
                            , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                            , text <| ")"
                            ]

                        "tag" ->
                            [ repoLink
                            , text <| String.replace "_" " " build.event
                            , text " "
                            , a [ href build.source ] [ text (Util.getNameFromRef build.ref) ]
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

                buildNumberLink =
                    [ a
                        [ Util.testAttribute "build-number"
                        , href build.link
                        ]
                        [ text <| "#" ++ String.fromInt build.number ]
                    ]

                buildCreatedPosix =
                    Time.millisToPosix <| Util.secondsToMillis build.created

                age =
                    DateFormat.Relative.relativeTime shared.time <| buildCreatedPosix

                timestamp =
                    Util.humanReadableDateTimeFormatter shared.zone buildCreatedPosix

                displayTime =
                    if props.showFullTimestamps then
                        [ text <| timestamp ++ " " ]

                    else
                        [ text age ]

                hoverTime =
                    if props.showFullTimestamps then
                        age

                    else
                        timestamp

                -- calculate build runtime
                runtime =
                    Util.formatRunTime shared.time build.started build.finished

                -- mask completed/pending builds that have not finished
                duration =
                    List.singleton <|
                        text <|
                            case build.status of
                                Vela.Running ->
                                    runtime

                                _ ->
                                    if build.started /= 0 && build.finished /= 0 then
                                        runtime

                                    else
                                        "--:--"
            in
            viewBuildPreview
                { statusIcon = [ Components.Svgs.buildStatusToIcon build.status ]
                , statusClass = statusToClass build.status
                , buildNumberLink = buildNumberLink
                , commitMessage = [ strong [] message ]
                , gitInfo =
                    [ div [ class "commit" ] commit
                    , text "on"
                    , div [ class "branch" ] branch
                    , text "by"
                    , div [ class "sender" ] sender
                    ]
                , displayTime = displayTime
                , duration = duration
                , infoRow = [ viewError build ]
                , buildAnimation = [ buildAnimation build.status build.number ]
                , hoverTitle = title hoverTime
                , viewActionsMenu = props.actionsMenu
                }

        _ ->
            viewBuildPreview
                { statusIcon = [ Components.Svgs.buildStatusToIcon Vela.Pending ]
                , statusClass = statusToClass Vela.Pending
                , buildNumberLink = []
                , commitMessage = []
                , gitInfo = []
                , displayTime = []
                , duration = [ text "--:--" ]
                , infoRow = []
                , buildAnimation = [ buildAnimation Vela.Pending 1 ]
                , hoverTitle = Html.Attributes.class ""
                , viewActionsMenu = Html.div [] []
                }


viewBuildPreview :
    { statusIcon : List (Html msg)
    , statusClass : Html.Attribute msg
    , buildNumberLink : List (Html msg)
    , commitMessage : List (Html msg)
    , gitInfo : List (Html msg)
    , displayTime : List (Html msg)
    , duration : List (Html msg)
    , infoRow : List (Html msg)
    , buildAnimation : List (Html msg)
    , hoverTitle : Html.Attribute msg
    , viewActionsMenu : Html msg
    }
    -> Html msg
viewBuildPreview props =
    div [ class "build-container", Util.testAttribute "build" ]
        [ div
            [ class "build"
            , props.statusClass
            ]
            ([ div
                [ class "status"
                , Util.testAttribute "build-status"
                , props.statusClass
                ]
                props.statusIcon
             , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] props.buildNumberLink
                    , div [ class "commit-msg" ] props.commitMessage
                    ]
                , div [ class "row" ]
                    [ div [ class "git-info" ]
                        props.gitInfo
                    , div [ class "time-info" ]
                        [ div [ class "time-completed" ]
                            [ div
                                [ class "age"
                                , props.hoverTitle
                                ]
                                props.displayTime
                            , span [ class "delimiter" ] [ text " /" ]
                            , div [ class "duration" ] props.duration
                            ]
                        , props.viewActionsMenu
                        ]
                    ]
                , div [ class "row" ] props.infoRow
                ]
             ]
                ++ props.buildAnimation
            )
        ]


viewActionsMenu :
    { msgs :
        { showHideActionsMenus : Maybe Int -> Maybe Bool -> msg
        , restartBuild : { org : String, repo : String, buildNumber : String } -> msg
        }
    , build : Vela.Build
    , showActionsMenus : List Int
    }
    -> Html msg
viewActionsMenu props =
    let
        ( org, repo ) =
            Util.orgRepoFromBuildLink props.build.link

        buildMenuBaseClassList =
            classList
                [ ( "details", True )
                , ( "-marker-right", True )
                , ( "-no-pad", True )
                , ( "build-toggle", True )
                ]

        buildMenuAttributeList =
            Util.open (List.member props.build.id props.showActionsMenus) ++ [ id "build-actions" ]

        viewRestartLink =
            case props.build.status of
                Vela.PendingApproval ->
                    text ""

                _ ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <|
                                props.msgs.restartBuild
                                    { org = org
                                    , repo = repo
                                    , buildNumber = String.fromInt props.build.number
                                    }
                            , Util.testAttribute "restart-build"
                            ]
                            [ text "Restart Build"
                            ]
                        ]

        viewCancelLink =
            case props.build.status of
                Vela.Running ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"

                            -- , Util.onClickPreventDefault <| props.msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                Vela.Pending ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"

                            -- , Util.onClickPreventDefault <| props.msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                Vela.PendingApproval ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"

                            -- , Util.onClickPreventDefault <| props.msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                _ ->
                    text ""

        viewApproveLink =
            case props.build.status of
                Vela.PendingApproval ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"

                            -- , Util.onClickPreventDefault <| props.msgs.approveBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "approve-build"
                            ]
                            [ text "Approve Build"
                            ]
                        ]

                _ ->
                    text ""
    in
    details (buildMenuBaseClassList :: buildMenuAttributeList)
        [ summary
            [ class "summary"
            , Util.onClickPreventDefault (props.msgs.showHideActionsMenus (Just props.build.id) Nothing)
            , Util.testAttribute "build-menu"
            ]
            [ text "Actions"
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml [ attribute "aria-label" "show build actions" ]
            ]
        , ul
            [ class "build-menu"
            , attribute "aria-hidden" "true"
            , attribute "role" "menu"
            ]
            [ viewApproveLink
            , viewRestartLink
            , viewCancelLink
            ]
        ]


{-| viewError : checks for build error and renders message
-}
viewError : Vela.Build -> Html msg
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
            let
                defaultLabel =
                    text "canceled:"

                ( label, message ) =
                    if String.isEmpty build.error then
                        ( defaultLabel, text "no error message" )

                    else
                        let
                            tgtBuild =
                                String.split " " build.error
                                    |> List.Extra.last
                                    |> Maybe.withDefault ""
                        in
                        -- check if the last part of the error message was a number
                        -- to handle auto canceled build messages which come in the
                        -- form of "build was auto canceled in favor of build 42"
                        case String.toInt tgtBuild of
                            -- not an auto cancel message, use the returned error msg
                            Nothing ->
                                ( defaultLabel, text build.error )

                            -- some special treatment to turn build number
                            -- into a link to the respective build
                            Just _ ->
                                let
                                    linkList =
                                        String.split "/" build.link
                                            |> List.reverse

                                    newLink =
                                        linkList
                                            |> List.Extra.setAt 0 tgtBuild
                                            |> List.reverse
                                            |> String.join "/"

                                    msg =
                                        String.replace tgtBuild "" build.error
                                in
                                ( text "auto canceled:"
                                , span [] [ text msg, a [ href newLink, Util.testAttribute "new-build-link" ] [ text ("#" ++ tgtBuild) ] ]
                                )
            in
            div [ class "error", Util.testAttribute "build-error" ]
                [ span [ class "label" ] [ label ]
                , span [ class "message" ] [ message ]
                ]

        _ ->
            div [ class "error hidden-spacer", Util.testAttribute "build-spacer" ]
                [ span [ class "label" ] [ text "No Errors" ]
                , span [ class "message" ]
                    [ text "This div is hidden to occupy space for a consistent experience" ]
                ]


{-| statusToClass : takes build status and returns css class
-}
statusToClass : Vela.Status -> Html.Attribute msg
statusToClass status =
    case status of
        Vela.Pending ->
            class "-pending"

        Vela.PendingApproval ->
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
            class "-canceled"

        Vela.Error ->
            class "-error"


{-| buildAnimation : takes build info and returns div containing styled flair based on running status
-}
buildAnimation : Vela.Status -> Int -> Html msg
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
    [ Components.Svgs.buildStatusAnimation "" y [ "-frame-0", "-top", "-cover" ]
    , Components.Svgs.buildStatusAnimation "none" y [ "-frame-0", "-top", "-start" ]
    , Components.Svgs.buildStatusAnimation dashes y [ "-frame-1", "-top", "-running" ]
    , Components.Svgs.buildStatusAnimation dashes y [ "-frame-2", "-top", "-running" ]
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
    [ Components.Svgs.buildStatusAnimation "" y [ "-frame-0", "-bottom", "-cover" ]
    , Components.Svgs.buildStatusAnimation "none" y [ "-frame-0", "-bottom", "-start" ]
    , Components.Svgs.buildStatusAnimation dashes y [ "-frame-1", "-bottom", "-running" ]
    , Components.Svgs.buildStatusAnimation dashes y [ "-frame-2", "-bottom", "-running" ]
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



-- BUILD


{-| viewCancelButton : takes org repo and build number and renders button to cancel a build
-}
viewCancelButton : Vela.Org -> Vela.Repo -> Vela.BuildNumber -> ({ org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } -> msg) -> Html msg
viewCancelButton org repo buildNumber cancelBuild =
    button
        [ classList
            [ ( "button", True )
            , ( "-outline", True )
            ]
        , onClick <| cancelBuild { org = org, repo = repo, buildNumber = buildNumber }
        , Util.testAttribute "cancel-build"
        ]
        [ text "Cancel Build"
        ]


{-| viewRestartButton : takes org repo and build number and renders button to restart a build
-}
viewRestartButton : Vela.Org -> Vela.Repo -> Vela.BuildNumber -> ({ org : Vela.Org, repo : Vela.Repo, buildNumber : Vela.BuildNumber } -> msg) -> Html msg
viewRestartButton org repo buildNumber restartBuild =
    button
        [ classList
            [ ( "button", True )
            , ( "-outline", True )
            ]
        , onClick <| restartBuild { org = org, repo = repo, buildNumber = buildNumber }
        , Util.testAttribute "restart-build"
        ]
        [ text "Restart Build"
        ]


{-| viewApproveButton: takes org repo and build number and renders button to approve a build run
-}
viewApproveButton : Vela.Org -> Vela.Repo -> WebData Vela.Build -> (Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg) -> Html msg
viewApproveButton org repo build approveBuild =
    case build of
        RemoteData.Success b ->
            let
                approveButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| approveBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "approve-build"
                        ]
                        [ text "Approve Build"
                        ]
            in
            case b.status of
                Vela.PendingApproval ->
                    approveButton

                _ ->
                    text ""

        _ ->
            text ""
