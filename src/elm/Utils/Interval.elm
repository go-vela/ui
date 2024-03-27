{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Interval exposing (Interval(..), tickEveryFiveSeconds, tickEveryOneSecond)

import Time
import Utils.Helpers as Util


{-| Interval : a type to represent the interval at which a message is sent.
-}
type Interval
    = OneSecond
    | FiveSeconds


{-| tickEveryOneSecond : a message to be sent every second.
-}
tickEveryOneSecond : ({ time : Time.Posix, interval : Interval } -> msg) -> Sub msg
tickEveryOneSecond msg =
    Time.every Util.oneSecondMillis <|
        \time -> msg { time = time, interval = OneSecond }


{-| tickEveryFiveSeconds : a message to be sent every five seconds.
-}
tickEveryFiveSeconds : ({ time : Time.Posix, interval : Interval } -> msg) -> Sub msg
tickEveryFiveSeconds msg =
    Time.every Util.fiveSecondsMillis <|
        \time -> msg { time = time, interval = FiveSeconds }
