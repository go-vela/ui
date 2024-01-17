{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Model exposing (Model(..))

import Pages.Account.Login_
import Pages.Account.Settings_
import Pages.Account.SourceRepos_
import Pages.Home_
import Pages.NotFound_
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Deployments_
import Pages.Org_Repos


type Model
    = AccountLogin_ Pages.Account.Login_.Model
    | AccountSettings_ Pages.Account.Settings_.Model
    | AccountSourceRepos_ Pages.Account.SourceRepos_.Model
    | Home_ Pages.Home_.Model
    | Org_Repos { org : String } Pages.Org_Repos.Model
    | Org_Repo_ { org : String, repo : String } Pages.Org_.Repo_.Model
    | Org_Repo_Deployments_ { org : String, repo : String } Pages.Org_.Repo_.Deployments_.Model
    | Redirecting_
    | Loading_
    | NotFound_ Pages.NotFound_.Model
