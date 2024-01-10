module Shared.Model exposing (Model)

import Alerts exposing (Alert)
import Auth.Session exposing (Session(..))
import Browser.Events exposing (Visibility(..))
import RemoteData exposing (RemoteData(..), WebData)
import Time
    exposing
        ( Posix
        , Zone
        )
import Toasty exposing (Stack)
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



-- todo: comments


type alias Model =
    { session : Session
    , fetchingToken : Bool
    , fetchingInitialToken : Bool
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
    , theme : Theme
    , shift : Bool
    , visibility : Visibility
    , showHelp : Bool
    , showIdentity : Bool
    , favicon : Favicon
    , pipeline : PipelineModel
    , templates : PipelineTemplates
    , buildMenuOpen : List Int
    , token : Maybe String

    -- todo: these need to be refactored with Msg
    -- , schedulesModel : Pages.Schedules.Model.Model Msg
    -- , secretsModel : Pages.Secrets.Model.Model Msg
    -- , deploymentModel : Pages.Deployments.Model.Model Msg
    }
