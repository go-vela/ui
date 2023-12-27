module Shared.Model exposing (..)

import Alerts exposing (Alert)
import Auth.Session exposing (Session(..))
import Browser.Events exposing (Visibility(..))
import Browser.Navigation as Navigation
import Pages exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Time
    exposing
        ( Posix
        , Zone
        )
import Url exposing (Url)
import Vela
    exposing
        ( CurrentUser
        , Favicon
        , Org
        , PipelineModel
        , PipelineTemplates
        , Repo
        , RepoModel
        , RepoSearchFilters
        , SourceRepositories
        , Theme(..)
        )
import Toasty exposing (Stack)

type alias Model =
    { session : Session
    , fetchingToken : Bool
    , user : WebData CurrentUser
    , toasties : Stack Alert
    , sourceRepos : WebData SourceRepositories
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
    , filters : RepoSearchFilters
    , favoritesFilter : String
    , entryURL : Url
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    , showHelp : Bool
    , showIdentity : Bool
    , favicon : Favicon
    -- , schedulesModel : Pages.Schedules.Model.Model Msg
    -- , secretsModel : Pages.Secrets.Model.Model Msg
    -- , deploymentModel : Pages.Deployments.Model.Model Msg
    , pipeline : PipelineModel
    , templates : PipelineTemplates
    , buildMenuOpen : List Int
    }