{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Model exposing (Model)

import Auth.Session exposing (Session(..))
import Browser.Events exposing (Visibility(..))
import Components.Alerts exposing (Alert)
import RemoteData exposing (WebData)
import Time exposing (Posix, Zone)
import Toasty exposing (Stack)
import Utils.Favicons as Favicons
import Utils.Theme as Theme
import Vela


{-| Model : The main shared model for the application.
-}
type alias Model =
    { -- FLAGS
      velaAPIBaseURL : String
    , velaFeedbackURL : String
    , velaDocsURL : String
    , velaRedirect : String
    , velaLogBytesLimit : Int
    , velaMaxBuildLimit : Int
    , velaScheduleAllowlist : List ( String, String )

    -- BASE URL
    , velaUIBaseURL : String

    --AUTH
    , session : Session

    -- USER
    , user : WebData Vela.User

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

    -- SOURCE REPOS
    , sourceRepos : WebData Vela.SourceRepositories

    -- BUILDS
    , builds : WebData (List Vela.Build)

    -- HOOKS
    , hooks : WebData (List Vela.Hook)
    }
