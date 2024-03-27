{--
SPDX-License-Identifier: Apache-2.0
--}


port module Interop exposing
    ( onGraphInteraction
    , onThemeChange
    , renderBuildGraph
    , setFavicon
    , setRedirect
    , setTheme
    )

import Json.Decode
import Json.Encode



-- To learn more about Elm ports, see the official guide:
-- <https://guide.elm-lang.org/interop/ports>
-- AUTH REDIRECT


{-| setRedirect : outbound.
-}
port setRedirect : Json.Encode.Value -> Cmd msg



-- THEME


{-| onThemeChange: inbound.
-}
port onThemeChange : (Json.Decode.Value -> msg) -> Sub msg


{-| setTheme : outbound.
-}
port setTheme : Json.Encode.Value -> Cmd msg



-- DYNAMIC FAVICON


{-| setFavicon : outbound.
-}
port setFavicon : Json.Encode.Value -> Cmd msg



-- VISUALIZATION


{-| renderBuildGraph : outbound.
-}
port renderBuildGraph : Json.Encode.Value -> Cmd msg


{-| onGraphInteraction : inbound.
-}
port onGraphInteraction : (Json.Decode.Value -> msg) -> Sub msg
