module TimeSeriesMetricsTest exposing (suite)

import Expect
import Metrics.TimeSeriesMetrics exposing (calculateAveragePerDay, calculateCountPerDay)
import Test exposing (Test, describe, test)
import Time
import Utils.Helpers as Util


suite : Test
suite =
    describe "TimeSeriesMetrics"
        [ describe "calculateCountPerDay"
            [ test "returns zero counts for empty list" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        result =
                            calculateCountPerDay now 3 identity []
                    in
                    Expect.equal (List.length result) 3
            , test "counts single item correctly" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        items =
                            [ Util.oneDaySeconds * 4 ]

                        result =
                            calculateCountPerDay now 3 identity items
                    in
                    Expect.equal
                        (List.map Tuple.second result)
                        [ 0, 1, 0 ]
            , test "aggregates multiple items on same day" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        items =
                            [ Util.oneDaySeconds * 4, Util.oneDaySeconds * 4, Util.oneDaySeconds * 4 ]

                        result =
                            calculateCountPerDay now 3 identity items
                    in
                    Expect.equal
                        (List.map Tuple.second result)
                        [ 0, 3, 0 ]
            ]
        , describe "calculateAveragePerDay"
            [ test "returns zero averages for empty list" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        result =
                            calculateAveragePerDay now 3 identity toFloat identity []
                    in
                    Expect.equal
                        (List.map Tuple.second result)
                        [ 0, 0, 0 ]
            , test "calculates average for single value per day" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        items =
                            [ Util.oneDaySeconds * 4 ]

                        result =
                            calculateAveragePerDay now 3 identity (always 10.0) identity items
                    in
                    Expect.equal
                        (List.map Tuple.second result)
                        [ 0, 10.0, 0 ]
            , test "calculates average for multiple values per day" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        items =
                            [ Util.oneDaySeconds * 4, Util.oneDaySeconds * 4, Util.oneDaySeconds * 4 ]

                        result =
                            calculateAveragePerDay now
                                3
                                identity
                                (\_ -> 15.0)
                                identity
                                items
                    in
                    Expect.equal
                        (List.map Tuple.second result)
                        [ 0, 15.0, 0 ]
            , test "applies value transformer correctly" <|
                \_ ->
                    let
                        now =
                            Time.millisToPosix (Util.oneDayMillis * 5)

                        items =
                            [ Util.oneDaySeconds * 4 ]

                        result =
                            calculateAveragePerDay now
                                3
                                identity
                                (always 10.0)
                                ((*) 2)
                                items
                    in
                    Expect.equal
                        (List.map Tuple.second result)
                        [ 0, 20.0, 0 ]
            ]
        ]
