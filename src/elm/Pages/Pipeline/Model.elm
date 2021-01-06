{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Model exposing (Download, Expand, Get, Msgs, PartialModel)

import Alerts exposing (Alert)
import Browser.Dom as Dom
import Browser.Navigation as Navigation
import Errors exposing (Error)
import Focus exposing (FocusLineNumber)
import Http
import Http.Detailed
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Time exposing (Posix)
import Toasty as Alerting exposing (Stack)
import Vela
    exposing
        ( Build
        , BuildNumber
        , CurrentUser
        , FocusFragment
        , Org
        , PipelineModel
        , PipelineTemplates
        , Repo
        , RepoModel
        , Session
        , SourceRepositories
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
        , repo : RepoModel
        , shift : Bool
        , templates : PipelineTemplates
        , pipeline : PipelineModel
        , page : Page
        , toasties : Stack Alert
    }


type alias Msgs msg =
    { get : Get msg
    , expand : Expand msg
    , focusLineNumber : FocusLineNumber msg
    , showHideTemplates : msg
    , download : Download msg
    }


type alias Get msg =
    Org -> Repo -> Maybe BuildNumber -> Maybe String -> FocusFragment -> Bool -> msg


type alias Expand msg =
    Org -> Repo -> Maybe BuildNumber -> Maybe String -> FocusFragment -> Bool -> msg


type alias Download msg =
    String -> String -> msg
