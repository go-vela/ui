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
import Utils.Favicons as Favicons
import Utils.Theme as Theme
import Vela
    exposing
        ( CurrentUser
        , Org
        , PipelineModel
        , PipelineTemplates
        , Repo
        , RepoModel
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
    , theme : Theme.Theme
    , shift : Bool
    , visibility : Visibility
    , favicon : Favicons.Favicon
    , pipeline : PipelineModel
    , templates : PipelineTemplates
    , buildMenuOpen : List Int
    }
