{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing (BuildModel, GetLogs, Msg(..), PartialModel)

import Alerts exposing (Alert)
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import Errors exposing (Error)
import Http
import Http.Detailed
import RemoteData exposing (WebData)
import Time exposing (Posix, Zone)
import Toasty as Alerting exposing (Stack)
import Vela
    exposing
        ( Build
        , BuildNumber
        , Favicon
        , FocusFragment
        , Log
        , Logs
        , Org
        , Repo
        , Session
        , Step
        , StepNumber
        , Steps
        )



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | navigationKey : Navigation.Key
        , velaAPI : String
        , session : Maybe Session
        , favicon : Favicon
        , time : Posix
        , zone : Zone
        , build : WebData Build
        , steps : WebData Steps
        , logs : Logs
        , shift : Bool
        , followingStep : Int
        , toasties : Stack Alert
    }


{-| BuildModel : model to contain build information that is crucial for rendering a pipeline
-}
type alias BuildModel =
    { org : Org
    , repo : Repo
    , buildNumber : BuildNumber
    , steps : Steps
    }



-- TYPES


type Msg
    = ExpandStep Org Repo BuildNumber StepNumber
    | BuildResponse Org Repo BuildNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Build ))
    | StepsResponse Org Repo BuildNumber (Maybe String) Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Steps ))
    | StepResponse Org Repo BuildNumber StepNumber (Result (Http.Detailed.Error String) ( Http.Metadata, Step ))
    | StepLogResponse StepNumber FocusFragment Bool (Result (Http.Detailed.Error String) ( Http.Metadata, Log ))
    | FocusLogs String
    | DownloadLogs String String
    | FollowStep Int
    | ExpandAllSteps Org Repo BuildNumber
    | CollapseAllSteps
    | FocusOn String
    | FocusResult (Result Dom.Error ())
    | Error Error
    | AlertsUpdate (Alerting.Msg Alert)


type alias GetStepLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd msg


type alias GetStepsLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd msg


type alias GetLogs a msg =
    ( GetStepLogs a msg, GetStepsLogs a msg )
