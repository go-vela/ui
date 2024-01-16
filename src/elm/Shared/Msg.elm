{--
SPDX-License-Identifier: Apache-2.0
--}


module Shared.Msg exposing (Msg(..))

import Browser.Dom
import Components.Alerts as Alerts exposing (Alert)
import Components.Favorites as Favorites
import Http
import Http.Detailed
import Toasty as Alerting
import Vela exposing (CurrentUser)


type Msg
    = NoOp
    | SetTheme Vela.Theme
      -- AUTH
    | Logout
    | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- USER
    | GetCurrentUser
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- FAVORITES
    | UpdateFavorites { org : String, maybeRepo : Maybe String, updateType : Favorites.UpdateType }
    | RepoFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- PAGINATION
    | GotoPage { pageNumber : Int }
      -- ALERTS
    | AddAlertError { content : String, addToastIfUnique : Bool }
    | AddAlertSuccess { content : String, addToastIfUnique : Bool }
    | AlertsUpdate (Alerting.Msg Alert)
      -- ERRORS
    | HandleHttpError (Http.Detailed.Error String)
      -- DOM
    | FocusOn String
    | FocusResult (Result Browser.Dom.Error ())
