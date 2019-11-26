{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Hooks exposing (view)

import Build exposing (statusToClass, statusToString)
import Dict
import FeatherIcons
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
        ( class
        , classList
        , href
        )
import Html.Events exposing (onClick)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import Time exposing (Posix)
import Util
import Vela
    exposing
        ( Build
        , BuildIdentifier
        , BuildNumber
        , Hook
        , HookBuilds
        , Hooks
        , Org
        , Repo
        )


{-| view : renders hooks
-}
view : WebData Hooks -> HookBuilds -> Posix -> String -> String -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
view hooks hookBuilds now org repo msg =
    let
        none =
            div []
                [ h1 []
                    [ text "No Hooks Found"
                    ]
                , p []
                    [ text <|
                        "Vela hooks belonging to this repo will display here."
                    ]
                ]
    in
    case hooks of
        RemoteData.Success hooks_ ->
            if List.length hooks_ == 0 then
                none

            else
                let
                    last =
                        case List.head <| List.reverse hooks_ of
                            Just h ->
                                h.id

                            Nothing ->
                                -1
                in
                div [ class "hooks", Util.testAttribute "hooks" ] <|
                    List.append
                        [ div [ class "hook-row", class "headers" ]
                            [ div [ class "header", class "source-id" ]
                                [ text "source id"
                                ]
                            , div [ class "header" ]
                                [ text "status"
                                ]
                            , div [ class "header" ]
                                [ text "created"
                                ]
                            , div [ class "header" ]
                                [ text "host"
                                ]
                            , div [ class "header" ]
                                [ text "event"
                                ]
                            , div [ class "header" ]
                                [ text "branch"
                                ]
                            ]
                        ]
                    <|
                        List.map (\hook -> viewHook now org repo hook hookBuilds (last == hook.id) msg) hooks_

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching hooks for this repository, please try again later!"
                    ]
                ]


viewHook : Posix -> Org -> Repo -> Hook -> HookBuilds -> Bool -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
viewHook now org repo hook hookBuilds last clickAction =
    let
        h =
            div [ class "hook-row" ]
                [ div [ class "detail", class "source-id" ]
                    [ text hook.source_id
                    ]
                , div [ class "detail" ]
                    [ span [ class "status", hookStatusClass hook.status ]
                        [ text hook.status ]
                    ]
                , div [ class "detail", class "created" ]
                    [ text <| Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created
                    ]
                , div [ class "detail", class "host" ]
                    [ text hook.host
                    ]
                , div [ class "detail", class "event" ]
                    [ text hook.event
                    ]
                , div [ class "detail", class "branch" ]
                    [ text hook.branch
                    ]
                ]
    in
    details [ class "hook" ]
        [ summary [ class "hook-summary", onClick (clickAction org repo <| String.fromInt hook.build_id) ]
            [ h
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , hookSummary now ( org, repo, String.fromInt hook.build_id ) hookBuilds "No logs to display" last
        ]


hookSummary : Posix -> BuildIdentifier -> HookBuilds -> String -> Bool -> Html msg
hookSummary now buildIdentifier hookBuilds logs last =
    div [ classList [ ( "summary", True ), ( "-last", last ) ] ]
        [ code []
            [ hookBuild now buildIdentifier hookBuilds
            ]
        , div [ class "logs" ] [ code [] [ text logs ] ]
        ]


hookBuild : Posix -> BuildIdentifier -> HookBuilds -> Html msg
hookBuild now ( org, repo, buildNumber ) hookBuilds =
    case fromID ( org, repo, buildNumber ) hookBuilds of
        NotAsked ->
            text ""

        Failure _ ->
            div [ class "error" ] [ text <| "error fetching build " ++ String.join "/" [ org, repo, buildNumber ] ]

        Loading ->
            div [ class "loading" ] [ Util.smallLoaderWithText "loading build..." ]

        Success build ->
            viewHookBuild now ( org, repo, buildNumber ) build


viewHookBuild : Posix -> BuildIdentifier -> Build -> Html msg
viewHookBuild now ( org, repo, buildNumber ) build =
    div [ class "hook-build" ]
        [ text "build:"
        , a [ class "item", Routes.href <| Routes.Build org repo buildNumber ] [ text buildNumber ]
        , span []
            [ span []
                [ text "status:"
                ]
            , span [ statusToClass build.status, class "item", class "status" ] [ text <| statusToString build.status ]
            ]
        , span []
            [ span []
                [ text "duration:"
                ]
            , span [ statusToClass build.status, class "item", class "duration" ] [ text <| Util.formatRunTime now build.started build.finished ]
            ]
        ]


hookStatusClass : String -> Html.Attribute msg
hookStatusClass status =
    case status of
        "success" ->
            class "-success"

        _ ->
            class "-failure"


fromID : BuildIdentifier -> HookBuilds -> WebData Build
fromID buildIdentifier hookBuilds =
    Maybe.withDefault NotAsked <| Dict.get buildIdentifier hookBuilds
