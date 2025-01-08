{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Insights exposing (Model, Msg, page)

import Auth
import Components.BarChart
import Components.Loading exposing (viewSmallLoader)
import Effect exposing (Effect)
import Float.Extra
import Html exposing (Html, div, h1, h2, h3, p, section, strong, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List
import Metrics.BuildMetrics as BuildMetrics exposing (Metrics)
import Metrics.TimeSeriesMetrics as TimeSeriesMetrics
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Helpers
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, route, model, and passes the insights page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        }



-- INIT


{-| Model : alias for a model object for an insights page.
we store the builds and calculated metrics.
-}
type alias Model =
    { builds : WebData (List Vela.Build)
    , metrics : Maybe Metrics
    }


{-| init : takes shared model, route, and initializes an insights page input arguments.
-}
init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    let
        currentTimeInSeconds =
            Time.posixToMillis shared.time // 1000

        sevenDaysInSeconds =
            7 * Helpers.oneDaySeconds

        timeMinusSevenDaysInSeconds : Int
        timeMinusSevenDaysInSeconds =
            currentTimeInSeconds - sevenDaysInSeconds
    in
    ( { builds = RemoteData.Loading
      , metrics = Nothing
      }
    , Effect.getAllBuilds
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetRepoBuildsResponse
        , after = timeMinusSevenDaysInSeconds
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = GetRepoBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetRepoBuildsResponse response ->
            case response of
                Ok ( meta, builds ) ->
                    let
                        metrics =
                            BuildMetrics.calculateMetrics builds
                    in
                    ( { model
                        | builds = RemoteData.succeed builds
                        , metrics = metrics
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | builds = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for the insights page.
-}
view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Pipeline Insights"
    , body =
        h2 [] [ text "Pipeline Insights (Last 7 Days)" ]
            :: (case model.builds of
                    RemoteData.Loading ->
                        [ viewSmallLoader ]

                    RemoteData.NotAsked ->
                        [ viewSmallLoader ]

                    RemoteData.Failure _ ->
                        viewError

                    RemoteData.Success builds ->
                        case builds of
                            [] ->
                                viewEmpty

                            _ ->
                                viewInsights model shared.time
               )
    }


{-| viewInsights : take model and current time and renders metrics.
-}
viewInsights : Model -> Time.Posix -> List (Html Msg)
viewInsights model now =
    case ( model.metrics, model.builds ) of
        ( Just m, RemoteData.Success builds ) ->
            let
                chartDataBuildsPerDay =
                    TimeSeriesMetrics.calculateCountPerDay now 7 .created builds

                chartDataAvgBuildTimePerDay =
                    TimeSeriesMetrics.calculateAveragePerDay
                        now
                        7
                        .created
                        (\build -> toFloat (build.finished - build.started))
                        (\seconds -> seconds / 60)
                        builds

                chartDataSuccessRatePerDay =
                    TimeSeriesMetrics.calculateAveragePerDay
                        now
                        7
                        .created
                        (\build ->
                            if build.status == Vela.Success then
                                100

                            else
                                0
                        )
                        identity
                        builds

                chartDataAvgQueueTimePerDay =
                    TimeSeriesMetrics.calculateAveragePerDay
                        now
                        7
                        .created
                        (\build -> toFloat (build.started - build.enqueued))
                        (\seconds -> seconds / 60)
                        (List.filter (\build -> build.started > 0) builds)

                barChart =
                    Components.BarChart.newBarChartConfig
            in
            [ h3 [] [ text "Build Activity" ]
            , section [ class "metrics" ]
                [ div [ class "metrics-quicklist", Helpers.testAttribute "metrics-quicklist-activity" ]
                    [ viewMetric (String.fromInt m.overall.buildFrequency) "average build(s) per day"
                    , viewMetric (String.fromInt m.overall.deployFrequency) "average deployment(s) per day"
                    ]
                , Components.BarChart.view
                    (barChart
                        |> Components.BarChart.withTitle "Builds per day (all branches)"
                        |> Components.BarChart.withData chartDataBuildsPerDay
                        |> Components.BarChart.withNumberUnit 0
                    )
                ]
            , h3 [] [ text "Build Duration" ]
            , section [ class "metrics" ]
                [ div [ class "metrics-quicklist", Helpers.testAttribute "metrics-quicklist-duration" ]
                    [ viewMetric (Helpers.formatTimeFromFloat m.overall.averageRuntime) "average"
                    , viewMetric (Helpers.formatTimeFromFloat m.overall.stdDeviationRuntime) "standard deviation"
                    , viewMetric (Helpers.formatTimeFromFloat m.overall.medianRuntime) "median"
                    , viewMetric (Helpers.formatTimeFromFloat m.overall.timeUsedOnFailedBuilds) "time used on failed builds"
                    ]
                , Components.BarChart.view
                    (barChart
                        |> Components.BarChart.withTitle "Average build duration per day (in minutes)"
                        |> Components.BarChart.withData chartDataAvgBuildTimePerDay
                    )
                ]
            , h3 [] [ text "Build Reliability" ]
            , section [ class "metrics" ]
                [ div [ class "metrics-quicklist", Helpers.testAttribute "metrics-quicklist-reliability" ]
                    [ viewMetric (Float.Extra.toFixedDecimalPlaces 1 m.overall.successRate ++ "%") "success rate"
                    , viewMetric (Float.Extra.toFixedDecimalPlaces 1 m.overall.failureRate ++ "%") "failure rate"
                    , viewMetric (Helpers.formatTimeFromFloat m.overall.averageTimeToRecovery) "average time to recover from failures"
                    ]
                , Components.BarChart.view
                    (barChart
                        |> Components.BarChart.withTitle "Average success rate per day"
                        |> Components.BarChart.withData chartDataSuccessRatePerDay
                        |> Components.BarChart.withMaxY 100
                        |> Components.BarChart.withPercentUnit
                    )
                ]
            , h3 [] [ text "Queue Performance" ]
            , section [ class "metrics" ]
                [ div [ class "metrics-quicklist", Helpers.testAttribute "metrics-quicklist-queue" ]
                    [ viewMetric (Helpers.formatTimeFromFloat m.overall.averageQueueTime) "average time in queue"
                    , viewMetric (Helpers.formatTimeFromFloat m.overall.medianQueueTime) "median time in queue"
                    ]
                , Components.BarChart.view
                    (barChart
                        |> Components.BarChart.withTitle "Average time in queue per day (in minutes)"
                        |> Components.BarChart.withData chartDataAvgQueueTimePerDay
                    )
                ]
            ]

        ( _, _ ) ->
            [ h3 [] [ text "No Metrics to Show" ] ]


{-| viewMetrics : takes a value and description as strings and renders a quick metric.
-}
viewMetric : String -> String -> Html msg
viewMetric value description =
    div [ class "metric" ]
        [ strong [ class "metric-value" ] [ text value ]
        , p [ class "metric-description" ] [ text description ]
        ]


{-| viewEmpty : renders information when there are no builds returned.
-}
viewEmpty : List (Html msg)
viewEmpty =
    [ h3 [ Helpers.testAttribute "no-builds" ] [ text "No builds found" ]
    , p [] [ text "Run some builds and reload the page." ]
    ]


{-| viewError : renders information when there was an error retrieving the builds.
-}
viewError : List (Html msg)
viewError =
    [ h3 [] [ text "There was an error retrieving builds :(" ]
    , p [] [ text "Try again in a little bit." ]
    ]
