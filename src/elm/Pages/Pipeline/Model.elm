{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Model exposing (Expand, Get, Msgs, PartialModel)

import Alerts exposing (Alert)
import Browser.Navigation as Navigation
import Errors exposing (Error)
import Focus exposing (FocusLineNumber)
import Http
import Http.Detailed
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Routes exposing (Route)
import Time exposing (Posix, Zone)
import Toasty as Alerting exposing (Stack)
import Vela
    exposing
        ( Build
        , BuildNumber
        , CurrentUser
        , FocusFragment
        , Org
        , PipelineModel
        , Repo
        , RepoModel
        , Session
        , SourceRepositories
        , Steps
        , Templates
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
        , zone : Zone
        , repo : RepoModel
        , shift : Bool
        , templates : ( WebData Templates, Error )
        , pipeline : PipelineModel
        , page : Page
        , toasties : Stack Alert
        , sourceRepos : WebData SourceRepositories
        , user : WebData CurrentUser
    }


type alias Msgs msg =
    { clickNavTab : Route -> msg
    , get : Get msg
    , expand : Expand msg
    , focusLineNumber : FocusLineNumber msg
    }


type alias Get msg =
    Org -> Repo -> Maybe BuildNumber -> Maybe String -> Bool -> FocusFragment -> msg


type alias Expand msg =
    Org -> Repo -> Maybe BuildNumber -> Maybe String -> Bool -> msg
