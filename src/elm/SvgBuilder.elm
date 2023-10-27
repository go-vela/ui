{--
SPDX-License-Identifier: Apache-2.0
--}


module SvgBuilder exposing
    ( buildStatusAnimation
    , buildStatusToIcon
    , hookStatusToIcon
    , hookSuccess
    , recentBuildStatusToIcon
    , star
    , stepStatusToIcon
    , terminal
    , velaLogo
    )

import Html exposing (Html)
import Html.Attributes exposing (attribute)
import Svg exposing (svg)
import Svg.Attributes
    exposing
        ( class
        , cx
        , cy
        , d
        , height
        , r
        , strokeLinecap
        , strokeWidth
        , viewBox
        , width
        , x1
        , x2
        , y1
        , y2
        )
import Util exposing (ariaHidden)
import Vela exposing (Status)


{-| velaLogo: produces the svg for the Vela logo
-}
velaLogo : Int -> Html msg
velaLogo size =
    svg
        [ width <| String.fromInt size
        , height <| String.fromInt size
        , viewBox "0 0 1500 1500"
        , class "vela-logo"
        ]
        [ Svg.path [ class "vela-logo-star", d "M1477.22 329.54l-139.11-109.63 11.45-176.75-147.26 98.42-164.57-65.51 48.11 170.47-113.16 136.27 176.99 6.93 94.63 149.72 61.28-166.19 171.64-43.73z" ] []
        , Svg.path [ class "vela-logo-outer", d "M1174.75 635.12l-417.18 722.57a3.47 3.47 0 01-6 0L125.38 273.13a3.48 3.48 0 013-5.22h796.86l39.14-47.13-14.19-50.28h-821.8A100.9 100.9 0 0041 321.84L667.19 1406.4a100.88 100.88 0 00174.74 0l391.61-678.27z" ] []
        , Svg.path [ class "vela-logo-inner", d "M1087.64 497.29l-49.37-1.93-283.71 491.39L395.9 365.54H288.13l466.43 807.88 363.02-628.76-29.94-47.37z" ] []
        ]


{-| buildPending : produces svg icon for build status - pending
-}
buildPending : Html msg
buildPending =
    svg
        [ class "build-icon -pending"
        , viewBox "0 0 408 408"
        , width "44"
        , height "44"
        , ariaHidden
        ]
        [ Svg.path [ class "bg-fill", d "M51 153c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm306 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm-153 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51z" ]
            []
        ]


{-| buildRunning : produces svg icon for build status - running
-}
buildRunning : Html msg
buildRunning =
    svg
        [ class "build-icon -running"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , ariaHidden
        ]
        [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ d "M22 10v12.75L30 27" ] []
        ]


{-| buildSuccess : produces svg icon for build status - success
-}
buildSuccess : Html msg
buildSuccess =
    svg
        [ class "build-icon -success"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , ariaHidden
        ]
        [ Svg.path [ d "M15 20.1l6.923 6.9L42 5" ] []
        , Svg.path [ d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
        ]


{-| buildFailure : produces svg icon for build status - failure
-}
buildFailure : Html msg
buildFailure =
    svg
        [ class "build-icon -failure"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , ariaHidden
        ]
        [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ d "M15 15l14 14M29 15L15 29" ] []
        ]


{-| buildStatusAnimation : takes dashes as particles an svg meant to parallax scroll on a running build
-}
buildStatusAnimation : String -> String -> List String -> Html msg
buildStatusAnimation dashes y classNames =
    let
        runningAnimationClass =
            if dashes == "none" then
                class "-running-start"

            else
                class "-running-particles"

        classes =
            List.map (\c -> class c) classNames

        attrs =
            List.append classes
                [ class "build-animation"
                , strokeWidth "4"
                , height "4"
                , ariaHidden
                ]
    in
    svg
        attrs
        [ Svg.line [ runningAnimationClass, class dashes, x1 "0%", x2 "100%", y1 y, y2 y ] []
        ]


{-| stepPending : produces svg icon for step status - pending
-}
stepPending : Html msg
stepPending =
    svg
        [ class "-icon -pending"
        , viewBox "0 0 408 408"
        , width "32"
        , height "32"
        , ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M51 153c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm306 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm-153 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51z"
            ]
            []
        ]


{-| stepRunning : produces svg icon for step status - running
-}
stepRunning : Html msg
stepRunning =
    svg
        [ class "-icon -running"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M22 10v12.75L30 27"
            ]
            []
        ]


{-| stepSuccess : produces svg icon for step status - success
-}
stepSuccess : Html msg
stepSuccess =
    svg
        [ class "-icon -success"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M15 20.1l6.923 6.9L42 5"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666"
            ]
            []
        ]


{-| stepFailure : produces svg icon for step status - failure
-}
stepFailure : Html msg
stepFailure =
    svg
        [ class "-icon -failure"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M15 15l14 14M29 15L15 29"
            ]
            []
        ]


{-| stepSkipped : produces svg icon for step status - killed
Note: killed/skipped are the same thing.
-}
stepSkipped : Html msg
stepSkipped =
    svg
        [ class "-icon -skip"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke", d "M30.88 16.987l-9.744-5.625-9.747 9.383" ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M33 14l1 6h-6z"
            , Svg.Attributes.fill "var(--color-lavender)"
            ]
            []
        , Svg.rect
            [ attribute "vector-effect" "non-scaling-stroke"
            , Svg.Attributes.fill "var(--color-lavender)"
            , Svg.Attributes.x "9"
            , Svg.Attributes.y "28"
            , Svg.Attributes.width "5"
            , Svg.Attributes.height "5"
            , Svg.Attributes.rx "3.5"
            ]
            []
        , Svg.rect
            [ attribute "vector-effect" "non-scaling-stroke"
            , Svg.Attributes.fill "var(--color-lavender)"
            , Svg.Attributes.x "19"
            , Svg.Attributes.y "28"
            , Svg.Attributes.width "5"
            , Svg.Attributes.height "5"
            , Svg.Attributes.rx "3.5"
            ]
            []
        , Svg.rect
            [ attribute "vector-effect" "non-scaling-stroke"
            , Svg.Attributes.fill "var(--color-lavender)"
            , Svg.Attributes.x "29"
            , Svg.Attributes.y "28"
            , Svg.Attributes.width "5"
            , Svg.Attributes.height "5"
            , Svg.Attributes.rx "3.5"
            ]
            []
        ]


{-| hookSuccess: produces the svg for the hook status success
-}
hookSuccess : Html msg
hookSuccess =
    svg
        [ class "hook-status"
        , class "-success"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "20"
        , height "20"
        , ariaHidden
        ]
        [ Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M15 20.1l6.923 6.9L42 5" ] []
        , Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
        ]


{-| hookSkipped: produces the svg for the hook status skipped
-}
hookSkipped : Html msg
hookSkipped =
    svg
        [ class "hook-status"
        , class "-skipped"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "20"
        , height "20"
        , ariaHidden
        ]
        [ Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M15 20.1l6.923 6.9L42 5" ] []
        , Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
        ]


{-| hookFailure: produces the svg for the hook status failure
-}
hookFailure : Html msg
hookFailure =
    svg
        [ class "hook-status"
        , class "-failure"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "20"
        , height "20"
        ]
        [ Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M15 15l14 14M29 15L15 29" ] []
        ]


{-| buildHistoryPending : produces svg icon for build history status - pending
-}
buildHistoryPending : Int -> Html msg
buildHistoryPending _ =
    svg
        [ class "-icon -pending"
        , viewBox "0 0 28 28"
        , width "26"
        , height "26"
        ]
        [ Svg.circle [ class "pending-circle", cx "14", cy "14", r "2" ] [] ]


{-| buildHistoryRunning : produces svg icon for build history status - running
-}
buildHistoryRunning : Int -> Html msg
buildHistoryRunning _ =
    svg
        [ class "-icon -running"
        , strokeWidth "2"
        , viewBox "0 0 28 28"
        , width "26"
        , height "26"
        ]
        [ Svg.path [ d "M14 7v7.5l5 2.5" ] [] ]


{-| buildHistorySuccess : produces svg icon for build history status - running
-}
buildHistorySuccess : Int -> Html msg
buildHistorySuccess _ =
    svg
        [ class "-icon -success"
        , strokeWidth "2"
        , viewBox "0 0 28 28"
        , width "26"
        , height "26"
        ]
        [ Svg.path [ d "M6 15.9227L10.1026 20 22 7" ] [] ]


{-| buildHistoryFailure : produces svg icon for build history status - failure
-}
buildHistoryFailure : Int -> Html msg
buildHistoryFailure _ =
    svg
        [ class "-icon -failure"
        , strokeWidth "2"
        , viewBox "0 0 28 28"
        , width "26"
        , height "26"
        ]
        [ Svg.path [ d "M8 8l12 12M20 8L8 20" ] [] ]


{-| buildStatusToIcon : takes build status and returns Icon from SvgBuilder
-}
buildStatusToIcon : Status -> Html msg
buildStatusToIcon status =
    case status of
        Vela.Pending ->
            buildPending

        Vela.Running ->
            buildRunning

        Vela.Success ->
            buildSuccess

        Vela.Failure ->
            buildFailure

        Vela.Killed ->
            buildFailure

        Vela.Canceled ->
            buildFailure

        Vela.Error ->
            buildFailure


{-| recentBuildStatusToIcon : takes build status string and returns Icon from SvgBuilder
-}
recentBuildStatusToIcon : Status -> Int -> Html msg
recentBuildStatusToIcon status index =
    case status of
        Vela.Pending ->
            buildHistoryPending index

        Vela.Running ->
            buildHistoryRunning index

        Vela.Success ->
            buildHistorySuccess index

        Vela.Killed ->
            buildHistoryFailure index

        Vela.Failure ->
            buildHistoryFailure index

        Vela.Canceled ->
            buildHistoryFailure index

        Vela.Error ->
            buildHistoryFailure index


{-| stepStatusToIcon : takes build status and returns Icon from SvgBuilder
-}
stepStatusToIcon : Status -> Html msg
stepStatusToIcon status =
    case status of
        Vela.Pending ->
            stepPending

        Vela.Running ->
            stepRunning

        Vela.Success ->
            stepSuccess

        Vela.Failure ->
            stepFailure

        Vela.Killed ->
            stepSkipped

        Vela.Canceled ->
            stepFailure

        Vela.Error ->
            stepFailure


{-| hookStatusToIcon : takes hook status string and returns Icon from SvgBuilder
-}
hookStatusToIcon : String -> Html msg
hookStatusToIcon status =
    case status of
        "success" ->
            hookSuccess

        "skipped" ->
            hookSkipped

        _ ->
            hookFailure


{-| star: produces the svg for the favorites star
-}
star : Bool -> Html msg
star favorited =
    svg
        [ viewBox "0 0 30 30"
        , width "30"
        , height "30"
        , class "-favorite-toggle"
        , class "icon"
        , class "favorite-star"
        , class <|
            if favorited then
                "favorited"

            else
                ""
        , Svg.Attributes.class "-cursor"
        ]
        [ Svg.path
            [ d "M23.1527 26.2212l-1.557-9.0781 6.5957-6.4292-9.115-1.3245L15 1.1298l-4.0764 8.2596-9.115 1.3245 6.5957 6.4292-1.557 9.0781L15 21.9352l8.1527 4.286z"
            ]
            []
        ]


{-| terminal: produces the svg for the contextual help terminal icon
-}
terminal : Html msg
terminal =
    Svg.svg
        [ Svg.Attributes.fill "none"
        , height <| "18"
        , width <| "18"
        , Svg.Attributes.stroke "currentColor"
        , strokeLinecap "round"
        , Svg.Attributes.strokeLinejoin "round"
        , strokeWidth <| "2"
        , viewBox "0 0 24 24"
        ]
        [ Svg.polyline [ Svg.Attributes.points "4 17 10 11 4 5" ] []
        , Svg.line [ x1 "12", y1 "19", x2 "20", y2 "19" ] []
        ]
