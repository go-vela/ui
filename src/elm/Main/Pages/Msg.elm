module Main.Pages.Msg exposing (Msg(..))

import Pages.Account.Authenticate_
import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Deployments_
import Pages.Home_
import Pages.NotFound_


type Msg
    = Login_ Pages.Account.Login_.Msg
    | AccountSettings_ Pages.Account.Settings_.Msg
      -- | AccountAuthenticate_ Pages.Account.Authenticate_.Msg
    | Home_ Pages.Home_.Msg
    | Deployments_ Pages.Deployments_.Msg
    | NotFound_ Pages.NotFound_.Msg
