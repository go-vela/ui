{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Util exposing (view)

import Html exposing (Html, div)
import Html.Attributes exposing (class)
import Route exposing (Route)
import Shared


view : Shared.Model -> Route () -> List (Html msg) -> Html msg
view shared route buttons =
    div [ class "util" ]
        buttons
