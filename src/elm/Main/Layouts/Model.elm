{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Layouts.Model exposing (..)

import Layouts.Default
import Layouts.Default.Admin
import Layouts.Default.Build
import Layouts.Default.Org
import Layouts.Default.Repo


type Model
    = Default { default : Layouts.Default.Model }
    | Default_Admin { default : Layouts.Default.Model, admin : Layouts.Default.Admin.Model }
    | Default_Build { default : Layouts.Default.Model, build : Layouts.Default.Build.Model }
    | Default_Org { default : Layouts.Default.Model, org : Layouts.Default.Org.Model }
    | Default_Repo { default : Layouts.Default.Model, repo : Layouts.Default.Repo.Model }
