module Shared exposing (..)

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


--init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
--init flagsResult route =
--    ( {}
--    , Effect.none
--    )

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



init : Flags -> Url -> Model
init flags url =
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

    -- , schedulesModel = initSchedulesModel
    -- , secretsModel = initSecretsModel
    -- , deploymentModel = initDeploymentsModel
    , pipeline = defaultPipeline
    , templates = defaultPipelineTemplates
    }