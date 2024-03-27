{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Layouts.Model exposing (..)

import Layouts.Default
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo


{-| Model : The model for the main layout.
-}
type Model
    = Default { default : Layouts.Default.Model }
    | Default_Org { default : Layouts.Default.Model, org : Layouts.Default.Org.Model }
    | Default_Repo { default : Layouts.Default.Model, repo : Layouts.Default.Repo.Model }
    | Default_Build { default : Layouts.Default.Model, repo : Layouts.Default.Build.Model }
