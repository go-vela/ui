module Shared.Msg exposing (Msg(..))

import Alerts exposing (Alert)
import Errors exposing (Error)
import Http
import Http.Detailed
import Toasty as Alerting
import Vela exposing (CurrentUser)


type Msg
    = NoOp
      -- AUTH
    | Logout
    | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- USER
    | GetCurrentUser
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- FAVORITES
    | ToggleFavorites { org : String, maybeRepo : Maybe String }
    | RepoFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- PAGINATION
    | GotoPage { pageNumber : Int }
      -- ERRORS
    | AddError (Http.Detailed.Error String)
    | HandleError Error
      -- ALERTS
    | AlertsUpdate (Alerting.Msg Alert)
    | ShowCopyToClipboardAlert { contentCopied : String }
