{--
SPDX-License-Identifier: Apache-2.0
--}


module ArtifactsTest exposing (suite)

import Expect
import Pages.Org_.Repo_.Build_.Artifacts as Artifacts
import Test exposing (..)
import Time


{-| Test constants
-}
currentTime : Int
currentTime =
    1715840944


currentTimeMillis : Int
currentTimeMillis =
    currentTime * 1000


currentTimePosix : Time.Posix
currentTimePosix =
    Time.millisToPosix currentTimeMillis


sevenDaysInSeconds : Int
sevenDaysInSeconds =
    7 * 24 * 60 * 60


suite : Test
suite =
    describe "Artifacts"
        [ describe "isArtifactExpired"
            [ test "artifact created just now is not expired" <|
                \_ ->
                    Artifacts.isArtifactExpired currentTimePosix currentTime
                        |> Expect.equal False
            , test "artifact created 1 hour ago is not expired" <|
                \_ ->
                    let
                        oneHourAgo =
                            currentTime - (60 * 60)
                    in
                    Artifacts.isArtifactExpired currentTimePosix oneHourAgo
                        |> Expect.equal False
            , test "artifact created 1 day ago is not expired" <|
                \_ ->
                    let
                        oneDayAgo =
                            currentTime - (24 * 60 * 60)
                    in
                    Artifacts.isArtifactExpired currentTimePosix oneDayAgo
                        |> Expect.equal False
            , test "artifact created 6 days 23 hours ago is not expired" <|
                \_ ->
                    let
                        almostSevenDaysAgo =
                            currentTime - (6 * 24 * 60 * 60 + 23 * 60 * 60)
                    in
                    Artifacts.isArtifactExpired currentTimePosix almostSevenDaysAgo
                        |> Expect.equal False
            , test "artifact created exactly 7 days ago is not expired" <|
                \_ ->
                    let
                        exactlySevenDaysAgo =
                            currentTime - sevenDaysInSeconds
                    in
                    Artifacts.isArtifactExpired currentTimePosix exactlySevenDaysAgo
                        |> Expect.equal False
            , test "artifact created 7 days and 1 second ago is expired" <|
                \_ ->
                    let
                        sevenDaysOneSec =
                            currentTime - sevenDaysInSeconds - 1
                    in
                    Artifacts.isArtifactExpired currentTimePosix sevenDaysOneSec
                        |> Expect.equal True
            , test "artifact created 8 days ago is expired" <|
                \_ ->
                    let
                        eightDaysAgo =
                            currentTime - (8 * 24 * 60 * 60)
                    in
                    Artifacts.isArtifactExpired currentTimePosix eightDaysAgo
                        |> Expect.equal True
            , test "artifact created 30 days ago is expired" <|
                \_ ->
                    let
                        thirtyDaysAgo =
                            currentTime - (30 * 24 * 60 * 60)
                    in
                    Artifacts.isArtifactExpired currentTimePosix thirtyDaysAgo
                        |> Expect.equal True
            , test "artifact with future created_at is not expired" <|
                \_ ->
                    let
                        futureTime =
                            currentTime + (24 * 60 * 60)
                    in
                    Artifacts.isArtifactExpired currentTimePosix futureTime
                        |> Expect.equal False
            , test "artifact created at timestamp 0 is expired" <|
                \_ ->
                    Artifacts.isArtifactExpired currentTimePosix 0
                        |> Expect.equal True
            , test "artifact with negative timestamp is expired" <|
                \_ ->
                    Artifacts.isArtifactExpired currentTimePosix -1000
                        |> Expect.equal True
            ]
        ]
