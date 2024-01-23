{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Msg exposing (Msg(..))

import Pages.Account.Login
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Home
import Pages.NotFound_
import Pages.Org_
import Pages.Org_.Builds
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Audit
import Pages.Org_.Repo_.Build_
import Pages.Org_.Repo_.Build_.Services
import Pages.Org_.Repo_.Deployments
import Pages.Org_.Repo_.Deployments.Add
import Pages.Org_.Repo_.Schedules
import Pages.Org_.Repo_.Secrets
import Pages.Org_.Repo_.Secrets.Add
import Pages.Org_.Repo_.Secrets.Edit_
import Pages.Org_.Secrets
import Pages.Org_.Secrets.Add
import Pages.Org_.Secrets.Edit_


type Msg
    = AccountLogin Pages.Account.Login.Msg
    | AccountSettings Pages.Account.Settings.Msg
    | AccountSourceRepos Pages.Account.SourceRepos.Msg
    | Home Pages.Home.Msg
    | Org_ Pages.Org_.Msg
    | Org_Builds Pages.Org_.Builds.Msg
    | Org_Secrets Pages.Org_.Secrets.Msg
    | Org_SecretsAdd Pages.Org_.Secrets.Add.Msg
    | Org_SecretsEdit_ Pages.Org_.Secrets.Edit_.Msg
    | Org_Repo_ Pages.Org_.Repo_.Msg
    | Org_Repo_Deployments Pages.Org_.Repo_.Deployments.Msg
    | Org_Repo_DeploymentsAdd Pages.Org_.Repo_.Deployments.Add.Msg
    | Org_Repo_Schedules Pages.Org_.Repo_.Schedules.Msg
    | Org_Repo_Audit Pages.Org_.Repo_.Audit.Msg
    | Org_Repo_Secrets Pages.Org_.Repo_.Secrets.Msg
    | Org_Repo_SecretsAdd Pages.Org_.Repo_.Secrets.Add.Msg
    | Org_Repo_SecretsEdit_ Pages.Org_.Repo_.Secrets.Edit_.Msg
    | Org_Repo_Build_ Pages.Org_.Repo_.Build_.Msg
    | Org_Repo_Build_Services Pages.Org_.Repo_.Build_.Services.Msg
    | NotFound_ Pages.NotFound_.Msg
