{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Model exposing
    ( Model
    , Msg(..)
    , KeyValuePair
    , PartialModel
    , DeploymentForm
    , DeploymentResponse
    , defaultDeploymentForm
    )

import Auth.Session exposing (Session(..))
import Http
import Http.Detailed
import Pages exposing (Page(..))
import Vela exposing (Deployment, Engine, Org, Repo, Team)


-- TYPES

type alias KeyValuePair =
  { key: String
  , value: String
  }

{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | velaAPI : String
        , session : Session
        , page : Page
        , deploymentModel : Model msg
    }


{-| Model : record to hold page input arguments
-}
type alias Model msg =
    { org : Org
    , repo : Repo
    , team : Team
    , engine : Engine
    , form : DeploymentForm
    , deploymentResponse : Maybe (DeploymentResponse msg)
    }

{-| SecretForm : record to hold potential add/update secret fields
-}
type alias DeploymentForm =
    { commit : String
    , description : String
    , payload : List KeyValuePair
    , ref : String
    , target : String
    , task : String
    , parameterInput: KeyValuePair
    }


defaultDeploymentForm : DeploymentForm
defaultDeploymentForm =
    DeploymentForm "" "" [] "" "" "" {key="",value=""}



-- MSG


type alias DeploymentResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Deployment ) -> msg

type Msg
    = OnChangeStringField String String
    | OnChangeEvent String Bool
    | AddParameter KeyValuePair
    | RemoveParameter KeyValuePair
    | AddDeployment Engine
    | CancelDeployment
