{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Msg exposing (Msg(..))

import Auth.Jwt
import Browser.Dom
import Browser.Events
import Components.Alerts exposing (Alert)
import Components.Favorites as Favorites
import Http
import Http.Detailed
import Time
import Toasty as Alerting
import Utils.Interval as Interval
import Utils.Theme as Theme
import Vela


type Msg
    = NoOp
      -- TIME
    | AdjustTimeZone { zone : Time.Zone }
    | AdjustTime { time : Time.Posix }
      --REFRESH
    | Tick { interval : Interval.Interval, time : Time.Posix }
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
      -- BUILD GRAPH
    | BuildGraphInteraction Vela.BuildGraphInteraction
      -- THEME
    | SetTheme { theme : Theme.Theme }
      -- ALERTS
    | AddAlertError { content : String, addToastIfUnique : Bool }
    | AddAlertSuccess { content : String, addToastIfUnique : Bool }
    | AlertsUpdate (Alerting.Msg Alert)
      -- ERRORS
    | HandleHttpError (Http.Detailed.Error String)
      -- DOM
    | FocusOn { target : String }
    | FocusResult (Result Browser.Dom.Error ())
      -- BROWSER
    | DownloadFile { filename : String, content : String, map : String -> String }
    | OnKeyDown { key : String }
    | OnKeyUp { key : String }
    | VisibilityChanged { visibility : Browser.Events.Visibility }
