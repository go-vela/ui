module Main.Pages.Model exposing (Model(..))

import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Account.SourceRepos_
import Pages.Deployments_
import Pages.Home_
import Pages.NotFound_


type Model
    = Login_ Pages.Account.Login_.Model
    | AccountSettings_ Pages.Account.Settings_.Model
    | AccountSourceRepos_ Pages.Account.SourceRepos_.Model
    | Home_ Pages.Home_.Model
    | Deployments_ Pages.Deployments_.Model
    | Redirecting_
    | Loading_
    | NotFound_ Pages.NotFound_.Model
