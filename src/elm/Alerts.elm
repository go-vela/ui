{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Alerts exposing (Alert(..), config, view)

import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class, href)
import Toasty as Alerting
import Toasty.Defaults as Alerts
import Util



-- TYPES


type alias Link =
    ( Label, Destination )


type alias Label =
    String


type alias Destination =
    String


type Alert
    = Success String String (Maybe Link)
    | Warning String String
    | Error String String



-- VIEW


{-| view : Default theme view handling the three alert variants.
-}
view : Alert -> Html msg
view toast =
    case toast of
        Success title message link ->
            wrapAlert "-success" title message link

        Warning title message ->
            wrapAlert "-warning" title message Nothing

        Error title message ->
            wrapAlert "-error" title message Nothing


{-| wrapAlert : wraps an alert message in the appropriate html.
-}
wrapAlert : String -> String -> String -> Maybe Link -> Html msg
wrapAlert variantClass title message link =
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
        [ h1 [ class "-title" ] [ text title ]
        , if String.isEmpty message then
            text ""

          else
            p [] [ text message, hyperlink ]
        ]



-- HELPERS


{-| config : configurations for alert items, used for displaying notifications to the user

    config delays automatic dismissal 15 seconds and applies unique container and item styles

-}
config : Alerting.Config msg
config =
    Alerts.config
        |> Alerting.delay (Util.oneSecondMillis * 30)
        |> Alerting.containerAttrs [ class "alert-container-attributes" ]
        |> Alerting.itemAttrs [ Util.testAttribute "alert", class "animated", class "alert-item-attributes" ]


{-| toHyperlink : takes Link and produces an Html hyperlink
-}
toHyperlink : Link -> Html msg
toHyperlink ( label, destination ) =
    a [ href destination, Util.testAttribute "alert-hyperlink" ] [ text label ]
