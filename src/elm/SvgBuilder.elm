{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module SvgBuilder exposing
    ( Icon
    , buildFailure
    , buildHistoryFailure
    , buildHistoryPending
    , buildHistoryRunning
    , buildHistorySuccess
    , buildPending
    , buildRunning
    , buildStatusAnimation
    , buildStatusToIcon
    , buildSuccess
    , checkbox
    , hookStatusToIcon
    , radio
    , recentBuildStatusToIcon
    , stepFailure
    , stepPending
    , stepRunning
    , stepStatusToIcon
    , stepSuccess
    , toHtml
    , velaLogo
    )

import Html exposing (Html)
import Html.Attributes exposing (attribute)
import Svg exposing (Svg, circle, svg)
import Svg.Attributes
    exposing
        ( class
        , cx
        , cy
        , d
        , fill
        , height
        , r
        , stroke
        , strokeLinecap
        , strokeLinejoin
        , strokeWidth
        , viewBox
        , width
        , x1
        , x2
        , y1
        , y2
        )
import Vela exposing (Status)


{-| IconAttributes : customizable attributes of an svg icon
-}
type alias IconAttributes =
    { size : Float
    , sizeUnit : String
    , strokeWidth : Float
    , class : Maybe String
    , viewBox : String
    }


{-| Icon : type representing icon builder
-}
type Icon
    = Icon
        { attrs : IconAttributes
        , src : List (Svg Never)
        }


{-| toHtml : takes list of svg attributes and classes and maps it to Html that produces generic
-}
toHtml : List (Svg.Attribute msg) -> List String -> Icon -> Html msg
toHtml attributes classNames (Icon { src, attrs }) =
    let
        strSize =
            attrs.size |> String.fromFloat

        baseAttributes =
            [ fill "none"
            , height <| strSize ++ attrs.sizeUnit
            , width <| strSize ++ attrs.sizeUnit
            , stroke "currentColor"
            , strokeLinecap "round"
            , strokeLinejoin "round"
            , strokeWidth <| String.fromFloat attrs.strokeWidth
            ]

        attributesWithViewBox =
            if attrs.viewBox /= "" then
                viewBox attrs.viewBox :: baseAttributes

            else
                baseAttributes

        combinedAttributes =
            (case attrs.class of
                Just c ->
                    class c :: attributesWithViewBox

                Nothing ->
                    attributesWithViewBox
            )
                ++ attributes

        classes =
            List.map (\c -> class c) classNames

        svgAttributes =
            List.append combinedAttributes classes
    in
    src
        |> List.map (Svg.map never)
        |> svg svgAttributes


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
buildPending : Icon
buildPending =
    let
        attrs =
            IconAttributes 44 "" 2 (Just "build-icon -pending") "0 0 408 408"

        src =
            [ Svg.g [ class "status-svg", class "-build-status-icon", class "-pending" ]
                [ Svg.path [ d "M51 153c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm306 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm-153 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51z" ]
                    []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildRunning : produces svg icon for build status - running
-}
buildRunning : Icon
buildRunning =
    let
        attrs =
            IconAttributes 44 "" 2 (Just "build-icon") "0 0 44 44"

        src =
            [ Svg.g [ class "status-svg" ]
                [ Svg.path [ class "-linecap-round", d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
                , Svg.path [ class "-linecap-square", d "M22 10v12.75L30 27" ] []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildSuccess : produces svg icon for build status - success
-}
buildSuccess : Icon
buildSuccess =
    let
        attrs =
            IconAttributes 44 "" 2 (Just "build-icon") "0 0 44 44"

        src =
            [ Svg.g [ class "status-svg", class "-linecap-square" ]
                [ Svg.path [ d "M15 20.1l6.923 6.9L42 5" ] []
                , Svg.path [ class "-linecap-round", d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildFailure : produces svg icon for build status - failure
-}
buildFailure : Icon
buildFailure =
    let
        attrs =
            IconAttributes 44 "" 2 (Just "build-icon") "0 0 44 44"

        strokeA =
            "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"

        strokeB =
            "M15 15l14 14M29 15L15 29"

        src =
            [ Svg.g [ class "status-svg" ]
                [ Svg.path [ class "-linecap-round", d strokeA ] []
                , Svg.path [ class "-linecap-square", d strokeB ] []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildStatusAnimation : takes dashes as particles an svg meant to parallax scroll on a running build
-}
buildStatusAnimation : String -> String -> Icon
buildStatusAnimation dashes y =
    let
        viewSize =
            144

        strokeWidth =
            4

        runningAnimationClass =
            if dashes == "none" then
                class "-running-start"

            else
                class "-running-particles"

        attrs =
            IconAttributes viewSize "" strokeWidth (Just "build-animation") ""

        src =
            [ Svg.line [ runningAnimationClass, class dashes, x1 "0%", x2 "100%", y1 y, y2 y ] []
            ]
    in
    Icon { attrs = attrs, src = src }


{-| stepPending : produces svg icon for step status - pending
-}
stepPending : Icon
stepPending =
    let
        attrs =
            IconAttributes 32 "" 2 (Just "-icon -pending") "0 0 408 408"

        src =
            [ Svg.g [ class "status-svg", class "-step-icon", class "-pending" ]
                [ Svg.path [ d "M51 153c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm306 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51zm-153 0c-28.05 0-51 22.95-51 51s22.95 51 51 51 51-22.95 51-51-22.95-51-51-51z" ]
                    []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| stepRunning : produces svg icon for step status - running
-}
stepRunning : Icon
stepRunning =
    let
        attrs =
            IconAttributes 32 "" 2 (Just "-icon") "0 0 44 44"

        src =
            [ Svg.g [ class "status-svg", class "-step-icon", class "-running" ]
                [ Svg.path [ class "-linecap-round", d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
                , Svg.path [ class "-linecap-square", d "M22 10v12.75L30 27" ] []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| stepSuccess : produces svg icon for step status - success
-}
stepSuccess : Icon
stepSuccess =
    let
        attrs =
            IconAttributes 32 "" 2 (Just "-icon") "0 0 44 44"

        src =
            [ Svg.g [ class "status-svg", class "-linecap-square", class "-step-icon", class "-success" ]
                [ Svg.path [ d "M15 20.1l6.923 6.9L42 5" ] []
                , Svg.path [ class "-linecap-round", d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| stepFailure : produces svg icon for step status - failure
-}
stepFailure : Icon
stepFailure =
    let
        attrs =
            IconAttributes 32 "" 2 (Just "-icon") "0 0 44 44"

        strokeA =
            "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z"

        strokeB =
            "M15 15l14 14M29 15L15 29"

        src =
            [ Svg.g [ class "status-svg", class "-step-icon", class "-failure" ]
                [ Svg.path [ class "-linecap-round", d strokeA ] []
                , Svg.path [ class "-linecap-square", d strokeB ] []
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildHistoryPending : produces svg icon for build history status - pending
-}
buildHistoryPending : Int -> Icon
buildHistoryPending _ =
    let
        attrs =
            IconAttributes 28 "" 2 (Just "-icon -pending") "0 0 28 28"

        strokeA =
            "M-281-124h1440V900H-281z"

        strokeB =
            "M0 0h28v28H0z"

        src =
            [ Svg.g [ class "build-history-svg", class "-build-history-icon", class "-pending" ]
                [ Svg.path [ class "-path-1", d strokeA ] []
                , Svg.g []
                    [ Svg.path [ class "-path-2", d strokeB ] []
                    , Svg.circle [ class "-path-3", cx "14", cy "14", r "2" ] []
                    ]
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildHistoryRunning : produces svg icon for build history status - running
-}
buildHistoryRunning : Int -> Icon
buildHistoryRunning _ =
    let
        attrs =
            IconAttributes 28 "" 2 (Just "-icon -running") "0 0 28 28"

        strokeA =
            "M-309-124h1440V900H-309z"

        strokeB =
            "M0 0h28v28H0z"

        strokeC =
            "M14 7v7.5l5 2.5"

        src =
            [ Svg.g [ class "build-history-svg", class "-build-history-icon", class "-running" ]
                [ Svg.path [ class "-path-1", d strokeA ] []
                , Svg.g []
                    [ Svg.path [ class "-path-2", d strokeB ] []
                    , Svg.path [ class "-path-3", d strokeC ] []
                    ]
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildHistorySuccess : produces svg icon for build history status - running
-}
buildHistorySuccess : Int -> Icon
buildHistorySuccess _ =
    let
        attrs =
            IconAttributes 28 "" 2 (Just "-icon -success") "0 0 28 28"

        strokeA =
            "M-113-124h1440V900H-113z"

        strokeB =
            "M0 0h28v28H0z"

        strokeC =
            "M6 15.9227L10.1026 20 22 7"

        src =
            [ Svg.g [ class "build-history-svg", class "-build-history-icon", class "-success" ]
                [ Svg.path [ class "-path-1", d strokeA ] []
                , Svg.g []
                    [ Svg.path [ class "-path-2", d strokeB ] []
                    , Svg.path [ class "-path-3", d strokeC ] []
                    ]
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| buildHistoryFailure : produces svg icon for build history status - failure
-}
buildHistoryFailure : Int -> Icon
buildHistoryFailure _ =
    let
        attrs =
            IconAttributes 28 "" 2 (Just "-icon -failure") "0 0 28 28"

        strokeA =
            "M-253-124h1440V900H-253z"

        strokeB =
            "M0 0h28v28H0z"

        strokeC =
            "M8 8l12 12M20 8L8 20"

        src =
            [ Svg.g [ class "build-history-svg", class "-build-history-icon" ]
                [ Svg.path [ class "-path-1", d strokeA ] []
                , Svg.g []
                    [ Svg.path [ class "-path-2", d strokeB ] []
                    , Svg.path [ class "-path-3", d strokeC ] []
                    ]
                ]
            ]
    in
    Icon { attrs = attrs, src = src }


{-| radio : produces svg icon for input radio select
-}
radio : Bool -> Icon
radio checked =
    let
        attrs =
            IconAttributes 22 "" 1 (Just "-icon -radio") "0 0 28 28"

        src =
            if checked then
                [ Svg.g [ fill "none", Svg.Attributes.fillRule "evenodd" ]
                    [ Svg.path [ fill "#282828", d "M-414-909h1440V115H-414z" ] []
                    , Svg.g []
                        [ Svg.circle [ stroke "#0CF", cx "14", cy "14", r "13.5" ] []
                        , Svg.circle [ fill "#0CF", stroke "#0CF", cx "14", cy "14", r "7" ] []
                        ]
                    ]
                ]

            else
                [ Svg.g [ fill "none", Svg.Attributes.fillRule "evenodd" ]
                    [ Svg.circle [ stroke "#0CF", cx "14", cy "14", r "13.5" ] []
                    , Svg.circle [ stroke "#0CF", cx "14", cy "14", r "13.5" ] []
                    , Svg.path [ stroke "none", d "M.5.5h27v27H.5z" ] []
                    ]
                ]
    in
    Icon { attrs = attrs, src = src }


{-| checkbox : produces svg icon for input checkbox select
-}
checkbox : Bool -> Icon
checkbox checked =
    let
        attrs =
            IconAttributes 22 "" 1 (Just "-icon -radio") "0 0 28 28"

        src =
            if checked then
                [ Svg.g [ fill "none", Svg.Attributes.fillRule "evenodd" ]
                    [ Svg.path [ stroke "#0CF", fill "#0CF", d "M.5.5h27v27H.5z" ] []
                    , Svg.path [ stroke "#282828", Svg.Attributes.fillRule "2", Svg.Attributes.strokeLinecap "square", d "M6 15.9227L10.1026 20 22 7" ] []
                    ]
                ]

            else
                [ Svg.g [ fill "none", Svg.Attributes.fillRule "evenodd" ]
                    [ Svg.path [ stroke "#0CF", fill "none", d "M.5.5h27v27H.5z" ] []
                    ]
                ]
    in
    Icon { attrs = attrs, src = src }


{-| statusToIcon : takes build status string and returns Icon from SvgBuilder
-}
buildStatusToIcon : Status -> Icon
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

        Vela.Error ->
            buildFailure


{-| recentBuildStatusToIcon : takes build status string and returns Icon from SvgBuilder
-}
recentBuildStatusToIcon : Status -> Int -> Icon
recentBuildStatusToIcon status index =
    case status of
        Vela.Pending ->
            buildHistoryPending index

        Vela.Running ->
            buildHistoryRunning index

        Vela.Success ->
            buildHistorySuccess index

        Vela.Failure ->
            buildHistoryFailure index

        Vela.Error ->
            buildHistoryFailure index


{-| stepStatusToIcon : takes build status and returns Icon from SvgBuilder
-}
stepStatusToIcon : Status -> Icon
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

        Vela.Error ->
            stepFailure


{-| hookStatusToIcon : takes hook status string and returns Icon from SvgBuilder
-}
hookStatusToIcon : String -> Html msg
hookStatusToIcon status =
    case status of
        "success" ->
            hookSuccess

        _ ->
            hookFailure


{-| hookSuccess: produces the svg for the hook status success
-}
hookSuccess : Html msg
hookSuccess =
    Icon
        { attrs = IconAttributes 20 "" 2 (Just "hook-status -success") "0 0 44 44"
        , src =
            [ Svg.g []
                [ Svg.path [ d "M15 20.1l6.923 6.9L42 5" ] []
                , Svg.path [ d "M43 22v16.333A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1h25.666" ] []
                ]
            ]
        }
        |> toHtml [ attribute "aria-hidden" "true" ] []


{-| hookFailure: produces the svg for the hook status failure
-}
hookFailure : Html msg
hookFailure =
    Icon
        { attrs = IconAttributes 20 "" 2 (Just "hook-status -failure") "0 0 44 44"
        , src =
            [ Svg.g []
                [ Svg.path [ d "M5.667 1h32.666A4.668 4.668 0 0143 5.667v32.666A4.668 4.668 0 0138.333 43H5.667A4.668 4.668 0 011 38.333V5.667A4.668 4.668 0 015.667 1z" ] []
                , Svg.path [ d "M15 15l14 14M29 15L15 29" ] []
                ]
            ]
        }
        |> toHtml [ attribute "aria-hidden" "true" ] []
