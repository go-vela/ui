{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Hooks exposing (view)

import Ansi.Log
import Array
import Html
    exposing
        ( Html
        , a
        , code
        , div
        , small
        , span
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
import Http
import Pages.Build.Logs exposing (decodeAnsi)
import RemoteData
import SvgBuilder exposing (hookStatusToIcon)
import Table
import Time exposing (Posix)
import Util
import Vela
    exposing
        ( Hook
        , HookNumber
        , Hooks
        , HooksModel
        , Org
        , Repo
        )


{-| PartialModel : type alias for passing in the main model with partial fields
-}
type alias PartialModel =
    { hooks : HooksModel
    , time : Posix
    , org : Org
    , repo : Repo
    }


type alias RedeliverHook msg =
    Org -> Repo -> HookNumber -> msg



-- VIEW


{-| view : renders hooks
-}
view : PartialModel -> RedeliverHook msg -> Html msg
view { hooks, time, org, repo } redeliverHook =
    let
        ( noRowsView, rows ) =
            case hooks.hooks of
                RemoteData.Success hooks_ ->
                    ( text "No hooks found for this repo"
                    , hooksToRows time hooks_ org repo redeliverHook
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "hooks-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No hooks found for this repo, most likely due to not having sufficient permissions to the source control repo"

                                        _ ->
                                            "No hooks found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No hooks found for this repo, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.largeLoader, [] )

        cfg =
            Table.Config
                "Hooks"
                "hooks"
                noRowsView
                tableHeaders
                rows
                Nothing
    in
    div [] [ Table.view cfg ]


{-| hooksToRows : takes list of hooks and produces list of Table rows
-}
hooksToRows : Posix -> Hooks -> Org -> Repo -> RedeliverHook msg -> Table.Rows Hook msg
hooksToRows now hooks org repo redeliverHook =
    hooks
        |> List.concatMap (\hook -> [ Just <| Table.Row hook (renderHook now org repo redeliverHook), hookErrorRow hook ])
        |> List.filterMap identity


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
renderHook : Posix -> Org -> Repo -> RedeliverHook msg -> Hook -> Html msg
renderHook now org repo redeliverHook hook =
    tr [ Util.testAttribute <| "hooks-row", hookStatusToRowClass hook.status ]
        [ td
            [ attribute "data-label" "status"
            , scope "row"
            , class "break-word"
            , class "-icon"
            ]
            [ hookStatusToIcon hook.status ]
        , td
            [ attribute "data-label" "source-id"
            , scope "row"
            , class "no-wrap"
            ]
            [ small [] [ code [ class "source-id", class "break-word" ] [ text hook.source_id ] ] ]
        , td
            [ attribute "data-label" "created"
            , scope "row"
            , class "break-word"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis hook.created) ]
        , td
            [ attribute "data-label" "host"
            , scope "row"
            , class "break-word"
            ]
            [ text hook.host ]
        , td
            [ attribute "data-label" "event"
            , scope "row"
            , class "break-word"
            ]
            [ text hook.event ]
        , td
            [ attribute "data-label" "branch"
            , scope "row"
            , class "break-word"
            ]
            [ text hook.branch ]
        , td
            [ attribute "data-label" ""
            , scope "row"
            , class "break-word"
            ]
            [ a
                [ href "#"
                , class "break-word"
                , Util.onClickPreventDefault <| redeliverHook org repo <| String.fromInt hook.number
                , Util.testAttribute <| "redeliver-hook-" ++ String.fromInt hook.number
                ]
                [ text "Redeliver Hook"
                ]
            ]
        ]


hookErrorRow : Hook -> Maybe (Table.Row Hook msg)
hookErrorRow hook =
    if not <| String.isEmpty hook.error then
        Just <| Table.Row hook renderHookError

    else
        Nothing


renderHookError : Hook -> Html msg
renderHookError hook =
    let
        lines =
            decodeAnsi hook.error
                |> Array.map
                    (\line ->
                        Just <|
                            Ansi.Log.viewLine line
                    )
                |> Array.toList
                |> List.filterMap identity

        msgRow =
            case hook.status of
                "skipped" ->
                    tr [ class "skipped-data", Util.testAttribute "hooks-skipped" ]
                        [ td [ attribute "colspan" "6" ]
                            [ code [ class "skipped-content" ]
                                lines
                            ]
                        ]

                _ ->
                    tr [ class "error-data", Util.testAttribute "hooks-error" ]
                        [ td [ attribute "colspan" "6" ]
                            [ code [ class "error-content" ]
                                lines
                            ]
                        ]
    in
    msgRow


{-| hookStatusToRowClass : takes hook status string and returns style class
-}
hookStatusToRowClass : String -> Html.Attribute msg
hookStatusToRowClass status =
    case status of
        "success" ->
            class "-success"

        "skipped" ->
            class "-skipped"

        _ ->
            class "-error"
