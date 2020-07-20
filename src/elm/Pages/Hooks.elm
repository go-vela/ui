{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Hooks exposing (hookStatus, receiveHookBuild, view)

import Dict
import Errors exposing (viewResourceError)
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
        , small
        , span
        , summary
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , scope
        )
import Html.Events exposing (onClick)
import Pages.Build exposing (statusToClass, statusToString)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder exposing (hookStatusToIcon)
import Table
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
        , HooksModel
        , Org
        , Repo
        , Viewing
        )


{-| PartialModel : type alias for passing in the main model with partial fields
-}
type alias PartialModel =
    { hooks : HooksModel
    , hookBuilds : HookBuilds
    , time : Posix
    }



-- VIEW


{-| view : renders hooks
-}
view : PartialModel -> String -> String -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
view { hooks, hookBuilds, time } org repo clickAction =
    case hooks.hooks of
        RemoteData.Success hooks_ ->
            div []
                [ Table.view
                    (Table.Config
                        "Hooks"
                        "hooks"
                        "No hooks found for this organization/repo"
                        tableHeaders
                        (hooksToRows time hooks_)
                        Nothing
                    )
                ]

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            viewResourceError { resourceLabel = "hooks for this repository", testLabel = "hooks" }


{-| hooksToRows : takes list of hooks and produces list of Table rows
-}
hooksToRows : Posix -> Hooks -> Table.Rows Hook msg
hooksToRows now hooks =
    hooks
        |> List.map (\hook -> [ Just <| Table.Row hook (renderHook now), hookErrorRow hook ])
        |> List.concat
        |> List.filterMap identity


hookErrorRow : Hook -> Maybe (Table.Row Hook msg)
hookErrorRow hook =
    if not <| String.isEmpty hook.error then
        Just <| Table.Row hook renderHookError

    else
        Nothing


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : Table.Columns
tableHeaders =
    [ ( Just "-icon", "" )
    , ( Nothing, "source" )
    , ( Nothing, "created" )
    , ( Nothing, "host" )
    , ( Nothing, "event" )
    , ( Nothing, "branch" )
    ]


{-| renderHook : takes hook and renders a table row
-}
renderHook : Posix -> Hook -> Html msg
renderHook now hook =
    tr [ Util.testAttribute <| "secrets-row" ]
        [ td
            [ attribute "data-label" "status"
            , scope "row"
            , class "-line-break"
            , class "-icon"
            ]
            [ hookStatusToIcon hook.status ]
        , td
            [ attribute "data-label" "source-id"
            , scope "row"
            , class "-line-no-break"
            ]
            [ small [] [ code [ class "source-id" ] [ text hook.source_id ] ] ]
        , td
            [ attribute "data-label" "created"
            , scope "row"
            , class "-line-break"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created) ]
        , td
            [ attribute "data-label" "host"
            , scope "row"
            , class "-line-break"
            ]
            [ text hook.host ]
        , td
            [ attribute "data-label" "event"
            , scope "row"
            , class "-line-break"
            ]
            [ text hook.event ]
        , td
            [ attribute "data-label" "branch"
            , scope "row"
            , class "-line-break"
            ]
            [ text hook.branch ]
        ]


renderHookError : Hook -> Html msg
renderHookError hook =
    tr [] [ td [ attribute "colspan" "5" ] [ text hook.error ] ]


{-| hooksTable : renders hooks table
-}
hooksTable : Posix -> Org -> Repo -> HookBuilds -> Hooks -> (Org -> Repo -> BuildNumber -> msg) -> List (Html msg)
hooksTable now org repo hookBuilds hooks clickAction =
    [ renderLabel
    , headers
    ]
        ++ rows now org repo hookBuilds hooks clickAction


renderLabel : Html msg
renderLabel =
    div [ class "table-label" ] [ text "Hooks" ]


{-| headers : renders hooks table headers
-}
headers : Html msg
headers =
    div [ class "headers" ]
        [ div [ class "header", class "source-id" ] [ text "source id" ]
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
    details ([ class "details", class "-no-pad", Util.testAttribute "hook" ] ++ (Util.open <| hookOpen ( org, repo, String.fromInt hook.build_id ) hookBuilds))
        [ summary [ class "summary", onClick (clickAction org repo <| String.fromInt hook.build_id) ]
            [ preview now hook ]
        , info now ( org, repo, String.fromInt hook.build_id ) hook hookBuilds
        ]


{-| firstCell : renders the expansion chevron icon
-}
firstCell : String -> Html msg
firstCell status =
    div [ class "first-cell" ]
        [ FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
        , hookStatusToIcon status
        ]


{-| preview : renders the hook preview displayed as the clickable row
-}
preview : Posix -> Hook -> Html msg
preview now hook =
    div [ class "row", class "preview" ]
        [ firstCell hook.status
        , sourceId hook
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


{-| sourceId : takes text and maybe attributes and renders cell data for hooks table row
-}
sourceId : Hook -> Html msg
sourceId hook =
    div [ class "cell", class "source-id" ]
        [ small [] [ code [ class "text" ] [ text hook.source_id ] ]
        ]


{-| info : renders the table row details when clicking/expanding a row
-}
info : Posix -> BuildIdentifier -> Hook -> HookBuilds -> Html msg
info now buildIdentifier hook hookBuilds =
    case Tuple.first <| fromId buildIdentifier hookBuilds of
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
                    , a
                        [ Util.testAttribute "build-link"
                        , class "-m-r"
                        , Routes.href <| Routes.Build org repo buildNumber Nothing
                        ]
                        [ text <| buildPath buildIdentifier
                        ]
                    ]
                ]
            , div []
                [ code [ class "element" ]
                    [ span [ class "-m-r" ] [ text "status:" ]
                    , span [ class "hook-build-status", statusToClass b.status, class "-m-r" ]
                        [ text <| statusToString b.status
                        ]
                    ]
                ]
            , div []
                [ code [ class "element" ]
                    [ span [ class "-m-r" ] [ text "duration:" ]
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


{-| fromId : takes build identifier and hook builds and returns the potential build
-}
fromId : BuildIdentifier -> HookBuilds -> ( WebData Build, Viewing )
fromId buildIdentifier hookBuilds =
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


{-| receiveHookBuild : takes org repo build and updates the appropriate build within hookbuilds
-}
receiveHookBuild : BuildIdentifier -> WebData Build -> HookBuilds -> HookBuilds
receiveHookBuild buildIdentifier b hookBuilds =
    Dict.update buildIdentifier (\_ -> Just ( b, viewingHook buildIdentifier hookBuilds )) hookBuilds


viewingHook : BuildIdentifier -> HookBuilds -> Bool
viewingHook buildIdentifier hookBuilds =
    case Dict.get buildIdentifier hookBuilds of
        Just ( _, viewing ) ->
            viewing

        Nothing ->
            False
