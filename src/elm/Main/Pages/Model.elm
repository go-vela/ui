{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Model exposing (Model(..))

import Pages.Account.Login
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Home
import Pages.NotFound_
import Pages.Org_
import Pages.Org_.Builds
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Build_
import Pages.Org_.Repo_.Deployments
import Pages.Org_.Secrets
import Pages.Org_.Secrets.Add


type Model
    = AccountLogin Pages.Account.Login.Model
    | AccountSettings Pages.Account.Settings.Model
    | AccountSourceRepos Pages.Account.SourceRepos.Model
    | Home Pages.Home.Model
    | Org_ { org : String } Pages.Org_.Model
    | Org_Builds { org : String } Pages.Org_.Builds.Model
    | Org_Secrets { org : String } Pages.Org_.Secrets.Model
    | Org_SecretsAdd { org : String } Pages.Org_.Secrets.Add.Model
    | Org_Repo_ { org : String, repo : String } Pages.Org_.Repo_.Model
    | Org_Repo_Deployments { org : String, repo : String } Pages.Org_.Repo_.Deployments.Model
    | Org_Repo_Build_ { org : String, repo : String, buildNumber : String } Pages.Org_.Repo_.Build_.Model
    | Redirecting_
    | Loading_
    | NotFound_ Pages.NotFound_.Model
