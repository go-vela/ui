{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Model exposing (GetLogs, Msg(..), PartialModel)

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
    }



-- TYPES


type Msg
    = ExpandStep Org Repo BuildNumber StepNumber String
    | FocusLogs String


type alias GetLogs a msg =
    PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> FocusFragment -> Cmd msg
