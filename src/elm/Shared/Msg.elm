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
import RemoteData exposing (WebData)
import Time
import Toasty as Alerting
import Utils.Favicons as Favicons
import Utils.Favorites as Favorites
import Utils.Interval as Interval
import Utils.Theme as Theme
import Vela


{-| Msg : The main shared message type for the application.
-}
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
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.User ))
      -- SOURCE REPOS
    | UpdateSourceRepos { sourceRepos : WebData Vela.SourceRepositories }
      -- FAVORITES
    | UpdateFavorite { org : String, maybeRepo : Maybe String, updateType : Favorites.UpdateType }
    | UpdateFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.User ))
    | AddFavorites { favorites : List { org : String, maybeRepo : Maybe String } }
    | AddFavoritesResponse { favorites : List { org : String, maybeRepo : Maybe String } } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.User ))
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
    | HandleHttpError { error : Http.Detailed.Error String, shouldShowAlertFn : Http.Detailed.Error String -> Bool }
      -- REFRESH
    | Tick { interval : Interval.Interval, time : Time.Posix }
