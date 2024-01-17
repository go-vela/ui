{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts exposing (..)

import Layouts.Default
import Layouts.Default.Org


type Layout msg
    = Default (Layouts.Default.Props msg)
    | Default_Org (Layouts.Default.Org.Props msg)


map : (msg1 -> msg2) -> Layout msg1 -> Layout msg2
map fn layout =
    case layout of
        Default data ->
            Default <| Layouts.Default.map fn data

        Default_Org data ->
            Default_Org <| Layouts.Default.Org.map fn data
