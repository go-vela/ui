{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing (BuildModel, GetLogs, Msg(..), PartialModel)

import Browser.Navigation as Navigation
import RemoteData exposing (WebData)
import Time exposing (Posix)
import Vela
    exposing
        ( Build
        , BuildNumber
        , FocusFragment
        , Logs
        , Org
        , Repo
        , StepNumber
        , Steps
        )



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | navigationKey : Navigation.Key
        , time : Posix
        , build : WebData Build
        , steps : WebData Steps
        , logs : Logs
        , shift : Bool
        , followingStep : Int
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
    | FocusLogs String
    | DownloadLogs String String
    | FollowStep Int
    | ExpandAllSteps Org Repo BuildNumber
    | CollapseAllSteps
    | FocusOn String


type alias GetStepLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd msg


type alias GetStepsLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd msg


type alias GetLogs a msg =
    ( GetStepLogs a msg, GetStepsLogs a msg )
