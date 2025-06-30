{--
SPDX-License-Identifier: Apache-2.0
--}


module BuildMetricsTest exposing (suite)

import Dict
import Expect
import Metrics.BuildMetrics exposing (..)
import Test exposing (..)
import Vela



-- Test Data


createSampleBuild : Int -> Int -> Int -> Vela.Status -> String -> String -> Vela.Build
createSampleBuild created duration queueTime buildStatus event branch =
    let
        now =
            created

        enqueuedAt =
            now + queueTime

        startedAt =
            enqueuedAt + queueTime

        finishedAt =
            startedAt + duration
    in
    { id = 1
    , repository_id = 1
    , number = 1
    , parent = 0
    , event = event
    , status = buildStatus
    , error = ""
    , enqueued = enqueuedAt
    , created = now
    , started = startedAt
    , finished = finishedAt
    , deploy = ""
    , clone = ""
    , source = ""
    , title = "Test Build"
    , message = ""
    , commit = "abc123"
    , sender = "test-user"
    , author = "test-user"
    , branch = branch
    , link = ""
    , ref = ""
    , base_ref = ""
    , host = ""
    , route = ""
    , runtime = ""
    , distribution = ""
    , approved_at = 0
    , approved_by = ""
    , deploy_payload = Nothing
    }


suite : Test
suite =
    describe "BuildMetrics"
        [ describe "calculateBuildFrequency"
            [ test "calculates daily build frequency" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Success "push" "main"
                            , createSampleBuild 86400 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172800 0 10 Vela.Success "push" "main"
                            ]
                    in
                    calculateBuildFrequency builds
                        |> Expect.equal 1
            , test "calculates daily build frequency (complex)" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Success "push" "main"
                            , createSampleBuild 14 0 10 Vela.Success "push" "main"
                            , createSampleBuild 86401 0 10 Vela.Success "push" "main"
                            , createSampleBuild 86403 0 10 Vela.Success "push" "main"
                            , createSampleBuild 86404 0 10 Vela.Success "push" "main"
                            , createSampleBuild 86405 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172800 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172801 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172802 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172803 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172804 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172805 0 10 Vela.Success "push" "main"
                            , createSampleBuild 172806 0 10 Vela.Success "push" "main"
                            ]
                    in
                    calculateBuildFrequency builds
                        |> Expect.equal 4
            , test "handles empty build list" <|
                \_ ->
                    calculateBuildFrequency []
                        |> Expect.equal 0
            ]
        , describe "calculateFailureRate"
            [ test "calculates failure rate percentage" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Success "push" "main"
                            , createSampleBuild 1 0 10 Vela.Failure "push" "main"
                            , createSampleBuild 2 0 10 Vela.Success "push" "main"
                            ]
                    in
                    calculateFailureRate builds
                        |> Expect.within (Expect.Absolute 0.01) 33.33
            , test "returns 0 for empty build list" <|
                \_ ->
                    calculateFailureRate []
                        |> Expect.equal 0
            ]
        , describe "calculateAverageRuntime"
            [ test "calculates average runtime excluding pending/running builds" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 15 10 Vela.Success "push" "main"
                            , createSampleBuild 1 15 10 Vela.Success "push" "main"
                            , createSampleBuild 2 15 0 Vela.Pending "push" "main"
                            ]
                    in
                    calculateAverageRuntime (filterCompletedBuilds builds)
                        |> Expect.equal 15
            , test "calculates average runtime for varied build run times" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 234 10 Vela.Success "push" "main"
                            , createSampleBuild 1 123 10 Vela.Success "push" "main"
                            , createSampleBuild 2 567 0 Vela.Pending "push" "main"
                            ]
                    in
                    calculateAverageRuntime (filterCompletedBuilds builds)
                        |> Expect.equal 178
            ]
        , describe "calculateMetrics"
            [ test "returns Nothing for empty build list" <|
                \_ ->
                    calculateMetrics []
                        |> Expect.equal Nothing
            , test "calculates all metrics for valid builds" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Success "push" "main"
                            , createSampleBuild 1 0 10 Vela.Success "push" "main"
                            ]
                    in
                    calculateMetrics builds
                        |> Maybe.map .overall
                        |> Maybe.map .successRate
                        |> Expect.equal (Just 100)
            ]
        , describe "calculateAverageTimeToRecovery"
            [ test "calculates average time between failure and success" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Failure "push" "main"
                            , createSampleBuild 100 0 10 Vela.Success "push" "main"
                            ]
                    in
                    calculateAverageTimeToRecovery builds
                        |> Expect.equal 100
            , test "calculates average time between failure and success (complex)" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Failure "push" "main"
                            , createSampleBuild 100 0 10 Vela.Success "push" "main"
                            , createSampleBuild 201 0 10 Vela.Success "push" "main"
                            , createSampleBuild 202 0 10 Vela.Success "push" "main"
                            , createSampleBuild 209 0 10 Vela.Success "push" "dev"
                            , createSampleBuild 210 0 10 Vela.Failure "push" "dev"
                            , createSampleBuild 250 0 10 Vela.Success "push" "main"
                            , createSampleBuild 300 0 10 Vela.Success "push" "dev"
                            , createSampleBuild 405 0 10 Vela.Success "push" "main"
                            ]
                    in
                    calculateAverageTimeToRecovery builds
                        |> Expect.equal 95
            ]
        , describe "calculateEventBranchMetrics"
            [ test "groups metrics by event and branch" <|
                \_ ->
                    let
                        builds =
                            [ createSampleBuild 0 0 10 Vela.Success "push" "main"
                            , createSampleBuild 1 0 10 Vela.Success "pull_request" "feature"
                            , createSampleBuild 2 0 10 Vela.Success "push" "main"
                            , createSampleBuild 3 0 10 Vela.Success "pull_request" "feature"
                            ]
                    in
                    calculateEventBranchMetrics builds
                        |> Dict.size
                        |> Expect.equal 2
            ]
        ]
