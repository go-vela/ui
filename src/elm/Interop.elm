{--
SPDX-License-Identifier: Apache-2.0
--}


port module Interop exposing (onGraphInteraction, onThemeChange, renderBuildGraph, setFavicon, setRedirect, setTheme)

import Json.Decode as Decode
import Json.Encode as Encode



-- AUTH REDIRECT


{-| outbound
-}
port setRedirect : Encode.Value -> Cmd msg



-- THEME


{-| inbound
-}
port onThemeChange : (Decode.Value -> msg) -> Sub msg


{-| outbound
-}
port setTheme : Encode.Value -> Cmd msg



-- DYNAMIC FAVICON


{-| outbound
-}
port setFavicon : Encode.Value -> Cmd msg



-- VISUALIZATION


{-| outbound
-}
port renderBuildGraph : Encode.Value -> Cmd msg


{-| inbound
-}
port onGraphInteraction : (Decode.Value -> msg) -> Sub msg
