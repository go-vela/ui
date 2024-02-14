{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Msg exposing (Msg(..))

import Auth.Jwt
import Browser.Dom
import Browser.Events
import Components.Alerts
import Http
import Http.Detailed
import Time
import Toasty as Alerting
import Utils.Favicons as Favicons
import Utils.Favorites as Favorites
import Utils.Interval as Interval
import Utils.Theme as Theme
import Vela


type Msg
    = NoOp
      -- BROWSER
    | FocusOn { target : String }
    | FocusResult (Result Browser.Dom.Error ())
    | DownloadFile { filename : String, content : String, map : String -> String }
    | OnKeyDown { key : String }
    | OnKeyUp { key : String }
    | VisibilityChanged { visibility : Browser.Events.Visibility }
      -- FAVICON
    | UpdateFavicon { favicon : Favicons.Favicon }
      -- TIME
    | AdjustTimeZone { zone : Time.Zone }
    | AdjustTime { time : Time.Posix }
      -- AUTH
    | FinishAuthentication { code : Maybe String, state : Maybe String }
    | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Auth.Jwt.JwtAccessToken ))
    | RefreshToken
    | Logout { from : Maybe String }
    | LogoutResponse { from : Maybe String } (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- USER
    | GetCurrentUser
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.CurrentUser ))
      -- FAVORITES
    | UpdateFavorites { org : String, maybeRepo : Maybe String, updateType : Favorites.UpdateType }
    | RepoFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.CurrentUser ))
      -- BUILDS
    | GetRepoBuilds { org : String, repo : String, pageNumber : Maybe Int, perPage : Maybe Int, maybeEvent : Maybe String }
    | GetRepoBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))
      -- HOOKS
    | GetRepoHooks { org : String, repo : String, pageNumber : Maybe Int, perPage : Maybe Int, maybeEvent : Maybe String }
    | GetRepoHooksResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Hook ))
      -- THEME
    | SetTheme { theme : Theme.Theme }
      -- ALERTS
    | AddAlertError { content : String, addToastIfUnique : Bool, link : Maybe Components.Alerts.Link }
    | AddAlertSuccess { content : String, addToastIfUnique : Bool, link : Maybe Components.Alerts.Link }
    | AlertsUpdate (Alerting.Msg Components.Alerts.Alert)
      -- ERRORS
    | HandleHttpError (Http.Detailed.Error String)
      -- REFRESH
    | Tick { interval : Interval.Interval, time : Time.Posix }
