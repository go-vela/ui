{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Insights exposing (Model, Msg, page)

import Auth
import Chart
import Chart.Attributes
import Chart.Events
import Chart.Item
import Components.Loading exposing (viewSmallLoader)
import Dict exposing (Dict)
import Effect exposing (Effect)
import Float.Extra
import Html exposing (Html, div, em, h1, h2, h3, p, section, strong, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List exposing (sort)
import List.Extra
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


{-| toLayout : takes user, route, model, and passes the deployments page info to Layouts.
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


type alias Metrics =
    { overall : OverallMetrics
    , byStatus : Dict String StatusMetrics
    }


type alias StatusMetrics =
    { averageRuntime : Float
    , medianRuntime : Float
    , buildFrequency : Int
    , longestRuntime : Int
    , eventBranchMetrics : Dict ( String, String ) EventBranchMetrics
    }


type alias OverallMetrics =
    { failureRate : Float
    , averageQueueTime : Float
    , averageRuntime : Float
    , timeUsedOnFailedBuilds : Float
    , successRate : Float
    , medianQueueTime : Float
    , medianRuntime : Float
    , buildFrequency : Int
    , averageTimeToRecovery : Float
    , longestQueueTime : Int
    , longestRuntime : Int
    , eventBranchMetrics : Dict ( String, String ) EventBranchMetrics
    }


type alias EventBranchMetrics =
    { medianRuntime : Float
    , buildTimesOverTime : List TimeSeriesData

    -- Add other metrics as needed
    }


type alias TimeSeriesData =
    { timestamp : Int
    , value : Float
    }


type alias Model =
    { builds : WebData (List Vela.Build)
    , metrics : Maybe Metrics
    , hovering : List (Chart.Item.One TimeSeriesData Chart.Item.Dot)
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    let
        currentTimeInSeconds =
            Time.posixToMillis shared.time // 1000

        sevenDaysInSeconds =
            7 * 24 * 60 * 60

        timeMinusSevenDaysInSeconds : Int
        timeMinusSevenDaysInSeconds =
            currentTimeInSeconds - sevenDaysInSeconds
    in
    ( { builds = RemoteData.Loading
      , metrics = Nothing
      , hovering = []
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


type Msg
    = GetRepoBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))
    | OnHover (List (Chart.Item.One TimeSeriesData Chart.Item.Dot))


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        OnHover hovering ->
            ( { model | hovering = hovering }
            , Effect.none
            )

        GetRepoBuildsResponse response ->
            case response of
                Ok ( meta, builds ) ->
                    let
                        metrics =
                            calculateMetrics builds
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


calculateMetrics : List Vela.Build -> Maybe Metrics
calculateMetrics builds =
    if List.isEmpty builds then
        Nothing

    else
        let
            failureRate =
                calculateFailureRate builds

            averageQueueTime =
                calculateAverageQueueTime builds

            averageRuntime =
                calculateAverageRuntime builds

            timeUsedOnFailedBuilds =
                calculateTimeUsedOnFailedBuilds builds

            successRate =
                calculateSuccessRate builds

            medianQueueTime =
                calculateMedianQueueTime builds

            medianRuntime =
                calculateMedianRuntime builds

            buildFrequency =
                calculateBuildFrequency builds

            averageTimeToRecovery =
                calculateAverageTimeToRecovery builds

            longestQueueTime =
                calculateLongestQueueTime builds

            longestRuntime =
                calculateLongestRuntime builds

            eventBranchMetrics =
                calculateEventBranchMetrics builds

            byStatus =
                calculateMetricsByStatus builds
        in
        Just
            { overall =
                { failureRate = failureRate
                , averageQueueTime = averageQueueTime
                , averageRuntime = averageRuntime
                , timeUsedOnFailedBuilds = timeUsedOnFailedBuilds
                , successRate = successRate
                , medianQueueTime = medianQueueTime
                , medianRuntime = medianRuntime
                , buildFrequency = buildFrequency
                , averageTimeToRecovery = averageTimeToRecovery
                , longestQueueTime = longestQueueTime
                , longestRuntime = longestRuntime
                , eventBranchMetrics = eventBranchMetrics
                }
            , byStatus = byStatus
            }


calculateLongestQueueTime : List Vela.Build -> Int
calculateLongestQueueTime builds =
    let
        queueTimes =
            List.map (\build -> build.started - build.enqueued) builds
    in
    if List.isEmpty queueTimes then
        0

    else
        List.maximum queueTimes |> Maybe.withDefault 0


calculateMedianRuntime : List Vela.Build -> Float
calculateMedianRuntime builds =
    let
        runTimes =
            List.map (\build -> toFloat (build.finished - build.started)) builds
    in
    calculateMedian runTimes


calculateMedianQueueTime : List Vela.Build -> Float
calculateMedianQueueTime builds =
    let
        queueTimes =
            List.map (\build -> toFloat (build.started - build.enqueued)) builds
    in
    calculateMedian queueTimes


calculateSuccessRate : List Vela.Build -> Float
calculateSuccessRate builds =
    let
        total =
            List.length builds

        succeeded =
            List.length (List.filter (\build -> build.status == Vela.Success) builds)
    in
    if total == 0 then
        0

    else
        (toFloat succeeded / toFloat total) * 100


calculateMetricsByStatus : List Vela.Build -> Dict String StatusMetrics
calculateMetricsByStatus builds =
    let
        -- Group builds by status
        groupedBuilds =
            List.foldl
                (\build acc ->
                    let
                        key =
                            Vela.statusToString build.status
                    in
                    Dict.update key (Maybe.map (\lst -> Just (build :: lst)) >> Maybe.withDefault (Just [ build ])) acc
                )
                Dict.empty
                builds

        calculateMetricsForGroup b =
            let
                buildTimes =
                    List.map (\build -> toFloat (build.finished - build.started)) b

                medianRuntime =
                    calculateMedian buildTimes

                averageRuntime =
                    calculateAverageRuntime b

                buildFrequency =
                    calculateBuildFrequency b

                longestRuntime =
                    calculateLongestRuntime b

                eventBranchMetrics =
                    calculateEventBranchMetrics b
            in
            { averageRuntime = averageRuntime
            , medianRuntime = medianRuntime
            , buildFrequency = buildFrequency
            , longestRuntime = longestRuntime
            , eventBranchMetrics = eventBranchMetrics
            }
    in
    Dict.map (\_ buildss -> calculateMetricsForGroup buildss) groupedBuilds


calculateAverageTimeToRecovery : List Vela.Build -> Float
calculateAverageTimeToRecovery builds =
    let
        -- Filter the builds to get only failed and successful builds
        failedBuilds =
            List.filter (\build -> build.status == Vela.Failure) builds

        successfulBuilds =
            List.filter (\build -> build.status == Vela.Success) builds

        -- Group builds by branch
        groupByBranch b =
            List.foldl
                (\build acc ->
                    Dict.update build.branch (Maybe.map (\lst -> Just (build :: lst)) >> Maybe.withDefault (Just [ build ])) acc
                )
                Dict.empty
                b

        groupedFailedBuilds =
            groupByBranch failedBuilds

        groupedSuccessfulBuilds =
            groupByBranch successfulBuilds

        -- Find pairs of failed and subsequent successful builds within each branch
        findRecoveryTimes f s =
            case ( f, s ) of
                ( [], _ ) ->
                    []

                ( _, [] ) ->
                    []

                ( failed :: restFailed, success :: restSuccess ) ->
                    if success.created > failed.created then
                        (success.created - failed.created) :: findRecoveryTimes restFailed restSuccess

                    else
                        findRecoveryTimes f restSuccess

        -- Calculate the time differences for each branch
        calculateBranchRecoveryTimes branch =
            let
                f =
                    Dict.get branch groupedFailedBuilds |> Maybe.withDefault []

                s =
                    Dict.get branch groupedSuccessfulBuilds |> Maybe.withDefault []
            in
            findRecoveryTimes (List.sortBy .created f) (List.sortBy .created s)

        -- Aggregate recovery times across all branches
        allRecoveryTimes =
            Dict.keys groupedFailedBuilds
                |> List.concatMap calculateBranchRecoveryTimes

        -- Compute the average of the time differences
        totalRecoveryTime =
            List.sum allRecoveryTimes

        count =
            List.length allRecoveryTimes
    in
    if count == 0 then
        0

    else
        toFloat totalRecoveryTime / toFloat count


calculateLongestRuntime : List Vela.Build -> Int
calculateLongestRuntime builds =
    builds
        |> List.map (\build -> build.finished - build.started)
        |> List.maximum
        |> Maybe.withDefault 0


calculateBuildFrequency : List Vela.Build -> Int
calculateBuildFrequency builds =
    let
        sortedByCreated =
            List.sortBy .created builds

        firstBuildTime =
            List.head sortedByCreated |> Maybe.map .created |> Maybe.withDefault 0

        lastBuildTime =
            List.reverse sortedByCreated |> List.head |> Maybe.map .created |> Maybe.withDefault 0

        totalSeconds =
            lastBuildTime - firstBuildTime

        totalDays =
            max 1 (totalSeconds // (24 * 60 * 60))

        totalBuilds =
            List.length builds
    in
    if totalDays == 0 then
        0

    else
        totalBuilds // totalDays


calculateMedian : List Float -> Float
calculateMedian list =
    let
        sorted =
            List.sort list

        len =
            List.length sorted
    in
    if len == 0 then
        0

    else if Basics.remainderBy 2 len == 1 then
        List.Extra.getAt (len // 2) sorted |> Maybe.withDefault 0

    else
        let
            mid1 =
                List.Extra.getAt (len // 2 - 1) sorted |> Maybe.withDefault 0

            mid2 =
                List.Extra.getAt (len // 2) sorted |> Maybe.withDefault 0
        in
        (mid1 + mid2) / 2


calculateEventBranchMetrics : List Vela.Build -> Dict ( String, String ) EventBranchMetrics
calculateEventBranchMetrics builds =
    let
        -- Group builds by (event, branch)
        groupedBuilds =
            List.foldl
                (\build acc ->
                    let
                        key =
                            ( build.event, build.branch )
                    in
                    Dict.update key (Maybe.map (\lst -> Just (build :: lst)) >> Maybe.withDefault (Just [ build ])) acc
                )
                Dict.empty
                builds

        -- Calculate metrics for each group
        calculateMetricsForGroup b =
            let
                buildTimes =
                    List.map (\build -> toFloat (build.finished - build.started)) b

                medianRuntime =
                    calculateMedian buildTimes

                buildTimesOverTime =
                    List.foldl
                        (\build acc ->
                            { timestamp = build.created, value = toFloat (build.finished - build.started) } :: acc
                        )
                        []
                        b
            in
            { medianRuntime = medianRuntime
            , buildTimesOverTime = buildTimesOverTime
            }
    in
    Dict.map (\_ buildss -> calculateMetricsForGroup buildss) groupedBuilds


calculateAverageRuntime : List Vela.Build -> Float
calculateAverageRuntime builds =
    let
        legitBuilds =
            builds
                |> List.filter (\build -> build.status /= Vela.Pending)
                |> List.filter (\build -> build.status /= Vela.Running)

        total =
            legitBuilds
                |> List.foldl (\build acc -> acc + (build.finished - build.started)) 0

        count =
            List.length legitBuilds
    in
    if count == 0 then
        toFloat 0

    else
        toFloat (total // count)


calculateAverageQueueTime : List Vela.Build -> Float
calculateAverageQueueTime builds =
    let
        total =
            builds |> List.filter (\build -> build.started > 0) |> List.foldl (\build acc -> acc + (build.started - build.enqueued)) 0

        count =
            List.length builds
    in
    if count == 0 then
        toFloat 0

    else
        toFloat (total // count)


calculateFailureRate : List Vela.Build -> Float
calculateFailureRate builds =
    let
        totalFailures =
            builds |> List.filter (\build -> build.status == Vela.Failure) |> List.length

        count =
            List.length builds
    in
    if count == 0 then
        0

    else
        toFloat totalFailures / toFloat count * 100


calculateTimeUsedOnFailedBuilds : List Vela.Build -> Float
calculateTimeUsedOnFailedBuilds builds =
    builds
        |> List.filter (\build -> build.status == Vela.Failure)
        |> List.foldl (\build acc -> acc + (build.finished - build.started)) 0
        |> toFloat



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Pages.Org_.Repo_.Insights"
    , body =
        case model.builds of
            RemoteData.Loading ->
                [ viewSmallLoader ]

            RemoteData.NotAsked ->
                viewEmpty

            RemoteData.Failure _ ->
                viewError

            RemoteData.Success builds ->
                case builds of
                    [] ->
                        viewEmpty

                    _ ->
                        viewOverallMetrics model shared.zone
    }


viewOverallMetrics : Model -> Time.Zone -> List (Html Msg)
viewOverallMetrics model time =
    case model.metrics of
        Nothing ->
            [ h1 [] [ text "No metrics" ] ]

        Just m ->
            let
                data =
                    m.overall.eventBranchMetrics
                        |> Dict.values
                        |> List.concatMap .buildTimesOverTime
            in
            List.concat
                [ [ h2 [] [ text "Performance Insights (Last 7 Days)" ] ]
                , viewMetric "Failure Rate" (Float.Extra.toFixedDecimalPlaces 2 m.overall.failureRate ++ "%") "Percentage of failed builds"
                , viewMetric "Average Queue Time" (Helpers.formatTimeFromFloat m.overall.averageQueueTime) "Average time builds spend in queue"
                , viewMetric "Average Runtime" (Helpers.formatTimeFromFloat m.overall.averageRuntime) "Average time builds take to complete"
                , viewMetric "Time Used on Failed Builds" (Helpers.formatTimeFromFloat m.overall.timeUsedOnFailedBuilds) "Total time spent on failed builds"
                , viewMetric "Success Rate" (Float.Extra.toFixedDecimalPlaces 2 m.overall.successRate ++ "%") "Percentage of successful builds"
                , viewMetric "Median Queue Time" (Helpers.formatTimeFromFloat m.overall.medianQueueTime) "Median time builds spend in queue"
                , viewMetric "Median Runtime" (Helpers.formatTimeFromFloat m.overall.medianRuntime) "Median time builds take to complete"
                , viewMetric "Build Frequency" (String.fromInt m.overall.buildFrequency) "Number of builds over the last 7 days"
                , viewMetric "Average Time to Recovery" (Helpers.formatTimeFromFloat m.overall.averageTimeToRecovery) "Average time to recover from failures"
                , viewMetric "Longest Queue Time" (Helpers.formatTimeFromInt m.overall.longestQueueTime) "Longest time a build spent in queue"
                , viewMetric "Longest Runtime" (Helpers.formatTimeFromInt m.overall.longestRuntime) "Longest time a build took to complete"
                , [ div [ class "chart-container" ]
                        [ Chart.chart
                            [ Chart.Attributes.height 200
                            , Chart.Attributes.width 400
                            , Chart.Events.onMouseMove OnHover (Chart.Events.getNearest Chart.Item.dots)
                            , Chart.Events.onMouseLeave (OnHover [])
                            ]
                            [ Chart.xLabels [ Chart.Attributes.times time ]
                            , Chart.yLabels [ Chart.Attributes.withGrid ]
                            , Chart.series (.timestamp >> toFloat)
                                [ Chart.interpolated .value [] [ Chart.Attributes.circle, Chart.Attributes.size 3 ]
                                ]
                                data
                            , Chart.each model.hovering <|
                                \p item ->
                                    [ Chart.tooltip item [] [] [] ]
                            ]
                        ]
                  ]
                ]


viewMetric : String -> String -> String -> List (Html msg)
viewMetric title value description =
    [ section [ class "metric" ]
        [ h3 [ class "metric-title" ] [ text title ]
        , strong [ class "metric-value" ] [ text value ]
        , em [ class "metric-description" ] [ text description ]
        ]
    ]


viewEmpty : List (Html msg)
viewEmpty =
    [ h1 [] [ text "No builds" ] ]


viewError : List (Html msg)
viewError =
    [ h1 [] [ text "Error" ] ]
