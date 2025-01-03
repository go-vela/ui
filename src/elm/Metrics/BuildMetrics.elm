{--
SPDX-License-Identifier: Apache-2.0
--}


module Metrics.BuildMetrics exposing (Metrics, calculateAverageRuntime, calculateAverageTimeToRecovery, calculateBuildFrequency, calculateEventBranchMetrics, calculateFailureRate, calculateMetrics)

import Dict exposing (Dict)
import Statistics
import Vela


type alias Metrics =
    { overall : OverallMetrics
    , byStatus : Dict String StatusMetrics
    }


type alias StatusMetrics =
    { averageRuntime : Float
    , medianRuntime : Float
    , buildFrequency : Int
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
    , stdDeviationRuntime : Float
    , buildFrequency : Int
    , deployFrequency : Int
    , averageTimeToRecovery : Float
    , eventBranchMetrics : Dict ( String, String ) EventBranchMetrics
    }


type alias EventBranchMetrics =
    { medianRuntime : Float
    , buildTimesOverTime : List TimeSeriesData
    }


type alias TimeSeriesData =
    { timestamp : Int
    , value : Float
    }


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

            stdDeviationRuntime =
                calculateStdDeviationRuntime builds

            buildFrequency =
                calculateBuildFrequency builds

            deployFrequency =
                calculateDeployFrequency builds

            averageTimeToRecovery =
                calculateAverageTimeToRecovery builds

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
                , stdDeviationRuntime = stdDeviationRuntime
                , buildFrequency = buildFrequency
                , deployFrequency = deployFrequency
                , averageTimeToRecovery = averageTimeToRecovery
                , eventBranchMetrics = eventBranchMetrics
                }
            , byStatus = byStatus
            }


calculateMedianRuntime : List Vela.Build -> Float
calculateMedianRuntime builds =
    let
        legitBuilds =
            builds
                |> List.filter (\build -> build.status /= Vela.Pending)
                |> List.filter (\build -> build.status /= Vela.Running)

        runTimes =
            List.map (\build -> toFloat (build.finished - build.started)) legitBuilds
    in
    calculateMedian runTimes


calculateStdDeviationRuntime : List Vela.Build -> Float
calculateStdDeviationRuntime builds =
    let
        legitBuilds =
            builds
                |> List.filter (\build -> build.status /= Vela.Pending)
                |> List.filter (\build -> build.status /= Vela.Running)

        runTimes =
            List.map (\build -> toFloat (build.finished - build.started)) legitBuilds
    in
    calculateStdDeviation runTimes


calculateMedianQueueTime : List Vela.Build -> Float
calculateMedianQueueTime builds =
    let
        legitBuilds =
            builds
                |> List.filter (\build -> build.started > 0)

        queueTimes =
            List.map (\build -> toFloat (build.started - build.enqueued)) legitBuilds
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

                eventBranchMetrics =
                    calculateEventBranchMetrics b
            in
            { averageRuntime = averageRuntime
            , medianRuntime = medianRuntime
            , buildFrequency = buildFrequency
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
            -- if we start a new day, we just count the whole day
            max 1 (ceiling (toFloat totalSeconds / (24 * 60 * 60)))

        totalBuilds =
            List.length builds
    in
    if totalDays == 0 then
        0

    else
        totalBuilds // totalDays


calculateDeployFrequency : List Vela.Build -> Int
calculateDeployFrequency builds =
    let
        sortedByCreated =
            builds
                |> List.filter (\build -> not (String.isEmpty build.deploy))
                |> List.sortBy .created

        firstBuildTime =
            List.head sortedByCreated |> Maybe.map .created |> Maybe.withDefault 0

        lastBuildTime =
            List.reverse sortedByCreated |> List.head |> Maybe.map .created |> Maybe.withDefault 0

        totalSeconds =
            lastBuildTime - firstBuildTime

        totalDays =
            max 1 (totalSeconds // (24 * 60 * 60))

        totalBuilds =
            List.length sortedByCreated
    in
    if totalDays == 0 then
        0

    else
        totalBuilds // totalDays


calculateMedian : List Float -> Float
calculateMedian list =
    List.sort list
        |> Statistics.quantile 0.5
        |> Maybe.withDefault 0


calculateStdDeviation : List Float -> Float
calculateStdDeviation list =
    Statistics.deviation list
        |> Maybe.withDefault 0


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
        0

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
        0

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
