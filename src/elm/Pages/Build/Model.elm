{--
SPDX-License-Identifier: Apache-2.0
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

import Browser.Navigation as Navigation
import Html exposing (Html)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Shared
import Time exposing (Posix, Zone)
import Vela exposing (BuildNumber, CurrentUser, Org, PipelineModel, Repo, RepoModel, SourceRepositories)



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | shared : Shared.Model
        , key : Navigation.Key
        , page : Page
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
    , approveBuild : ApproveBuild msg
    , restartBuild : RestartBuild msg
    , cancelBuild : CancelBuild msg
    , toggle : Maybe Int -> Maybe Bool -> msg
    , buildGraphMsgs : BuildGraphMsgs msg
    }


type alias LogsMsgs msg =
    { focusLine : FocusLine msg
    , download : Download msg
    , focusOn : FocusOn msg
    , followStep : FollowResource msg
    , followService : FollowResource msg
    }


type alias ApproveBuild msg =
    Org -> Repo -> BuildNumber -> msg


type alias BuildGraphMsgs msg =
    { refresh : Org -> Repo -> BuildNumber -> msg
    , rotate : msg
    , showServices : Bool -> msg
    , showSteps : Bool -> msg
    , updateFilter : String -> msg
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
