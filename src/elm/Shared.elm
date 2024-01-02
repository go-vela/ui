module Shared exposing (..)

-- todo: these need to be refined, only expose what is needed

import Alerts exposing (..)
import Auth.Session exposing (..)
import Browser.Dom exposing (..)
import Browser.Events exposing (Visibility(..))
import Dict exposing (..)
import Pages exposing (..)
import RemoteData exposing (..)
import Shared.Model
import Time exposing (..)
import Toasty as Alerting
import Url exposing (..)
import Util exposing (..)
import Vela exposing (..)



-- INIT


type alias Model =
    Shared.Model.Model



-- todo: comments, what goes in here, why


type alias Flags =
    { isDev : Bool
    , velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaTheme : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , velaScheduleAllowlist : String
    }



-- todo: comments


init : Flags -> Url -> Model
init flags url =
    -- todo: these need to be logically ordered (flags, session, user, data models, etc)
    { session = Unauthenticated
    , fetchingToken = String.length flags.velaRedirect == 0
    , user = NotAsked
    , sourceRepos = NotAsked
    , velaAPI = flags.velaAPI
    , velaFeedbackURL = flags.velaFeedbackURL
    , velaDocsURL = flags.velaDocsURL
    , velaRedirect = flags.velaRedirect
    , velaLogBytesLimit = flags.velaLogBytesLimit
    , velaMaxBuildLimit = flags.velaMaxBuildLimit
    , velaScheduleAllowlist = Util.stringToAllowlist flags.velaScheduleAllowlist
    , toasties = Alerting.initialState
    , zone = utc
    , time = millisToPosix 0
    , filters = Dict.empty
    , favoritesFilter = ""
    , repo = defaultRepoModel
    , entryURL = url
    , theme = stringToTheme flags.velaTheme
    , shift = False
    , visibility = Visible
    , showHelp = False
    , showIdentity = False
    , buildMenuOpen = []
    , favicon = defaultFavicon
    , pipeline = defaultPipeline
    , templates = defaultPipelineTemplates

    -- todo: these need to be refactored with Msg
    -- , schedulesModel = initSchedulesModel
    -- , secretsModel = initSecretsModel
    -- , deploymentModel = initDeploymentsModel
    }
