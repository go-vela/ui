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
            div []
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
        [ div [ class "header", class "source-id" ] [ text "source id" ]
        , div [ class "header" ] [ text "created" ]
        , div [ class "header" ] [ text "status" ]
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
    details [ class "row" ]
        [ summary [ class "hook-summary", onClick (clickAction org repo <| String.fromInt hook.build_id) ]
            [ preview now hook ]
        , info now ( org, repo, String.fromInt hook.build_id ) hook hookBuilds
        ]


{-| chevron : renders the expansion chevron icon
-}
chevron : Html msg
chevron =
    FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "chevron" |> FeatherIcons.toHtml []


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Posix -> Hook -> Html msg
preview now hook =
    div [ class "row", class "preview" ]
        [ chevron
        , cell hook.source_id (Just <| class "source-id") Nothing
        , cell (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created) (Just <| class "created") Nothing
        , cell hook.status Nothing <| Just <| classList [ ( "status", True ), ( hookStatus hook.status, True ) ]
        , cell hook.host (Just <| class "host") Nothing
        , cell hook.event (Just <| class "event") Nothing
        , cell hook.branch (Just <| class "branch") Nothing
        ]


{-| cell : takes text and maybe attributes and renders cell data for hooks table row
-}
cell : String -> Maybe (Html.Attribute msg) -> Maybe (Html.Attribute msg) -> Html msg
cell txt outerAttrs innerAttrs =
    div [ class "cell", Maybe.withDefault (class "") outerAttrs ]
        [ span [ Maybe.withDefault (class "") innerAttrs ] [ text txt ] ]


{-| info : renders the table row details when clicking/expanding a row
-}
info : Posix -> BuildIdentifier -> Hook -> HookBuilds -> Html msg
info now buildIdentifier hook hookBuilds =
    case fromID buildIdentifier hookBuilds of
        NotAsked ->
            error hook.error

        Failure _ ->
            div [ class "error" ] [ text <| "error fetching build " ++ buildPath buildIdentifier ]

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
            [ code [ class "element" ]
                [ span [ class "-m-r" ] [ text "build:" ]
                , a [ class "-m-r", Routes.href <| Routes.Build org repo buildNumber ]
                    [ text <| buildPath buildIdentifier
                    ]
                ]
            , code [ class "element" ]
                [ span [ class "-m-l", class "-m-r" ] [ text "status:" ]
                , span [ statusToClass b.status, class "-m-r", class "status" ]
                    [ text <| statusToString b.status
                    ]
                ]
            , code [ class "element" ]
                [ span [ class "-m-l", class "-m-r" ] [ text "duration:" ]
                , span [ statusToClass b.status, class "-m-r", class "duration" ]
                    [ text <| Util.formatRunTime now b.started b.finished
                    ]
                ]
            ]
        ]


{-| error : renders hook error
-}
error : String -> Html msg
error err =
    if not <| String.isEmpty err then
        div [ class "info", class "-failure" ]
            [ div [ class "wrapper" ]
                [ code [ class "element" ]
                    [ span [ class "-m-r" ] [ text "error:" ]
                    , span [ class "-error" ]
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
fromID : BuildIdentifier -> HookBuilds -> WebData Build
fromID buildIdentifier hookBuilds =
    Maybe.withDefault NotAsked <| Dict.get buildIdentifier hookBuilds


{-| hookStatus : takes hook status and maps it to a string, for strict typing.
TODO: this is used while finalizing Hook Status logic.
-}
hookStatus : String -> String
hookStatus status =
    case status of
        "success" ->
            "success"

        _ ->
            "failure"
