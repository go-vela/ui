{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Msg exposing (Msg(..))

import Auth.Jwt
import Browser.Dom
import Components.Alerts exposing (Alert)
import Components.Favorites as Favorites
import Http
import Http.Detailed
import Time
import Toasty as Alerting
import Utils.Interval as Interval
import Vela exposing (CurrentUser)


type Msg
    = NoOp
      -- TIME
    | AdjustTimeZone { zone : Time.Zone }
    | AdjustTime { time : Time.Posix }
      --REFRESH
    | Tick { interval : Interval.Interval, time : Time.Posix }
      -- AUTH
    | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Auth.Jwt.JwtAccessToken ))
    | RefreshAccessToken
    | FinishAuthentication { code : Maybe String, state : Maybe String }
    | Logout
    | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- USER
    | GetCurrentUser
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- FAVORITES
    | UpdateFavorites { org : String, maybeRepo : Maybe String, updateType : Favorites.UpdateType }
    | RepoFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- BUILD GRAPH
    | BuildGraphInteraction Vela.BuildGraphInteraction
      -- PAGINATION
    | GotoPage { pageNumber : Int }
      -- THEME
    | SetTheme { theme : Vela.Theme }
      -- ALERTS
    | AddAlertError { content : String, addToastIfUnique : Bool }
    | AddAlertSuccess { content : String, addToastIfUnique : Bool }
    | AlertsUpdate (Alerting.Msg Alert)
      -- ERRORS
    | HandleHttpError (Http.Detailed.Error String)
      -- DOM
    | FocusOn { target : String }
    | FocusResult (Result Browser.Dom.Error ())
