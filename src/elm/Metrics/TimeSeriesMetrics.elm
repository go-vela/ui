{--
SPDX-License-Identifier: Apache-2.0
--}


module Metrics.TimeSeriesMetrics exposing (calculateAveragePerDay, calculateCountPerDay)

import Dict
import Time
import Utils.Helpers as Util


{-| calculateCountPerDay : creates a list of tuples to show ocurrence count of items per day. it takes current time, number of days,
a function to get the timestamp of an item, and a list of items.
-}
calculateCountPerDay :
    Time.Posix
    -> Int
    -> (a -> Int)
    -> List a
    -> List ( Time.Posix, Float )
calculateCountPerDay now daysToShow getTimestamp items =
    let
        today =
            Time.posixToMillis now // Util.oneDayMillis

        emptyDays =
            List.range 0 (daysToShow - 1)
                |> List.map (\offset -> today - offset)
                |> List.map (\day -> ( day, 0 ))
                |> Dict.fromList

        filledDays =
            items
                |> List.map (\item -> getTimestamp item // Util.oneDaySeconds)
                |> List.foldl
                    (\day acc ->
                        Dict.update day
                            (Maybe.map (\count -> count + 1))
                            acc
                    )
                    emptyDays
    in
    filledDays
        |> Dict.toList
        |> List.map
            (\( day, count ) ->
                ( Time.millisToPosix (day * Util.oneDayMillis), toFloat count )
            )
        |> List.sortBy (Time.posixToMillis << Tuple.first)


{-| calculateAveragePerDay : creates a list of tuples to show average of a given value per day. it takes current time,
number of days, a function to get the timestamp of an item, a function to get the value to capture,
a function to transform the value, and a list of items.
-}
calculateAveragePerDay :
    Time.Posix
    -> Int
    -> (a -> Int)
    -> (a -> Float)
    -> (Float -> Float)
    -> List a
    -> List ( Time.Posix, Float )
calculateAveragePerDay now daysToShow getTimestamp getValue transformValue items =
    let
        today =
            Time.posixToMillis now // Util.oneDayMillis

        emptyDays =
            List.range 0 (daysToShow - 1)
                |> List.map (\offset -> today - offset)
                |> List.map (\day -> ( day, [] ))
                |> Dict.fromList

        filledDays =
            items
                |> List.map (\item -> ( getTimestamp item // Util.oneDaySeconds, getValue item ))
                |> List.foldl
                    (\( day, value ) acc ->
                        let
                            currentValues =
                                Dict.get day acc
                                    |> Maybe.withDefault []
                        in
                        Dict.insert day (value :: currentValues) acc
                    )
                    emptyDays
    in
    filledDays
        |> Dict.toList
        |> List.map
            (\( day, values ) ->
                let
                    average =
                        case values of
                            [] ->
                                0

                            _ ->
                                List.sum values / toFloat (List.length values)
                in
                ( Time.millisToPosix (day * Util.oneDayMillis), transformValue average )
            )
        |> List.sortBy (Time.posixToMillis << Tuple.first)
