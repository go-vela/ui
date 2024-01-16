{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Layouts.Model exposing (..)

import Layouts.Default


type Model
    = Default { default : Layouts.Default.Model }
