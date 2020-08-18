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
    = ExpandStep Org Repo BuildNumber StepNumber String
    | FocusLogs String
    | FollowStep Int
    | FollowSteps Bool
    | ExpandAllSteps
    | CollapseAllSteps
    | FocusOn String
