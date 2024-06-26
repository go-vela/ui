{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Alerts exposing (Alert(..), Link, errorConfig, successConfig, view)

import FeatherIcons
import Html exposing (Html, a, button, div, h1, p, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Route.Path
import Toasty as Alerting
import Toasty.Defaults as Alerts
import Utils.Helpers as Util



-- TYPES


{-| Link : alias to represent a record for label and destination.
-}
type alias Link =
    ( Label, Destination )


{-| Label : alias for label string.
-}
type alias Label =
    String


{-| Destination : alias to represent route path.
-}
type alias Destination =
    Route.Path.Path


{-| Alert : alert status.
-}
type Alert
    = Success String String (Maybe Link)
    | Error String String



-- VIEW


{-| view : Default theme view handling the three alert variants.
-}
view : (String -> msg) -> Alert -> Html msg
view copy toast =
    case toast of
        Success title message link ->
            wrapAlert "-success" title message link Nothing

        Error title message ->
            wrapAlert "-error" title message Nothing <| Just copy


{-| wrapAlert : wraps an alert message in the appropriate html.
-}
wrapAlert : String -> String -> String -> Maybe Link -> Maybe (String -> msg) -> Html msg
wrapAlert variantClass title message link copy =
    let
        hyperlink =
            case link of
                Just l ->
                    toHyperlink l

                Nothing ->
                    text ""
    in
    div
        [ class "alert-container", class variantClass ]
        [ h1 [ class "-title" ] [ text title, copyButton message copy ]
        , if String.isEmpty message then
            text ""

          else
            p [ class "-message" ] [ text message, hyperlink ]
        ]


{-| copyButton : renders a copy button.
-}
copyButton : String -> Maybe (String -> msg) -> Html msg
copyButton copyContent copy =
    case copy of
        Just copyMsg ->
            button
                [ class "copy-button"
                , attribute "aria-label" <| "copy error message '" ++ copyContent ++ "' to clipboard "
                , class "button"
                , class "-icon"
                , onClick <| copyMsg copyContent
                , attribute "data-clipboard-text" copyContent
                ]
                [ FeatherIcons.copy
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml []
                ]

        Nothing ->
            text ""



-- HELPERS


{-| config : configurations for alert items, used for displaying notifications to the user.

    config delays automatic dismissal x seconds and applies unique container and item styles

    config applies animation overrides for pablen / toasty Elm package animations, bounceInRight and fadeOutRightBig

-}
config : Float -> Alerting.Config msg
config timeoutSeconds =
    Alerts.config
        |> Alerting.delay (Util.oneSecondMillis * timeoutSeconds)
        |> Alerting.containerAttrs [ class "alert-container-attributes" ]
        |> Alerting.itemAttrs [ Util.testAttribute "alert", class "animated", class "alert-item-attributes" ]


{-| successConfig : configurations for successful alert items.

    successConfig delays automatic dismissal 5 seconds and applies unique container and item styles

-}
successConfig : Alerting.Config msg
successConfig =
    config 5


{-| errorConfig : configurations for erroroneous alert items.

    errorConfig delays automatic dismissal 15 seconds and applies unique container and item styles

-}
errorConfig : Alerting.Config msg
errorConfig =
    config 15


{-| toHyperlink : takes Link and produces an Html hyperlink.
-}
toHyperlink : Link -> Html msg
toHyperlink ( label, destination ) =
    a [ Route.Path.href destination, Util.testAttribute "alert-hyperlink" ] [ text label ]
