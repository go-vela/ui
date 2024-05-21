{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Svgs exposing
    ( buildStatusAnimation
    , buildStatusToIcon
    , buildVizLegendEdge
    , buildVizLegendNode
    , hookStatusToIcon
    , hookSuccess
    , recentBuildStatusToIcon
    , star
    , statusToIcon
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
        , x
        , x1
        , x2
        , y
        , y1
        , y2
        )
import Utils.Helpers as Util
import Vela



-- VIEW


{-| velaLogo : produces the svg for the Vela logo.
-}
velaLogo : Int -> Html msg
velaLogo size =
    svg
        [ width <| String.fromInt size
        , height <| String.fromInt size
        , viewBox "0 0 1048 1048"
        , class "vela-logo"
        ]
        [ Svg.path [ class "vela-logo-line", d "M272.7 175.2h-107a37.6 37.6 0 0 0-32 17.8 37.5 37.5 0 0 0-1.6 36.6L462.9 891a37.5 37.5 0 0 0 33.6 20.8c14.2 0 27.2-8 33.6-20.8l219.8-439.5 42 84-194.6 389.1a112.7 112.7 0 0 1-201.6 0L65 263.1a112.6 112.6 0 0 1 100.8-163H235l37.6 75.1Z" ] []
        , Svg.path [ class "vela-logo-line", d "M276.9 100.1h83.7l37.6 75.1h-83.7l-37.6-75Zm167.4 0h42l37.5 75.1H482l-37.7-75Zm-134 150.2 186.2 372.2L593.8 428l90.8-13.8-188.1 376.2-270-540h83.9Z" ] []
        , Svg.path [ class "vela-logo-star", d "m770.6 325.3-154.8 23.4 111.5-109.9-69.5-138.7h1.8L796.1 171 907.6 61 882 215.4l139 72-154.8 23.4-25.5 154.4-70.1-139.9Z" ] []
        ]


{-| buildPending : produces svg icon for build status - pending.
-}
buildPending : Html msg
buildPending =
    svg
        [ class "build-icon -pending"
        , viewBox "0 0 408 408"
        , width "44"
        , height "44"
        , Util.ariaHidden
        ]
        [ Svg.path [ class "bg-fill", d "M51 153c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm306 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm-153 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51z" ]
            []
        ]


{-| buildRunning : produces svg icon for build status - running.
-}
buildRunning : Html msg
buildRunning =
    svg
        [ class "build-icon -running"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , Util.ariaHidden
        ]
        [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ d "M22 10v12.75L30 27" ] []
        ]


{-| buildSuccess : produces svg icon for build status - success.
-}
buildSuccess : Html msg
buildSuccess =
    svg
        [ class "build-icon -success"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , Util.ariaHidden
        ]
        [ Svg.path [ d "M15 20.1l6.923 6.9L42 5" ] []
        , Svg.path [ d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
        ]


{-| buildFailure : produces svg icon for build status - failure.
-}
buildFailure : Html msg
buildFailure =
    svg
        [ class "build-icon -failure"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , Util.ariaHidden
        ]
        [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ d "M15 15l14 14M29 15L15 29" ] []
        ]


{-| buildCanceled : produces svg icon for build status - canceled.
-}
buildCanceled : Html msg
buildCanceled =
    svg
        [ class "build-icon -canceled"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , Util.ariaHidden
        ]
        [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ d "M15 15L29 29" ] []
        ]


{-| buildError : produces svg icon for build status - error.
-}
buildError : Html msg
buildError =
    svg
        [ class "build-icon -error"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "44"
        , height "44"
        , Util.ariaHidden
        ]
        [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
        , Svg.path [ d "M22 14V25" ] []
        , Svg.path [ d "M22 30V27" ] []
        ]


{-| buildStatusAnimation : takes dashes as particles an svg meant to parallax scroll on a running build.
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
                , Util.ariaHidden
                ]
    in
    svg
        attrs
        [ Svg.line [ runningAnimationClass, class dashes, x1 "0%", x2 "100%", y1 y, y2 y ] []
        ]


{-| stepPending : produces svg icon for step status - pending.
-}
stepPending : Html msg
stepPending =
    svg
        [ class "-icon -pending"
        , viewBox "0 0 408 408"
        , width "32"
        , height "32"
        , Util.ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M51 153c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm306 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm-153 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51z"
            ]
            []
        ]


{-| stepRunning : produces svg icon for step status - running.
-}
stepRunning : Html msg
stepRunning =
    svg
        [ class "-icon -running"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , Util.ariaHidden
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


{-| stepSuccess : produces svg icon for step status - success.
-}
stepSuccess : Html msg
stepSuccess =
    svg
        [ class "-icon -success"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , Util.ariaHidden
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


{-| stepFailure : produces svg icon for step status - failure.
-}
stepFailure : Html msg
stepFailure =
    svg
        [ class "-icon -failure"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , Util.ariaHidden
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


{-| stepError : produces svg icon for step status - error.
-}
stepError : Html msg
stepError =
    svg
        [ class "-icon -error"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , Util.ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M22 13V25"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M22 29V32"
            ]
            []
        ]


{-| stepCanceled : produces svg icon for step status - canceled.
-}
stepCanceled : Html msg
stepCanceled =
    svg
        [ class "-icon -canceled"
        , strokeWidth "2"
        , viewBox "0 0 44 44"
        , width "32"
        , height "32"
        , Util.ariaHidden
        ]
        [ Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"
            ]
            []
        , Svg.path
            [ attribute "vector-effect" "non-scaling-stroke"
            , d "M15 15l14 14"
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
        , Util.ariaHidden
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


{-| hookSuccess : produces the svg for the hook status success.
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
        , Util.ariaHidden
        ]
        [ Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M15 20.1l6.923 6.9L42 5" ] []
        , Svg.path [ attribute "vector-effect" "non-scaling-stroke", d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
        ]


{-| hookSkipped : produces the svg for the hook status skipped.
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
        , Util.ariaHidden
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
            , Svg.Attributes.x "10"
            , Svg.Attributes.y "28"
            , Svg.Attributes.width "4"
            , Svg.Attributes.height "4"
            , Svg.Attributes.rx "3"
            ]
            []
        , Svg.rect
            [ attribute "vector-effect" "non-scaling-stroke"
            , Svg.Attributes.fill "var(--color-lavender)"
            , Svg.Attributes.x "20"
            , Svg.Attributes.y "28"
            , Svg.Attributes.width "4"
            , Svg.Attributes.height "4"
            , Svg.Attributes.rx "3"
            ]
            []
        , Svg.rect
            [ attribute "vector-effect" "non-scaling-stroke"
            , Svg.Attributes.fill "var(--color-lavender)"
            , Svg.Attributes.x "30"
            , Svg.Attributes.y "28"
            , Svg.Attributes.width "4"
            , Svg.Attributes.height "4"
            , Svg.Attributes.rx "3"
            ]
            []
        ]


{-| hookFailure : produces the svg for the hook status failure.
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


{-| buildHistoryPending : produces svg icon for build history status - pending.
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


{-| buildHistoryRunning : produces svg icon for build history status - running.
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


{-| buildHistorySuccess : produces svg icon for build history status - success.
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


{-| buildHistoryFailure : produces svg icon for build history status - failure.
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


{-| buildHistoryError : produces svg icon for build history status - error.
-}
buildHistoryError : Int -> Html msg
buildHistoryError _ =
    svg
        [ class "-icon -error"
        , strokeWidth "2"
        , viewBox "0 0 28 28"
        , width "26"
        , height "26"
        ]
        [ Svg.path [ d "M14 8v7" ] []
        , Svg.path [ d "M14 18v2" ] []
        ]


{-| buildHistoryCanceled : produces svg icon for build history status - canceled.
-}
buildHistoryCanceled : Int -> Html msg
buildHistoryCanceled _ =
    svg
        [ class "-icon -canceled"
        , strokeWidth "2"
        , viewBox "0 0 28 28"
        , width "26"
        , height "26"
        ]
        [ Svg.path [ d "M8 8l12 12" ] [] ]


{-| buildStatusToIcon : takes build status and returns Icon from SvgBuilder.
-}
buildStatusToIcon : Vela.Status -> Html msg
buildStatusToIcon status =
    case status of
        Vela.Pending ->
            buildPending

        Vela.PendingApproval ->
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
            buildCanceled

        Vela.Error ->
            buildError


{-| recentBuildStatusToIcon : takes build status string and returns Icon from SvgBuilder.
-}
recentBuildStatusToIcon : Vela.Status -> Int -> Html msg
recentBuildStatusToIcon status index =
    case status of
        Vela.Pending ->
            buildHistoryPending index

        Vela.PendingApproval ->
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
            buildHistoryCanceled index

        Vela.Error ->
            buildHistoryError index


{-| statusToIcon : takes build status and returns Icon from SvgBuilder.
-}
statusToIcon : Vela.Status -> Html msg
statusToIcon status =
    case status of
        Vela.Pending ->
            stepPending

        Vela.PendingApproval ->
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
            stepCanceled

        Vela.Error ->
            stepError


{-| hookStatusToIcon : takes hook status string and returns Icon from SvgBuilder.
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


{-| star : produces the svg for the favorites star.
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


{-| terminal : produces the svg for the contextual help terminal icon.
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


{-| buildVizLegendNode : produces svg for a build graph legend node.
-}
buildVizLegendNode : List (Svg.Attribute msg) -> Html msg
buildVizLegendNode attrs =
    let
        size =
            22

        padding =
            4
    in
    svg
        [ class "elm-build-graph-legend-node"
        , width <| String.fromInt size
        , height <| String.fromInt size
        ]
        [ Svg.rect
            ([ width <| String.fromInt (size - padding)
             , height <| String.fromInt (size - padding)
             , x <| String.fromInt (padding // 2)
             , y <| String.fromInt (padding // 2)
             ]
                ++ attrs
            )
            []
        ]


{-| buildVizLegendEdge : produces line svg for a build graph legend edge.
-}
buildVizLegendEdge : List (Svg.Attribute msg) -> Html msg
buildVizLegendEdge attrs =
    let
        size =
            22

        padding =
            4

        length =
            22
    in
    svg
        [ width <| String.fromInt size
        , height <| String.fromInt size
        , class "elm-build-graph-legend-edge"
        ]
        [ Svg.line
            ([ x1 <| String.fromInt 0
             , x2 <| String.fromInt length
             , y1 <| String.fromInt (size // 2)
             , y2 <| String.fromInt (size // 2)
             , width <| String.fromInt (size - padding)
             , height <| String.fromInt (size - padding)
             ]
                ++ attrs
            )
            []
        ]
