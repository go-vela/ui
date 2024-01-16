{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Model exposing (Model)

import Auth.Session exposing (Session(..))
import Browser.Events exposing (Visibility(..))
import Components.Alerts as Alerts exposing (Alert)
import RemoteData exposing (RemoteData(..), WebData)
import Time
    exposing
        ( Posix
        , Zone
        )
import Toasty exposing (Stack)
import Vela
    exposing
        ( CurrentUser
        , Favicon
        , Org
        , PipelineModel
        , PipelineTemplates
        , Repo
        , RepoModel
        , Theme(..)
        )


type alias Model =
    { session : Session
    , user : WebData CurrentUser
    , toasties : Stack Alert
    , repo : RepoModel
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , velaScheduleAllowlist : List ( Org, Repo )
    , zone : Zone
    , time : Posix
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    , favicon : Favicon
    , pipeline : PipelineModel
    , templates : PipelineTemplates
    , buildMenuOpen : List Int

    -- todo: these need to be refactored with Msg
    -- , schedulesModel : Pages.Schedules.Model.Model Msg
    -- , secretsModel : Pages.Secrets.Model.Model Msg
    -- , deploymentModel : Pages.Deployments.Model.Model Msg
    }
