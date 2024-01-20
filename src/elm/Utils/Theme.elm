module Utils.Theme exposing (..)

import Json.Decode
import Json.Encode


type Theme
    = Light
    | Dark



-- THEME


stringToTheme : String -> Theme
stringToTheme theme =
    case theme of
        "theme-light" ->
            Light

        _ ->
            Dark


decodeTheme : Json.Decode.Decoder Theme
decodeTheme =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                Json.Decode.succeed <| stringToTheme str
            )


encodeTheme : Theme -> Json.Encode.Value
encodeTheme theme =
    case theme of
        Light ->
            Json.Encode.string "theme-light"

        _ ->
            Json.Encode.string "theme-dark"
