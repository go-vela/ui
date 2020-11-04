{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing (GetLogs, Msg(..), RestartedBuildResponse, PartialModel)

import Browser.Navigation as Navigation
import Http
import Http.Detailed
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
        , Session
        , StepNumber
        , Steps
        )



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
        , logs : Logs
        , shift : Bool
        , followingStep : Int
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


type alias RestartedBuildResponse msg =
    Org -> Repo -> BuildNumber -> (Result (Http.Detailed.Error String) ( Http.Metadata, Build )) -> msg

type alias GetLogs a msg =
    ( GetStepLogs a msg, GetStepsLogs a msg )
