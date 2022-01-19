{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Settings exposing (Msgs, view)

import Auth.Session exposing (Session(..))
import DateFormat.Relative exposing (relativeTime)
import FeatherIcons
import Html exposing (Html, br, button, div, em, h2, label, p, section, text, textarea)
import Html.Attributes exposing (attribute, class, for, id, readonly, rows, wrap)
import Html.Events exposing (onClick)
import Time
import Util
import Vela exposing (Copy)


{-| Msgs : record containing msgs routeable to Main.elm
-}
type alias Msgs msg =
    { copy : Copy msg }


view : Session -> Time.Posix -> Msgs msg -> Html msg
view session now actions =
    div [ class "my-settings", Util.testAttribute "settings" ] <|
        case session of
            Authenticated auth ->
                let
                    timeRemaining =
                        if Time.posixToMillis auth.expiresAt < Time.posixToMillis now then
                            "Token has expired"

                        else
                            "Expires " ++ relativeTime now auth.expiresAt ++ "."
                in
                [ section [ class "settings", Util.testAttribute "user-token" ]
                    [ h2 [ class "settings-title" ] [ text "Authentication Token" ]
                    , p [ class "settings-description" ] [ text timeRemaining, br [] [], em [] [ text "Token will refresh before it expires." ] ]
                    , div [ class "form-controls", class "-no-x-pad" ]
                        [ label [ class "form-label", class "visually-hidden", for "token" ] [ text "Auth Token" ]
                        , textarea
                            [ class "form-control"
                            , class "copy-display"
                            , class "-is-expanded"
                            , id "token"
                            , rows 4
                            , readonly True
                            , wrap "soft"
                            ]
                            [ text auth.token ]
                        , button
                            [ class "copy-button"
                            , class "button"
                            , class "-icon"
                            , class "-white"
                            , attribute "data-clipboard-text" auth.token
                            , attribute "aria-label" "copy token"
                            , Util.testAttribute "copy-token"
                            , onClick <| actions.copy auth.token
                            ]
                            [ FeatherIcons.copy
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml []
                            ]
                        ]
                    ]
                ]

            Unauthenticated ->
                []
