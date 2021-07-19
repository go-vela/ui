{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Model exposing
    ( DeploymentForm
    , DeploymentResponse
    , Model
    , Msg(..)
    , PartialModel
    , PromoteDeploymentResponse
    , defaultDeploymentForm
    )

import Auth.Session exposing (Session(..))
import Http
import Http.Detailed
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Vela exposing (Build, Deployment, Engine, KeyValuePair, Org, Repo, Repository, Team)



-- TYPES


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


type alias PromoteDeploymentResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Build ) -> msg


type Msg
    = OnChangeStringField String String
    | AddParameter DeploymentForm
    | RemoveParameter KeyValuePair
    | AddDeployment
