{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Util exposing (view)

import Html exposing (Html, div)
import Html.Attributes exposing (class)
import Route exposing (Route)
import Shared



-- VIEW


{-| view : renders the wrapper for placing other components in util space, if applicable.
-}
view : Shared.Model -> Route () -> List (Html msg) -> Html msg
view shared route buttons =
    div [ class "util" ]
        buttons
