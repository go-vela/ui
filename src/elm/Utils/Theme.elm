{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Theme exposing (Theme(..), decodeTheme, encodeTheme, stringToTheme)

import Json.Decode
import Json.Encode


{-| Theme : available theme options.
-}
type Theme
    = Light
    | Dark



-- THEME


{-| stringToTheme : convert a string to a theme.
-}
stringToTheme : String -> Theme
stringToTheme theme =
    case theme of
        "theme-light" ->
            Light

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


{-| encodeTheme : a value to capture which theme is set.
-}
encodeTheme : Theme -> Json.Encode.Value
encodeTheme theme =
    case theme of
        Light ->
            Json.Encode.string "theme-light"

        _ ->
            Json.Encode.string "theme-dark"
