{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Model exposing (Error, PartialModel, Msg(..))

import Alerts exposing (Alert)
import Browser.Navigation as Navigation
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Time exposing (Posix)
import Toasty as Alerting exposing (Stack)
import Vela
    exposing
        ( Build
        , Org
        , Pipeline
        , Repo
        , Session
        , Steps
        , Templates
        )
import Http
import Http.Detailed


-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | velaAPI : String
        , session : Maybe Session
        , navigationKey : Navigation.Key
        , time : Posix
        , build : WebData Build
        , steps : WebData Steps
        , shift : Bool
        , templates : ( WebData Templates, Error )
        , pipeline : Pipeline
        , page : Page
        , toasties : Stack Alert
    }


-- MSG


type Msg
    = GetPipelineConfig Org Repo (Maybe String) Bool
    | ExpandPipelineConfig Org Repo (Maybe String) Bool
    | GetPipelineConfigResponse Org Repo (Maybe String) (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ExpandPipelineConfigResponse Org Repo (Maybe String) (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | PipelineTemplatesResponse Org Repo (Result (Http.Detailed.Error String) ( Http.Metadata, Templates ))
    | FocusLine Int
    | Error Error
    | AlertsUpdate (Alerting.Msg Alert)

-- TYPES 
type alias Error =
    String