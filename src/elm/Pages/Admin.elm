{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Admin exposing (view)

import Html
    exposing
        ( Html
        , a
        , code
        , div
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
import List.Extra
import RemoteData
import Routes
import String.Extra
import Table
import Time exposing (Posix)
import Url exposing (Protocol, Url)
import Util
import Vela
    exposing
        ( Worker
        , WorkerModel
        , Workers
        )


{-| PartialModel : type alias for passing in the main model with partial fields
-}
type alias PartialModel =
    { workers : WorkerModel
    , time : Posix
    }



-- VIEW


{-| view : renders hooks
-}
view : PartialModel -> Html msg
view { workers, time } =
    let
        ( noRowsView, rows ) =
            case workers.workers of
                RemoteData.Success workers_ ->
                    ( text "No workers found"
                    , workersToRows time workers_
                    )

                RemoteData.Failure error ->
                    ( span [ Util.testAttribute "workers-error" ]
                        [ text <|
                            case error of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No workers found, most likely due to not having sufficient permissions to view workers"

                                        _ ->
                                            "No workers found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No workers found, there was an error with the server"
                        ]
                    , []
                    )

                _ ->
                    ( Util.largeLoader, [] )

        cfg =
            Table.Config
                "Workers"
                "workers"
                noRowsView
                tableHeaders
                rows
                Nothing
    in
    div [] [ Table.view cfg ]


{-| workersToRows : takes list of workers and produces list of Table rows
-}
workersToRows : Posix -> Workers -> Table.Rows Worker msg
workersToRows now workers =
    workers
        |> List.map (\worker -> [ Just <| Table.Row worker (renderWorker now) ])
        |> List.concat
        |> List.filterMap identity


{-| tableHeaders : returns table headers for secrets table
-}
tableHeaders : Table.Columns
tableHeaders =
    [ ( Nothing, "hostname" )
    , ( Nothing, "address" )
    , ( Nothing, "routes" )
    , ( Nothing, "active" )
    , ( Nothing, "status" )
    , ( Nothing, "last status update" )
    , ( Nothing, "running builds" )
    , ( Nothing, "last build start" )
    , ( Nothing, "last build finish" )
    , ( Nothing, "last check in" )
    , ( Nothing, "build limit" )
    ]


{-| renderHook : takes hook and renders a table row
-}
renderWorker : Posix -> Worker -> Html msg
renderWorker now worker =
    tr [ Util.testAttribute <| "worker-row", workerStatusToRowClass worker.status worker.active ]
        [ td
            [ attribute "data-label" "hostname"
            , scope "row"
            , class "break-word"
            ]
            [ text worker.host_name ]
        , td
            [ attribute "data-label" "address"
            , scope "row"
            , class "no-wrap"
            ]
            [ text worker.address ]
        , td
            [ attribute "data-label" "routes"
            , scope "row"
            , class "break-word"
            ]
            [ renderListCell worker.routes "no routes" "routes" ]
        , td
            [ attribute "data-label" "active"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.boolToYesNo worker.active ]
        , td
            [ attribute "data-label" "status"
            , scope "row"
            , class "break-word"
            ]
            [ text worker.status ]
        , td
            [ attribute "data-label" "last_status_update"
            , scope "row"
            , class "break-word"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis worker.last_status_update) ]
        , td
            [ attribute "data-label" "running_build_ids"
            , scope "row"
            , class "break-word"
            ]
            [ renderBuildListCell worker.running_build_ids "" "running-builds" ]
        , td
            [ attribute "data-label" "last_build_started"
            , scope "row"
            , class "break-word"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis worker.last_build_started) ]
        , td
            [ attribute "data-label" "last_build_finished"
            , scope "row"
            , class "break-word"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis worker.last_build_finished) ]
        , td
            [ attribute "data-label" "last_checked_in"
            , scope "row"
            , class "break-word"
            ]
            [ text <| (Util.relativeTimeNoSeconds now <| Time.millisToPosix <| Util.secondsToMillis worker.last_checked_in) ]
        , td
            [ attribute "data-label" "build_limit"
            , scope "row"
            , class "break-word"
            ]
            [ text <| String.fromInt worker.build_limit ]
        ]


renderListCell : List String -> String -> String -> Html msg
renderListCell items none itemClassName =
    div [] <|
        if List.length items == 0 then
            [ text none ]

        else
            items
                |> List.sort
                |> List.map
                    (\item ->
                        listItemView itemClassName item
                    )


{-| listItemView : takes classname, text and size constraints and renders a list element
-}
listItemView : String -> String -> Html msg
listItemView className text_ =
    div [ class className ]
        [ span
            [ class "list-item"
            ]
            [ text text_ ]
        ]


{-| renderBuildListCell : takes an item and class name and renders a build link list for a table cell
-}
renderBuildListCell : List String -> String -> String -> Html msg
renderBuildListCell items none itemClassName =
    div [] <|
        if List.length items == 0 then
            [ text none ]

        else
            items
                |> List.sort
                |> List.map
                    (\item ->
                        listBuildItemView itemClassName item
                    )


{-| listBuildItemView : takes classname and text from a build link and renders a clickable list element
-}
listBuildItemView : String -> String -> Html msg
listBuildItemView className text_ =
    let
        path =
            case Url.fromString text_ of
                Just url ->
                    String.Extra.rightOf "/" url.path

                Nothing ->
                    text_
    in
    div [ class className ]
        [ a
            [ class "list-item"
            , href text_
            ]
            [ text path ]
        ]


{-| workerStatusToRowClass : takes worker status string and returns style class
-}
workerStatusToRowClass : String -> Bool -> Html.Attribute msg
workerStatusToRowClass status active =
    if active then
        case status of
            "idle" ->
                class "-worker-idle"

            "available" ->
                class "-worker-available"

            "busy" ->
                class "-worker-busy"

            _ ->
                class "-error"

    else
        class "-error"
