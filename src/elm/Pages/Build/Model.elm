{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing (..)

import Browser.Navigation as Navigation
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Routes exposing (Route)
import Time exposing (Posix, Zone)
import Vela
    exposing
        ( Build
        , BuildNumber
        , CurrentUser
        , FocusFragment
        , Logs
        , Org
        , PipelineModel
        , Repo
        , RepoModel
        , SourceRepositories
        , StepNumber
        , Steps
        )



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | navigationKey : Navigation.Key
        , sourceRepos : WebData SourceRepositories
        , user : WebData CurrentUser
        , page : Page
        , time : Posix
        , zone : Zone
        , repo : RepoModel
        , shift : Bool
        , pipeline : PipelineModel
    }



-- TYPES


type alias Msgs msg =
    { clickBuildNavTab : Route -> msg
    , collapseAllSteps : msg
    , collapseAllServices : msg
    , expandAllSteps : ExpandAll msg
    , expandAllServices : ExpandAll msg
    , expandStep : Expand msg
    , expandService : Expand msg
    , logsMsgs : LogsMsgs msg
    }


type alias LogsMsgs msg =
    { focusLine : FocusLine msg
    , download : Download msg
    , focusOn : FocusOn msg
    , followStep : FollowStep msg
    }


type alias ExpandAll msg =
    Org -> Repo -> BuildNumber -> msg


type alias Expand msg =
    Org -> Repo -> BuildNumber -> String -> msg


type alias FollowStep msg =
    Int -> msg


type alias FocusLine msg =
    String -> msg


type alias Download msg =
    String -> String -> msg


type alias FocusOn msg =
    String -> msg


type alias GetLogs a msg =
    ( GetStepLogs a msg, GetStepsLogs a msg )


type alias GetStepLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Bool -> Cmd msg


type alias GetStepsLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> Steps -> FocusFragment -> Bool -> Cmd msg
