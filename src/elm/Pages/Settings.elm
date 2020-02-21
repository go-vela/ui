{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Settings exposing (Msgs, view)

import FeatherIcons
import Html exposing (Html, button, div, h2, p, section, text, textarea)
import Html.Attributes exposing (attribute, class, readonly, rows, wrap)
import Html.Events exposing (onClick)
import Util
import Vela exposing (Copy, Session)


{-| Msgs : record containing msgs routeable to Main.elm
-}
type alias Msgs msg =
    { copy : Copy msg }


view : Maybe Session -> Msgs msg -> Html msg
view user actions =
    case user of
        Just u ->
            section [ class "settings", Util.testAttribute "user-token" ]
                [ h2 [ class "settings-title" ] [ text "Token" ]
                , p [ class "settings-description" ] [ text "Your token - don't share." ]
                , div [ class "form-controls", class "-no-x-pad" ]
                    [ textarea
                        [ class "form-control"
                        , class "copy-display"
                        , class "-is-expanded"
                        , rows 2
                        , readonly True
                        , wrap "soft"
                        ]
                        [ text u.token ]
                    , button
                        [ class "copy-button"
                        , class "button"
                        , class "-icon"
                        , class "-white"
                        , attribute "data-clipboard-text" u.token
                        , attribute "aria-label" "copy status badge markdown code"
                        , Util.testAttribute "copy-md"
                        , onClick <| actions.copy u.token
                        ]
                        [ FeatherIcons.copy
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml []
                        ]
                    ]
                ]

        _ ->
            div [] [ text "no settings you" ]
