{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.DashboardRepoCard exposing (view)

import Html exposing (Html, div, text)
import Shared
import Vela


type alias Props =
    { card : Vela.DashboardRepoCard
    }


view : Shared.Model -> Props -> Html msg
view shared props =
    div [] [ text <| "Future " ++ props.card.org ++ "/" ++ props.card.name ++ " card" ]
