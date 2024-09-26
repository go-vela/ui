{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Status.Workers exposing (Model, Msg, page)

import Api.Pagination
import Auth
import Components.Crumbs
import Components.Loading
import Components.Nav
import Components.Pager
import Components.Table
import Dict
import Effect exposing (Effect)
import Html exposing (Html, a, div, main_, span, text, tr)
import Html.Attributes exposing (class, href)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


{-| toLayout : takes user, model, and passes the home page info to Layouts.
-}
toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        }



-- INIT


type alias Model =
    { workers : WebData (List Vela.Worker)
    , pager : List WebLink
    }


init : Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init shared route () =
    ( { workers = RemoteData.Loading
      , pager = []
      }
    , Effect.getWorkers
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetWorkersResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        }
    )



-- UPDATE


type Msg
    = -- WORKERS
      GetWorkersResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Worker ))
    | GotoPage Int
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetWorkersResponse response ->
            case response of
                Ok ( meta, workers ) ->
                    ( { model
                        | workers = RemoteData.Success workers
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | workers = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.replaceRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getWorkers
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetWorkersResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    }
                ]
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getWorkers
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetWorkersResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( "Status", Nothing )
            , ( "Workers", Nothing )
            ]
    in
    { title = "Worker Status"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = [], crumbs = Components.Crumbs.view route.path crumbs }
        , main_ [ class "content-wrap" ]
            [ viewWorkers shared model route
            , Components.Pager.view
                { show = True
                , links = model.pager
                , labels = Components.Pager.defaultLabels
                , msg = GotoPage
                }
            ]
        ]
    }


{-| viewWorkers : renders a list of workers.
-}
viewWorkers : Shared.Model -> Model -> Route () -> Html Msg
viewWorkers shared model route =
    let
        actions =
            Just <|
                div [ class "buttons" ]
                    [ Components.Pager.view
                        { show = True
                        , links = model.pager
                        , labels = Components.Pager.defaultLabels
                        , msg = GotoPage
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
            case model.workers of
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
workersToRows : Shared.Model -> List Vela.Worker -> Components.Table.Rows Vela.Worker Msg
workersToRows shared workers =
    List.map (\worker -> Components.Table.Row worker (viewWorker shared)) workers


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


{-| viewWorker : takes worker and renders a table row
-}
viewWorker : Shared.Model -> Vela.Worker -> Html Msg
viewWorker shared worker =
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
