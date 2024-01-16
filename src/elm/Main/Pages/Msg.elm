{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Msg exposing (Msg(..))

import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Account.SourceRepos_
import Pages.Home_
import Pages.NotFound_
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Deployments_


type Msg
    = AccountLogin_ Pages.Account.Login_.Msg
    | AccountSettings_ Pages.Account.Settings_.Msg
    | AccountSourceRepos_ Pages.Account.SourceRepos_.Msg
    | Home_ Pages.Home_.Msg
    | Org_Repo_ Pages.Org_.Repo_.Msg
    | Org_Repo_Deployments_ Pages.Org_.Repo_.Deployments_.Msg
    | NotFound_ Pages.NotFound_.Msg
