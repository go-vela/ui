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
        , FocusFragment
        , Logs
        , Org
        , Repo
        , RepoModel
        , StepNumber
        , Steps
        )



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | navigationKey : Navigation.Key
        , page : Page
        , time : Posix
        , zone : Zone
        , repo : RepoModel
        , shift : Bool
    }



-- TYPES


type alias Msgs msg =
    { collapseAllSteps : msg
    , expandAllSteps : ExpandAll msg
    , expandStep : Expand msg
    , collapseAllServices : msg
    , expandAllServices : ExpandAll msg
    , expandService : Expand msg
    , logsMsgs : LogsMsgs msg
    }


type alias LogsMsgs msg =
    { focusLine : FocusLine msg
    , download : Download msg
    , focusOn : FocusOn msg
    , followStep : FollowResource msg
    , followService : FollowResource msg
    }


type alias ExpandAll msg =
    Org -> Repo -> BuildNumber -> msg


type alias Expand msg =
    Org -> Repo -> BuildNumber -> String -> msg


type alias FollowResource msg =
    Int -> msg


type alias FocusLine msg =
    String -> msg


type alias Download msg =
    String -> String -> msg


type alias FocusOn msg =
    String -> msg
