{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Auth.Session exposing
    ( Session(..)
    , SessionDetails
    , defaultSessionDetails
    , refreshAccessToken
    )

import Process
import Task
import Time exposing (Posix)


{-| SessionDetails defines the shape
of the session information
-}
type alias SessionDetails =
    { token : String
    , expiresAt : Posix
    , userName : String
    }


defaultSessionDetails : SessionDetails
defaultSessionDetails =
    SessionDetails "" (Time.millisToPosix 0) ""


{-| Session represents the possible
session states
-}
type Session
    = Unauthenticated
    | Authenticated SessionDetails



-- HELPERS


{-| refreshAccessToken is a helper to schedule
a job to try and refresh the access token
-}
refreshAccessToken : msg -> SessionDetails -> Cmd msg
refreshAccessToken msg sessionDetails =
    delayTask sessionDetails.expiresAt
        |> Task.attempt (\_ -> msg)


{-| delayTask takes a time in the future
and delays in one of the following ways:

  - 30s before future time
  - if future time is less than a minute,
    use half of the time left as the delay
  - immediately if future time is in past

-}
delayTask : Time.Posix -> Task.Task Never ()
delayTask timeout =
    let
        safeInterval =
            30 * 1000

        delay posixBy posixNow =
            let
                by =
                    Time.posixToMillis posixBy

                now =
                    Time.posixToMillis posixNow
            in
            max ((by - now) // 2) (by - now - safeInterval) |> max 0
    in
    Time.now |> Task.andThen (\now -> toFloat (delay timeout now) |> Process.sleep)
