{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts exposing (..)

import Layouts.Default
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo


type Layout msg
    = Default Layouts.Default.Props
    | Default_Build (Layouts.Default.Build.Props msg)
    | Default_Org (Layouts.Default.Org.Props msg)
    | Default_Repo (Layouts.Default.Repo.Props msg)


map : (msg1 -> msg2) -> Layout msg1 -> Layout msg2
map fn layout =
    case layout of
        Default data ->
            Default data

        Default_Build data ->
            Default_Build (Layouts.Default.Build.map fn data)

        Default_Org data ->
            Default_Org (Layouts.Default.Org.map fn data)

        Default_Repo data ->
            Default_Repo (Layouts.Default.Repo.map fn data)
