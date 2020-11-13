{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Model exposing (PartialModel, Error)

import Browser.Navigation as Navigation
import Pages exposing (Page(..))
import RemoteData exposing (WebData)
import Time exposing (Posix)
import Vela
    exposing
        ( Build
        , Org
        , Pipeline
        , Repo
        , Session
        , Steps
        , Templates
        )
import Toasty as Alerting exposing (Stack)
import Alerts exposing (Alert)



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
        , shift : Bool
        , templates :  (WebData Templates, Error)
        , pipeline : Pipeline
        , page : Page
        , toasties : Stack Alert
    }

type alias Error = String