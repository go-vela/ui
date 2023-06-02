{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing
    ( Download
    , Expand
    , ExpandAll
    , FocusLine
    , FocusOn
    , FollowResource
    , LogLine
    , LogsMsgs
    , Msgs
    , PartialModel
    )

import Ansi.Log
import Browser.Navigation as Navigation
import Html exposing (Html)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Time exposing (Posix, Zone)
import Vela exposing (BuildNumber, CurrentUser, Org, PipelineModel, Repo, RepoModel, SourceRepositories)



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | navigationKey : Navigation.Key
        , user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
        , page : Page
        , time : Posix
        , zone : Zone
        , repo : RepoModel
        , shift : Bool
        , buildMenuOpen : List Int
        , pipeline : PipelineModel
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
    , restartBuild : RestartBuild msg
    , cancelBuild : CancelBuild msg
    , toggle : Maybe Int -> Maybe Bool -> msg
    }


type alias LogsMsgs msg =
    { focusLine : FocusLine msg
    , download : Download msg
    , focusOn : FocusOn msg
    , followStep : FollowResource msg
    , followService : FollowResource msg
    }


type alias RestartBuild msg =
    Org -> Repo -> BuildNumber -> msg


type alias CancelBuild msg =
    Org -> Repo -> BuildNumber -> msg


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


type alias LogLine msg =
    { view : Html msg
    }
