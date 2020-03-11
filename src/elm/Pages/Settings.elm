{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Settings exposing (Msgs, view)

import FeatherIcons
import Html exposing (Html, br, button, div, em, h2, label, p, section, text, textarea)
import Html.Attributes exposing (attribute, class, for, id, readonly, rows, wrap)
import Html.Events exposing (onClick)
import Util
import Vela exposing (Copy, Session)


{-| Msgs : record containing msgs routeable to Main.elm
-}
type alias Msgs msg =
    { copy : Copy msg }


view : Maybe Session -> Msgs msg -> Html msg
view user actions =
    div [ class "my-settings", Util.testAttribute "settings" ]
        [ section [ class "settings", Util.testAttribute "user-token" ]
            [ h2 [ class "settings-title" ] [ text "Auth Token" ]
            , p [ class "settings-description" ] [ text "Your authentication token.", br [] [], em [] [ text "Updated every time you log in." ] ]
            , case user of
                Just u ->
                    div [ class "form-controls", class "-no-x-pad" ]
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
                            [ text u.token ]
                        , button
                            [ class "copy-button"
                            , class "button"
                            , class "-icon"
                            , class "-white"
                            , attribute "data-clipboard-text" u.token
                            , attribute "aria-label" "copy token"
                            , Util.testAttribute "copy-token"
                            , onClick <| actions.copy u.token
                            ]
                            [ FeatherIcons.copy
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml []
                            ]
                        ]

                _ ->
                    div [] [ text "unable to load token :(" ]
            ]
        ]
