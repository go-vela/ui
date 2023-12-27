{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Deployments.Model exposing
    ( DeploymentForm
    , DeploymentResponse
    , Model
    , Msg(..)
    , PartialModel
    , defaultDeploymentForm
    )

import Shared
import Auth.Session exposing (Session)
import Http
import Http.Detailed
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Vela exposing (Deployment, KeyValuePair, Org, Repo, Repository, Team)



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | shared: Shared.Model
        , page : Page
        , deploymentModel : Model msg
    }


{-| Model : record to hold page input arguments
-}
type alias Model msg =
    { org : Org
    , repo : Repo
    , team : Team
    , form : DeploymentForm
    , repo_settings : WebData Repository
    , deploymentResponse : DeploymentResponse msg
    }


{-| DeploymentForm : record to hold potential deployment fields
-}
type alias DeploymentForm =
    { commit : String
    , description : String
    , payload : List KeyValuePair
    , ref : String
    , target : String
    , task : String
    , parameterInputKey : String
    , parameterInputValue : String
    }


defaultDeploymentForm : DeploymentForm
defaultDeploymentForm =
    DeploymentForm "" "" [] "" "" "" "" ""



-- MSG


type alias DeploymentResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Deployment ) -> msg


type Msg
    = OnChangeStringField String String
    | AddParameter DeploymentForm
    | RemoveParameter KeyValuePair
    | AddDeployment
