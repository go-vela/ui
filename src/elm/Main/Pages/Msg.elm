module Main.Pages.Msg exposing (Msg(..))

import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Account.SourceRepos_
import Pages.Deployments_
import Pages.Home_
import Pages.NotFound_


type Msg
    = Login_ Pages.Account.Login_.Msg
    | AccountSettings_ Pages.Account.Settings_.Msg
    | AccountSourceRepos_ Pages.Account.SourceRepos_.Msg
    | Home_ Pages.Home_.Msg
    | Deployments_ Pages.Deployments_.Msg
    | NotFound_ Pages.NotFound_.Msg
