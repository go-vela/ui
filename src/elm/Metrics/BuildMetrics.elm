{--
SPDX-License-Identifier: Apache-2.0
--}


module Metrics.BuildMetrics exposing
    ( Metrics
    , calculateAverageRuntime
    , calculateAverageTimeToRecovery
    , calculateBuildFrequency
    , calculateEventBranchMetrics
    , calculateFailureRate
    , calculateMetrics
    , filterCompletedBuilds
    )

import Dict exposing (Dict)
import Html exposing (b)
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
    { -- frequency metrics
      buildFrequency : Int
    , deployFrequency : Int

    -- duration metrics
    , averageRuntime : Float
    , stdDeviationRuntime : Float
    , medianRuntime : Float
    , timeUsedOnFailedBuilds : Float

    -- relability
    , successRate : Float
    , failureRate : Float
    , averageTimeToRecovery : Float

    -- queue metrics
    , averageQueueTime : Float
    , medianQueueTime : Float

    -- aggregrates
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


{-| calculateMetrics : calculates metrics based on the list of builds passed in.
returns Nothing when the list is empty.
-}
calculateMetrics : List Vela.Build -> Maybe Metrics
calculateMetrics builds =
    if List.isEmpty builds then
        Nothing

    else
        let
            completedBuilds =
                filterCompletedBuilds builds

            -- frequency
            buildFrequency =
                calculateBuildFrequency builds

            deployFrequency =
                calculateDeployFrequency builds

            -- duration
            averageRuntime =
                calculateAverageRuntime completedBuilds

            stdDeviationRuntime =
                calculateStdDeviationRuntime completedBuilds

            medianRuntime =
                calculateMedianRuntime completedBuilds

            timeUsedOnFailedBuilds =
                calculateTimeUsedOnFailedBuilds builds

            -- reliability
            successRate =
                calculateSuccessRate builds

            failureRate =
                calculateFailureRate builds

            averageTimeToRecovery =
                calculateAverageTimeToRecovery builds

            -- queue metrics
            averageQueueTime =
                calculateAverageQueueTime builds

            medianQueueTime =
                calculateMedianQueueTime builds

            -- aggregrates
            eventBranchMetrics =
                calculateEventBranchMetrics builds

            byStatus =
                calculateMetricsByStatus builds
        in
        Just
            { overall =
                { buildFrequency = buildFrequency
                , deployFrequency = deployFrequency
                , averageRuntime = averageRuntime
                , stdDeviationRuntime = stdDeviationRuntime
                , medianRuntime = medianRuntime
                , timeUsedOnFailedBuilds = timeUsedOnFailedBuilds
                , successRate = successRate
                , failureRate = failureRate
                , averageTimeToRecovery = averageTimeToRecovery
                , averageQueueTime = averageQueueTime
                , medianQueueTime = medianQueueTime
                , eventBranchMetrics = eventBranchMetrics
                }
            , byStatus = byStatus
            }


filterCompletedBuilds : List Vela.Build -> List Vela.Build
filterCompletedBuilds builds =
    builds
        |> List.filter (\build -> build.status /= Vela.Pending)
        |> List.filter (\build -> build.status /= Vela.PendingApproval)
        |> List.filter (\build -> build.status /= Vela.Running)



-- frequency calculations


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
                |> List.filter (\build -> build.event == "deployment")
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



-- duration calculations


calculateAverageRuntime : List Vela.Build -> Float
calculateAverageRuntime builds =
    let
        total =
            List.foldl (\build acc -> acc + (build.finished - build.started)) 0 builds

        count =
            List.length builds
    in
    if count == 0 then
        0

    else
        toFloat (total // count)


calculateStdDeviationRuntime : List Vela.Build -> Float
calculateStdDeviationRuntime builds =
    builds
        |> List.map (\build -> toFloat (build.finished - build.started))
        |> calculateStdDeviation


calculateMedianRuntime : List Vela.Build -> Float
calculateMedianRuntime builds =
    builds
        |> List.map (\build -> toFloat (build.finished - build.started))
        |> calculateMedian


calculateTimeUsedOnFailedBuilds : List Vela.Build -> Float
calculateTimeUsedOnFailedBuilds builds =
    builds
        |> List.filter (\build -> build.status == Vela.Failure)
        |> List.foldl (\build acc -> acc + (build.finished - build.started)) 0
        |> toFloat



-- reliability calculations


calculateSuccessRate : List Vela.Build -> Float
calculateSuccessRate builds =
    let
        total =
            builds
                |> List.length
                |> toFloat

        succeeded =
            builds
                |> List.filter (\build -> build.status == Vela.Success)
                |> List.length
                |> toFloat
    in
    if total == 0 then
        0

    else
        (succeeded / total) * 100


calculateFailureRate : List Vela.Build -> Float
calculateFailureRate builds =
    let
        totalFailures =
            builds
                |> List.filter (\build -> build.status == Vela.Failure)
                |> List.length
                |> toFloat

        count =
            builds
                |> List.length
                |> toFloat
    in
    if count == 0 then
        0

    else
        (totalFailures / count) * 100


calculateAverageTimeToRecovery : List Vela.Build -> Float
calculateAverageTimeToRecovery builds =
    let
        failedBuilds =
            List.filter (\build -> build.status == Vela.Failure) builds

        successfulBuilds =
            List.filter (\build -> build.status == Vela.Success) builds

        -- group builds by branch
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

        -- find pairs of failed and subsequent successful builds within each branch
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

        -- calculate the time differences for each branch
        calculateBranchRecoveryTimes branch =
            let
                f =
                    Dict.get branch groupedFailedBuilds |> Maybe.withDefault []

                s =
                    Dict.get branch groupedSuccessfulBuilds |> Maybe.withDefault []
            in
            findRecoveryTimes (List.sortBy .created f) (List.sortBy .created s)

        -- aggregate recovery times across all branches
        allRecoveryTimes =
            Dict.keys groupedFailedBuilds
                |> List.concatMap calculateBranchRecoveryTimes

        -- compute the average of the time differences
        totalRecoveryTime =
            toFloat (List.sum allRecoveryTimes)

        count =
            toFloat (List.length allRecoveryTimes)
    in
    if count == 0 then
        0

    else
        totalRecoveryTime / count



-- queue time calculations


calculateAverageQueueTime : List Vela.Build -> Float
calculateAverageQueueTime builds =
    let
        total =
            builds
                |> List.filter (\build -> build.started > 0)
                |> List.foldl (\build acc -> acc + (build.started - build.enqueued)) 0

        count =
            List.length builds
    in
    if count == 0 then
        0

    else
        toFloat (total // count)


calculateMedianQueueTime : List Vela.Build -> Float
calculateMedianQueueTime builds =
    builds
        |> List.filter (\build -> build.started > 0)
        |> List.map (\build -> toFloat (build.started - build.enqueued))
        |> calculateMedian


calculateMetricsByStatus : List Vela.Build -> Dict String StatusMetrics
calculateMetricsByStatus builds =
    let
        -- group builds by status
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
    Dict.map (\_ buildList -> calculateMetricsForGroup buildList) groupedBuilds


calculateEventBranchMetrics : List Vela.Build -> Dict ( String, String ) EventBranchMetrics
calculateEventBranchMetrics builds =
    let
        -- group builds by (event, branch)
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

        -- calculate metrics for each group
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
    Dict.map (\_ buildsList -> calculateMetricsForGroup buildsList) groupedBuilds



-- generic helpers


calculateMedian : List Float -> Float
calculateMedian list =
    List.sort list
        |> Statistics.quantile 0.5
        |> Maybe.withDefault 0


calculateStdDeviation : List Float -> Float
calculateStdDeviation list =
    Statistics.deviation list
        |> Maybe.withDefault 0
