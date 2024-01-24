{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Model exposing (Model)

import Auth.Session exposing (Session(..))
import Browser.Events exposing (Visibility(..))
import Components.Alerts exposing (Alert)
import RemoteData exposing (RemoteData(..), WebData)
import Time exposing (Posix, Zone)
import Toasty exposing (Stack)
import Utils.Favicons as Favicons
import Utils.Theme as Theme
import Vela


type alias Model =
    { -- FLAGS
      velaAPI : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , velaScheduleAllowlist : List ( String, String )

    --AUTH
    , session : Session

    -- USER
    , user : WebData Vela.CurrentUser

    -- TIME
    , zone : Zone
    , time : Posix

    -- KEY MODIFIERS
    , shift : Bool

    -- VISIBILITY
    , visibility : Visibility

    -- FAVICON
    , favicon : Favicons.Favicon

    -- THEME
    , theme : Theme.Theme

    -- ALERTS
    , toasties : Stack Alert
    }
