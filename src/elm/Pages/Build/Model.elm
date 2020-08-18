{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing (Msg(..))

import Vela
    exposing
        ( BuildNumber
        , Org
        , Repo
        , StepNumber
        )



-- TYPES


type Msg
    = ExpandStep Org Repo BuildNumber StepNumber
    | FocusLogs String
    | FollowStep Int
    | FollowSteps Org Repo BuildNumber Bool
    | ExpandAllSteps Org Repo BuildNumber
    | CollapseAllSteps
    | FocusOn String
