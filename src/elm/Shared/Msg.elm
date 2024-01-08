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
      -- PAGINATION
    | GotoPage { pageNumber : Int }
      -- AUTH
    | TokenResponse (Result (Http.Detailed.Error String) ( Http.Metadata, JwtAccessToken ))
      -- USER
    | GetCurrentUser
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- FAVORITES
    | ToggleFavorites { org : String, maybeRepo : Maybe String }
    | RepoFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- ERRORS
    | HandleError Error
      -- ALERTS
    | AlertsUpdate (Alerting.Msg Alert)
