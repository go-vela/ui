module Shared.Msg exposing (Msg(..))

import Alerts exposing (Alert)
import Auth.Jwt exposing (JwtAccessToken, JwtAccessTokenClaims, extractJwtClaims)
import Errors exposing (Error)
import Http
import Http.Detailed
import Toasty as Alerting exposing (Stack)
import Vela exposing (CurrentUser, SourceRepositories)


type Msg
    = NoOp
      -- AUTH
    | Logout
    | LogoutResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
      -- USER
    | GetCurrentUser
    | CurrentUserResponse (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- SOURCE REPOS
    | GetUserSourceRepos
    | GetUserSourceReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
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
