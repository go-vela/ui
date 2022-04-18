{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Model exposing (Download, Expand, Get, Msgs, PartialModel)

import Alerts exposing (Alert)
import Auth.Session exposing (Session)
import Browser.Navigation as Navigation
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Time exposing (Posix)
import Toasty exposing (Stack)
import Vela
    exposing
        ( BuildNumber
        , CurrentUser
        , FocusFragment
        , Org
        , PipelineModel
        , PipelineTemplates
        , Repo
        , RepoModel
        , SourceRepositories
        )



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | velaAPI : String
        , session : Session
        , user : WebData CurrentUser
        , sourceRepos : WebData SourceRepositories
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
    , focusLineNumber : Int -> msg
    , showHideTemplates : msg
    , download : Download msg
    }


type alias Get msg =
    Org -> Repo -> Maybe BuildNumber -> String -> FocusFragment -> Bool -> msg


type alias Expand msg =
    Org -> Repo -> Maybe BuildNumber -> String -> FocusFragment -> Bool -> msg


type alias Download msg =
    String -> String -> msg
