{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.BarChart exposing
    ( newBarChartConfig
    , view
    , withData
    , withHeight
    , withMaxY
    , withNumberUnit
    , withPadding
    , withPercentUnit
    , withTitle
    , withWidth
    )

import Axis
import DateFormat
import Float.Extra
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Scale exposing (defaultBandConfig)
import Time
import TypedSvg
import TypedSvg.Attributes
import TypedSvg.Attributes.InPx
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (AnchorAlignment(..), Transform(..))
import Utils.Helpers as Util


{-| UnitFormat defines what format the values in the chart should be displayed in.
-}
type UnitFormat
    = Unit
        { suffix : String
        , decimals : Int
        , formatter : Float -> String
        }


{-| percent: a unit format that displays values as percentages. note: 1 decimal place is displayed.
-}
percent : UnitFormat
percent =
    Unit
        { suffix = "%"
        , decimals = 1
        , formatter = \value -> Float.Extra.toFixedDecimalPlaces 1 value
        }


{-| minutes: a unit format that displays values as hours/minutes/seconds.
-}
minutes : UnitFormat
minutes =
    Unit
        { suffix = ""
        , decimals = 0
        , formatter = \value -> Util.formatTimeFromFloat (value * 60)
        }


{-| number: a unit format that displays values as numbers with the specified number of decimals.
-}
number : Int -> UnitFormat
number decimals =
    Unit
        { suffix = ""
        , decimals = decimals
        , formatter = \value -> Float.Extra.toFixedDecimalPlaces decimals value
        }


{-| BarChartConfig is an opaque type that configures a chart.
-}
type BarChartConfig
    = BarChartConfig
        { title : String
        , width : Float
        , height : Float
        , padding : Float
        , data : List ( Time.Posix, Float )
        , maybeMaxY : Maybe Float
        , unit : UnitFormat
        }


{-| newBarChart: creates a new BarChart configuration with default values.
-}
newBarChartConfig : BarChartConfig
newBarChartConfig =
    BarChartConfig
        { title = "BarChart"
        , width = 900
        , height = 400
        , padding = 30
        , data = []
        , maybeMaxY = Nothing
        , unit = minutes
        }


{-| withWidth: override the width of the chart (in pixels).
-}
withWidth : Float -> BarChartConfig -> BarChartConfig
withWidth v (BarChartConfig config) =
    BarChartConfig { config | width = v }


{-| withHeight: override the height of the chart (in pixels).
-}
withHeight : Float -> BarChartConfig -> BarChartConfig
withHeight v (BarChartConfig config) =
    BarChartConfig { config | height = v }


{-| withPadding: override the padding of the chart (in pixels).
-}
withPadding : Float -> BarChartConfig -> BarChartConfig
withPadding v (BarChartConfig config) =
    BarChartConfig { config | padding = v }


{-| withTitle: override the title of the chart.
-}
withTitle : String -> BarChartConfig -> BarChartConfig
withTitle v (BarChartConfig config) =
    BarChartConfig { config | title = v }


{-| withTitle: set the data for the chart.
-}
withData : List ( Time.Posix, Float ) -> BarChartConfig -> BarChartConfig
withData v (BarChartConfig config) =
    BarChartConfig { config | data = v }


{-| withTitle: override the max y-axis value (default value is inferred based on dataset).
-}
withMaxY : Float -> BarChartConfig -> BarChartConfig
withMaxY v (BarChartConfig config) =
    BarChartConfig { config | maybeMaxY = Just v }


{-| withPercentUnit: override unit for the values in the dataset to be percentages (default is time values).
-}
withPercentUnit : BarChartConfig -> BarChartConfig
withPercentUnit (BarChartConfig config) =
    BarChartConfig { config | unit = percent }


{-| withNumberUnit: override unit for the values in the dataset to be plain number format
with the given decimal places.
-}
withNumberUnit : Int -> BarChartConfig -> BarChartConfig
withNumberUnit v (BarChartConfig config) =
    BarChartConfig { config | unit = number v }


{-| view: takes title, width (optional), height (optional), data, optional maximum y-axis value,
unit as string, and returns a chart.
-}
view : BarChartConfig -> Html msg
view (BarChartConfig { title, width, height, padding, data, maybeMaxY, unit }) =
    let
        maxY =
            case maybeMaxY of
                Just max ->
                    max

                Nothing ->
                    List.maximum (List.map Tuple.second data)
                        |> Maybe.withDefault 0

        xScale : List ( Time.Posix, Float ) -> Scale.BandScale Time.Posix
        xScale m =
            List.map Tuple.first m
                |> Scale.band { defaultBandConfig | paddingInner = 0.1, paddingOuter = 0.1 } ( 0, width - 2 * padding )

        yScale : Scale.ContinuousScale Float
        yScale =
            Scale.linear ( height - 2 * padding, 0 ) ( 0, maxY )

        dateFormat : Time.Posix -> String
        dateFormat =
            DateFormat.format [ DateFormat.dayOfMonthFixed, DateFormat.text " ", DateFormat.monthNameAbbreviated ] Time.utc

        xAxis : List ( Time.Posix, Float ) -> Svg msg
        xAxis m =
            Axis.bottom [] (Scale.toRenderable dateFormat (xScale m))

        yAxis : Svg msg
        yAxis =
            Axis.left [ Axis.tickCount 5 ] yScale

        column : Scale.BandScale Time.Posix -> ( Time.Posix, Float ) -> Svg msg
        column scale ( date, value ) =
            let
                stringValue =
                    case unit of
                        Unit { formatter, suffix } ->
                            formatter value ++ suffix
            in
            TypedSvg.g [ TypedSvg.Attributes.class [ "column" ] ]
                [ TypedSvg.rect
                    [ TypedSvg.Attributes.InPx.x <| Scale.convert scale date
                    , TypedSvg.Attributes.InPx.y <| Scale.convert yScale value
                    , TypedSvg.Attributes.InPx.width <| Scale.bandwidth scale
                    , TypedSvg.Attributes.InPx.height <| height - Scale.convert yScale value - 2 * padding
                    ]
                    []
                , TypedSvg.text_
                    [ TypedSvg.Attributes.InPx.x <| Scale.convert (Scale.toRenderable dateFormat scale) date
                    , TypedSvg.Attributes.InPx.y <| Scale.convert yScale value - 5
                    , TypedSvg.Attributes.textAnchor AnchorMiddle
                    ]
                    [ text <| stringValue ]
                ]
    in
    div [ class "metrics-chart", Util.testAttribute "metrics-chart" ]
        [ div [ class "chart-header" ] [ text title ]
        , TypedSvg.svg [ TypedSvg.Attributes.viewBox 0 0 width height ]
            [ TypedSvg.g
                [ TypedSvg.Attributes.transform [ Translate (padding - 1) (height - padding) ]
                , TypedSvg.Attributes.InPx.strokeWidth 2
                , TypedSvg.Attributes.class [ "axis" ]
                ]
                [ xAxis data ]
            , TypedSvg.g
                [ TypedSvg.Attributes.transform [ Translate (padding - 1) padding ]
                , TypedSvg.Attributes.InPx.strokeWidth 2
                , TypedSvg.Attributes.class [ "axis" ]
                ]
                [ yAxis ]
            , TypedSvg.g
                [ TypedSvg.Attributes.transform [ Translate padding padding ]
                , TypedSvg.Attributes.class [ "series" ]
                ]
              <|
                List.map (column (xScale data)) data
            ]
        ]
