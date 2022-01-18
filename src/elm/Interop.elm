{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


port module Interop exposing (onThemeChange, setFavicon, setRedirect, setTheme)

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
