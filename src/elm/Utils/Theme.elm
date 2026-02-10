{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Theme exposing (Theme(..), decodeTheme, encodeTheme, stringToTheme, toString)

import Json.Decode
import Json.Encode


{-| Theme : available theme options.
-}
type Theme
    = Light
    | Dark
    | System



-- THEME


{-| toString : convert a theme to a string
-}
toString : Theme -> String
toString theme =
    case theme of
        Light ->
            "theme-light"

        Dark ->
            "theme-dark"

        System ->
            "theme-system"


{-| stringToTheme : convert a string to a theme.
-}
stringToTheme : String -> Theme
stringToTheme theme =
    case theme of
        "theme-light" ->
            Light

        "theme-system" ->
            System

        _ ->
            Dark


{-| decodeTheme : decode the set theme from JSON.
-}
decodeTheme : Json.Decode.Decoder Theme
decodeTheme =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                Json.Decode.succeed <| stringToTheme str
            )


{-| encodeTheme : value to capture which theme is set.
-}
encodeTheme : Theme -> Json.Encode.Value
encodeTheme theme =
    case theme of
        Light ->
            Json.Encode.string "theme-light"

        System ->
            Json.Encode.string "theme-system"

        _ ->
            Json.Encode.string "theme-dark"
