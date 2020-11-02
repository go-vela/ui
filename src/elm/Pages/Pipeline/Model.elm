{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.Model exposing (Msg(..), PartialModel, ExpandPipelineConfigResponse)

import Browser.Navigation as Navigation
import Http
import Http.Detailed
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
        , shift : Bool
        , pipeline : Pipeline
        , page : Page
    }



-- TYPES


type Msg
    = ExpandPipelineConfig Org Repo (Maybe String)


type alias ExpandPipelineConfigResponse msg =
    Org -> Repo -> Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
