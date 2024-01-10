module Shared.Msg exposing (Msg(..))

import Alerts exposing (Alert)
import Auth.Jwt exposing (JwtAccessToken, JwtAccessTokenClaims, extractJwtClaims)
import Errors exposing (Error)
import Http
import Http.Detailed
import Toasty as Alerting exposing (Stack)
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
    | HandleError Error
      -- ALERTS
    | AlertsUpdate (Alerting.Msg Alert)
    | ShowCopyToClipboardAlert { contentCopied : String }
