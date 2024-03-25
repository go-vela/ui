{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Interval exposing (Interval(..), tickEveryFiveSeconds, tickEveryOneSecond)

import Time
import Utils.Helpers as Util


type Interval
    = OneSecond
    | FiveSeconds


tickEveryOneSecond : ({ time : Time.Posix, interval : Interval } -> msg) -> Sub msg
tickEveryOneSecond msg =
    Time.every Util.oneSecondMillis <|
        \time -> msg { time = time, interval = OneSecond }


tickEveryFiveSeconds : ({ time : Time.Posix, interval : Interval } -> msg) -> Sub msg
tickEveryFiveSeconds msg =
    Time.every Util.fiveSecondsMillis <|
        \time -> msg { time = time, interval = FiveSeconds }
