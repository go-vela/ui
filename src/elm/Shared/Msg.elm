module Shared.Msg exposing (Msg(..))

import Alerts exposing (Alert)
import Errors exposing (Error)
import Http
import Http.Detailed
import Toasty as Alerting exposing (Stack)
import Vela exposing (CurrentUser)


type Msg
    = NoOp
      -- FAVORITES
    | ToggleFavorites { org : String, maybeRepo : Maybe String }
    | RepoFavoriteResponse { favorite : String, favorited : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, CurrentUser ))
      -- ERRORS
    | HandleError Error
      -- ALERTS
    | AlertsUpdate (Alerting.Msg Alert)
