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
        , href
        )
import Html.Events exposing (onClick)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (hookStatusToIcon)
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
        , Viewing
        )



-- VIEW


{-| view : renders hooks
-}
view : WebData Hooks -> HookBuilds -> Posix -> String -> String -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
view hooks hookBuilds now org repo clickAction =
    case hooks of
        RemoteData.Success hooks_ ->
            if List.length hooks_ == 0 then
                noHooks

            else
                div [ class "hooks", Util.testAttribute "hooks" ] <|
                    hooksTable now org repo hookBuilds hooks_ clickAction

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            div [ Util.testAttribute "hooks-error" ]
                [ p []
                    [ text <|
                        "There was an error fetching hooks for this repository, please try again later!"
                    ]
                ]


{-| hooksTable : renders hooks table
-}
hooksTable : Posix -> Org -> Repo -> HookBuilds -> Hooks -> (Org -> Repo -> BuildNumber -> msg) -> List (Html msg)
hooksTable now org repo hookBuilds hooks clickAction =
    headers :: rows now org repo hookBuilds hooks clickAction


{-| headers : renders hooks table headers
-}
headers : Html msg
headers =
    div [ class "headers" ]
        [ div [ class "first-cell" ] [ text "" ]
        , div [ class "header", class "source-id" ] [ text "source id" ]
        , div [ class "header" ] [ text "created" ]
        , div [ class "header" ] [ text "host" ]
        , div [ class "header" ] [ text "event" ]
        , div [ class "header" ] [ text "branch" ]
        ]


{-| rows : renders hooks table rows
-}
rows : Posix -> Org -> Repo -> HookBuilds -> Hooks -> (Org -> Repo -> BuildNumber -> msg) -> List (Html msg)
rows now org repo hookBuilds hooks clickAction =
    List.map (\hook -> row now org repo hook hookBuilds clickAction) hooks


{-| row : renders hooks table row wrapped in details element
-}
row : Posix -> Org -> Repo -> Hook -> HookBuilds -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
row now org repo hook hookBuilds clickAction =
    details [ class "row", Util.testAttribute "hook", Util.open <| hookOpen ( org, repo, String.fromInt hook.build_id ) hookBuilds ]
        [ summary [ class "hook-summary", onClick (clickAction org repo <| String.fromInt hook.build_id) ]
            [ preview now hook ]
        , info now ( org, repo, String.fromInt hook.build_id ) hook hookBuilds
        ]


{-| firstCell : renders the expansion chevron icon
-}
firstCell : String -> Html msg
firstCell status =
    div [ class "first-cell" ]
        [ FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "chevron" |> FeatherIcons.toHtml []
        , hookStatusToIcon status
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Posix -> Hook -> Html msg
preview now hook =
    div [ class "row", class "preview" ]
        [ firstCell hook.status
        , sourceID hook
        , cell (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created) <| class "created"
        , cell hook.host <| class "host"
        , cell hook.event <| class "event"
        , cell hook.branch <| class "branch"
        ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Html.Attribute msg -> Html msg
cell txt cls =
    div [ class "cell", cls ]
        [ span [] [ text txt ] ]


{-| sourceID : takes text and maybe attributes and renders cell data for hooks table row
-}
sourceID : Hook -> Html msg
sourceID hook =
    div [ class "cell", class "source-id" ]
        [ code [ class "text" ] [ text hook.source_id ]
        ]


{-| info : renders the table row details when clicking/expanding a row
-}
info : Posix -> BuildIdentifier -> Hook -> HookBuilds -> Html msg
info now buildIdentifier hook hookBuilds =
    case Tuple.first <| fromID buildIdentifier hookBuilds of
        NotAsked ->
            error hook.error

        Failure _ ->
            error "failed to fetch a build for this hook"

        Loading ->
            div [ class "loading" ] [ Util.smallLoaderWithText "loading build..." ]

        Success b ->
            build now buildIdentifier b


{-| build : renders the specific hook build information
-}
build : Posix -> BuildIdentifier -> Build -> Html msg
build now buildIdentifier b =
    let
        ( org, repo, buildNumber ) =
            buildIdentifier
    in
    div [ class "info", statusToClass b.status ]
        [ div [ class "wrapper" ]
            [ div []
                [ code [ class "element" ]
                    [ span [ class "-m-r" ] [ text "build:" ]
                    , a [ Util.testAttribute "build-link", class "-m-r", Routes.href <| Routes.Build org repo buildNumber Nothing ]
                        [ text <| buildPath buildIdentifier
                        ]
                    ]
                ]
            , div []
                [ code [ class "element" ]
                    [ span [ class "-m-l", class "-m-r" ] [ text "status:" ]
                    , span [ class "hook-build-status", statusToClass b.status, class "-m-r" ]
                        [ text <| statusToString b.status
                        ]
                    ]
                ]
            , div []
                [ code [ class "element" ]
                    [ span [ class "-m-l", class "-m-r" ] [ text "duration:" ]
                    , span [ statusToClass b.status, class "-m-r", class "duration" ]
                        [ text <| Util.formatRunTime now b.started b.finished
                        ]
                    ]
                ]
            ]
        ]


{-| error : renders hook failure error msg
-}
error : String -> Html msg
error err =
    if not <| String.isEmpty err then
        div [ class "info", class "-failure" ]
            [ div [ class "wrapper" ]
                [ code [ class "element" ]
                    [ span [ class "error-label", class "-m-r" ] [ text "error:" ]
                    , span [ class "error-text" ]
                        [ text err
                        ]
                    ]
                ]
            ]

    else
        text ""


{-| noHooks : renders the page shown when no hooks are returned by the server
-}
noHooks : Html msg
noHooks =
    div []
        [ h1 []
            [ text "No Hooks Found"
            ]
        , p []
            [ text <|
                "Hook payloads delivered to Vela will display here."
            ]
        ]



-- HELPERS


{-| buildPath : takes build identifier and returns the string path to the build
-}
buildPath : BuildIdentifier -> String
buildPath ( org, repo, buildNumber ) =
    String.join "/" [ org, repo, buildNumber ]


{-| fromID : takes build identifier and hook builds and returns the potential build
-}
fromID : BuildIdentifier -> HookBuilds -> ( WebData Build, Viewing )
fromID buildIdentifier hookBuilds =
    Maybe.withDefault ( NotAsked, False ) <| Dict.get buildIdentifier hookBuilds


{-| hookStatus : takes hook status and maps it to a string, for strict typing.
-}
hookStatus : String -> String
hookStatus status =
    case status of
        "success" ->
            "success"

        _ ->
            "failure"


{-| hookOpen : returns true/false whether hook is being viewed
-}
hookOpen : BuildIdentifier -> HookBuilds -> Bool
hookOpen buildIdentifier hookBuilds =
    Tuple.second <| Maybe.withDefault ( NotAsked, False ) <| Dict.get buildIdentifier hookBuilds
