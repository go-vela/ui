{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Hooks exposing (hookStatus, view)

import Errors exposing (viewResourceError)
import Html
    exposing
        ( Html
        , code
        , div
        , small
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , scope
        )
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import SvgBuilder exposing (hookStatusToIcon)
import Table
import Time exposing (Posix)
import Util
import Vela
    exposing
        ( Hook
        , Hooks
        , HooksModel
        )


{-| PartialModel : type alias for passing in the main model with partial fields
-}
type alias PartialModel =
    { hooks : HooksModel
    , time : Posix
    }



-- VIEW


{-| view : renders hooks
-}
view : PartialModel -> Html msg
view { hooks, time } =
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
    tr [ Util.testAttribute <| "hooks-row", hookStatusToRowClass hook.status ]
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


hookErrorRow : Hook -> Maybe (Table.Row Hook msg)
hookErrorRow hook =
    if not <| String.isEmpty hook.error then
        Just <| Table.Row hook renderHookError

    else
        Nothing


renderHookError : Hook -> Html msg
renderHookError hook =
    tr [ class "error-data", Util.testAttribute "hooks-error" ] [ td [ attribute "colspan" "6" ] [ small [ class "error-content" ] [ text hook.error ] ] ]


{-| hookStatus : takes hook status and maps it to a string, for strict typing.
-}
hookStatus : String -> String
hookStatus status =
    case status of
        "success" ->
            "success"

        _ ->
            "failure"


{-| hookStatusToRowClass : takes hook status string and returns style class
-}
hookStatusToRowClass : String -> Html.Attribute msg
hookStatusToRowClass status =
    case status of
        "success" ->
            class "-success"

        _ ->
            class "-error"
