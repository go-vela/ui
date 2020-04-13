{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.AddSecret exposing (view)

import Html exposing (Html, div)
import Pages.Secrets.Types exposing (Msg(..), PartialModel)


view : PartialModel a msg -> Html msg
view model =
    div [] []
