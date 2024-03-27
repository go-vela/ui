{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Layouts.Msg exposing (..)

import Layouts.Default
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo


{-| Msg : The messages available for Layouts.
-}
type Msg
    = Default Layouts.Default.Msg
    | Default_Org Layouts.Default.Org.Msg
    | Default_Repo Layouts.Default.Repo.Msg
    | Default_Build Layouts.Default.Build.Msg
