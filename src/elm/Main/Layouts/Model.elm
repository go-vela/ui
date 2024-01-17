{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Layouts.Model exposing (..)

import Layouts.Default
import Layouts.Default.Org


type Model
    = Default { default : Layouts.Default.Model }
    | Default_Org { default : Layouts.Default.Model, org : Layouts.Default.Org.Model }
