{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Update exposing
    ( init
    )

import Api
import Http
import List.Extra
import Pages.Deployments.Model exposing (DeploymentResponse, Model, Msg(..), PartialModel, defaultDeploymentForm)
import RemoteData exposing (RemoteData(..))
import Routes
import Util exposing (stringToMaybe)
import Vela
    exposing
        ( Deployment
        )



-- INIT


{-| init : takes msg updates from Main.elm and initializes secrets page input arguments
-}
init : DeploymentResponse msg -> Model msg
init deploymentResponse =
    Model "native"
        ""
        ""
        ""
        defaultDeploymentForm
        Nothing

