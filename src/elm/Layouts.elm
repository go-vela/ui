{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts exposing (..)

import Layouts.Default
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo


{-| Layout : defines the sub layouts.
-}
type Layout msg
    = Default Layouts.Default.Props
    | Default_Org (Layouts.Default.Org.Props msg)
    | Default_Repo (Layouts.Default.Repo.Props msg)
    | Default_Build (Layouts.Default.Build.Props msg)


{-| Used internally by Elm Land to connect layouts to the application.

Vist (<https://elm.land/concepts/layouts.html#usage-example-1>) for an example.

-}
map : (msg1 -> msg2) -> Layout msg1 -> Layout msg2
map fn layout =
    case layout of
        Default data ->
            Default data

        Default_Org data ->
            Default_Org <| Layouts.Default.Org.map fn data

        Default_Repo data ->
            Default_Repo <| Layouts.Default.Repo.map fn data

        Default_Build data ->
            Default_Build <| Layouts.Default.Build.map fn data
