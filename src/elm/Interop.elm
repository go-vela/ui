{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


port module Interop exposing (onSessionChange, storeSession)

import Json.Decode as Decode
import Json.Encode as Encode



-- inbound port


port onSessionChange : (Decode.Value -> msg) -> Sub msg



-- outbound port


port storeSession : Encode.Value -> Cmd msg
