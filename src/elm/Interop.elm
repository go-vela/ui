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



-- AUTH REDIRECT


{-| outbound
-}
port setRedirect : Json.Encode.Value -> Cmd msg



-- THEME


{-| inbound
-}
port onThemeChange : (Json.Decode.Value -> msg) -> Sub msg


{-| outbound
-}
port setTheme : Json.Encode.Value -> Cmd msg



-- DYNAMIC FAVICON


{-| outbound
-}
port setFavicon : Json.Encode.Value -> Cmd msg



-- VISUALIZATION


{-| outbound
-}
port renderBuildGraph : Json.Encode.Value -> Cmd msg


{-| inbound
-}
port onGraphInteraction : (Json.Decode.Value -> msg) -> Sub msg
