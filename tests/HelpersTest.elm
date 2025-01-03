{--
SPDX-License-Identifier: Apache-2.0
--}


module HelpersTest exposing (suite)

import Expect
import Test exposing (..)
import Time
import Utils.Helpers



-- FormatRunTime Tests


currentTime : Int
currentTime =
    1715840944


currentTimeMillis : Int
currentTimeMillis =
    Utils.Helpers.secondsToMillis currentTime


suite : Test
suite =
    describe "BuildMetrics"
        [ describe "formatRunTime"
            [ test "started 1 second ago, finished is invalid (-1)" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) (currentTime - 1) -1
                        |> Expect.equal "00:01"
            , test "started 1 second ago, finished is invalid (0)" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) (currentTime - 1) 0
                        |> Expect.equal "00:01"
            , test "started and finished have invalid value (-1)" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) -1 -1
                        |> Expect.equal "--:--"
            , test "started and finished have invalid value (0)" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) 0 0
                        |> Expect.equal "--:--"
            , test "started is invalid (0), finished one second ago" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) 0 (currentTime - 1)
                        |> Expect.equal "--:--"
            , test "started is invalid (-1), finished one second ago" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) -1 (currentTime - 1)
                        |> Expect.equal "--:--"
            , test "finished time is before started time" <|
                \_ ->
                    Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) (currentTime - 1) (currentTime - 2)
                        |> Expect.equal "--:--"
            ]
        , describe "formatTimeFromFloat"
            [ test "zero seconds" <|
                \_ ->
                    Utils.Helpers.formatTimeFromFloat 0
                        |> Expect.equal "0s"
            , test "one minute" <|
                \_ ->
                    Utils.Helpers.formatTimeFromFloat 60
                        |> Expect.equal "1m 0s"
            , test "one hour" <|
                \_ ->
                    Utils.Helpers.formatTimeFromFloat 3600
                        |> Expect.equal "1h 0s"
            , test "negative value" <|
                \_ ->
                    Utils.Helpers.formatTimeFromFloat -10.5
                        |> Expect.equal "0s"
            , test "decimal seconds" <|
                \_ ->
                    Utils.Helpers.formatTimeFromFloat 125.7
                        |> Expect.equal "2m 5s"
            , test "large number" <|
                \_ ->
                    Utils.Helpers.formatTimeFromFloat 7384
                        |> Expect.equal "2h 3m 4s"
            ]
        ]
