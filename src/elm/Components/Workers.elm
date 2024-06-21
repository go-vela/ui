module Components.Workers exposing (view, viewSingle)

import Api.Pagination
import Components.Loading
import Components.Pager
import Components.Table
import Html exposing (Html, a, div, span, text, tr)
import Html.Attributes exposing (class, href)
import Http
import LinkHeader exposing (WebLink)
import RemoteData exposing (WebData)
import Shared
import Utils.Helpers as Util
import Vela


type alias Props msg =
    { workers : WebData (List Vela.Worker)
    , pager : List WebLink
    , gotoPage : Api.Pagination.Page -> msg
    }


{-| view : renders a list of workers.
-}
view : Shared.Model -> Props msg -> Html msg
view shared props =
    let
        actions =
            Just <|
                div [ class "buttons" ]
                    [ Components.Pager.view
                        { show = True
                        , links = props.pager
                        , labels = Components.Pager.defaultLabels
                        , msg = props.gotoPage
                        }
                    ]

        ( noRowsView, rows ) =
            let
                viewHttpError e =
                    span [ Util.testAttribute "workers-error" ]
                        [ text <|
                            case e of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No workers found, most likely due to not having access to the resource"

                                        _ ->
                                            "No workers found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No workers found"
                        ]
            in
            case props.workers of
                RemoteData.Success w ->
                    ( text "No workers found"
                    , workersToRows shared w
                    )

                RemoteData.Failure error ->
                    ( viewHttpError error, [] )

                _ ->
                    ( Components.Loading.viewSmallLoader, [] )

        cfg =
            Components.Table.Config
                "Workers"
                "workers"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div []
        [ Components.Table.view cfg
        ]



-- TABLE


{-| workersToRows : takes list of workers and produces list of Table rows
-}
workersToRows : Shared.Model -> List Vela.Worker -> Components.Table.Rows Vela.Worker msg
workersToRows shared workers =
    List.map (\worker -> Components.Table.Row worker (viewWorkerRow shared)) workers


{-| tableHeaders : returns table headers for workers table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Nothing, "address" )
    , ( Nothing, "status" )
    , ( Nothing, "routes" )
    , ( Nothing, "active" )
    , ( Nothing, "last status update" )
    , ( Nothing, "running builds" )
    , ( Nothing, "last build started" )
    , ( Nothing, "last build finished" )
    , ( Nothing, "last checked in" )
    , ( Nothing, "build limit" )
    ]


{-| viewWorkerRow : takes worker and renders a table row
-}
viewWorkerRow : Shared.Model -> Vela.Worker -> Html msg
viewWorkerRow shared worker =
    tr [ Util.testAttribute <| "workers-row", statusToRowClass worker.status ]
        [ Components.Table.viewItemCell
            { dataLabel = "address"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text worker.address
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "status"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text worker.status
                ]
            }
        , Components.Table.viewListItemCell
            { dataLabel = "routes"
            , parentClassList = [ ( "routes", True ) ]
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ text <| String.join ", " worker.routes
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "active"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.boolToYesNo worker.active
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "last status update"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault shared.zone worker.last_status_update
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "running builds"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ viewWorkerBuildsLinks worker
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "last build started"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault shared.zone worker.last_build_started
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "last build finished"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault shared.zone worker.last_build_finished
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "last checked in"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault shared.zone worker.last_checked_in
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "build limit"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| String.fromInt worker.build_limit
                ]
            }
        ]


{-| viewWorkerBuildsLinks : renders a list of links to worker builds
-}
viewWorkerBuildsLinks : Vela.Worker -> Html msg
viewWorkerBuildsLinks worker =
    worker.running_builds
        |> List.map
            (\build ->
                a
                    [ href build.link ]
                    [ text
                        (build.link
                            |> String.split "/"
                            |> List.reverse
                            |> List.head
                            |> Maybe.withDefault ""
                            |> String.append "#"
                        )
                    ]
            )
        |> List.intersperse (text ", ")
        |> div []


{-| statusToRowClass : takes a worker status and returns a class for the row
-}
statusToRowClass : String -> Html.Attribute msg
statusToRowClass status =
    case status of
        "idle" ->
            class "status-idle"

        "available" ->
            class "status-available"

        "busy" ->
            class "status-busy"

        "error" ->
            class "status-error"

        _ ->
            class "status-success"


type alias PropsSingle =
    { worker : WebData Vela.Worker }


{-| viewSingle : takes worker and renders a single
-}
viewSingle : Shared.Model -> PropsSingle -> Html msg
viewSingle shared props =
    let
        ( noRowsView, rows ) =
            let
                viewHttpError e =
                    span [ Util.testAttribute "workers-error" ]
                        [ text <|
                            case e of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No workers found, most likely due to not having access to the resource"

                                        _ ->
                                            "No workers found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No workers found"
                        ]
            in
            case props.worker of
                RemoteData.Success w ->
                    ( text "No workers found"
                    , workersToRows shared [ w ]
                    )

                RemoteData.Failure error ->
                    ( viewHttpError error, [] )

                _ ->
                    ( Components.Loading.viewSmallLoader, [] )

        cfg =
            Components.Table.Config
                ""
                "workers"
                noRowsView
                tableHeaders
                rows
                Nothing
    in
    div []
        [ Components.Table.view cfg
        ]
