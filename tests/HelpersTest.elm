{--
SPDX-License-Identifier: Apache-2.0
--}


module HelpersTest exposing (..)

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


testFormatRunTimeFinishedInvalid : Test
testFormatRunTimeFinishedInvalid =
    test "formatRunTime: started 1 second ago, finished is invalid (-1)" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) (currentTime - 1) -1
                |> Expect.equal "00:01"


testFormatRunTimeFinishedInvalid2 : Test
testFormatRunTimeFinishedInvalid2 =
    test "formatRunTime: started 1 second ago, finished is invalid (0)" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) (currentTime - 1) 0
                |> Expect.equal "00:01"


testFormatRunTimeStartAndFinishedInvalid : Test
testFormatRunTimeStartAndFinishedInvalid =
    test "formatRunTime: started and finished have invalid value (-1)" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) -1 -1
                |> Expect.equal "--:--"


testFormatRunTimeStartAndFinishedInvalid2 : Test
testFormatRunTimeStartAndFinishedInvalid2 =
    test "formatRunTime: started and finished have invalid value (0)" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) 0 0
                |> Expect.equal "--:--"


testFormatRunTimeStartedInvalid : Test
testFormatRunTimeStartedInvalid =
    test "formatRunTime: started is invalid (0), finished one second ago" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) 0 (currentTime - 1)
                |> Expect.equal "--:--"


testFormatRunTimeStartedInvalid2 : Test
testFormatRunTimeStartedInvalid2 =
    test "formatRunTime: started is invalid (-1), finished one second ago" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) -1 (currentTime - 1)
                |> Expect.equal "--:--"


testFormatRunTimeFinishedBeforeStarted : Test
testFormatRunTimeFinishedBeforeStarted =
    test "formatRunTime: finished time is before started time" <|
        \_ ->
            Utils.Helpers.formatRunTime (Time.millisToPosix currentTimeMillis) (currentTime - 1) (currentTime - 2)
                |> Expect.equal "--:--"
