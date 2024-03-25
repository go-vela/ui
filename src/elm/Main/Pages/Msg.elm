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
import Pages.Org_.Repo_.Build_
import Pages.Org_.Repo_.Build_.Graph
import Pages.Org_.Repo_.Build_.Pipeline
import Pages.Org_.Repo_.Build_.Services
import Pages.Org_.Repo_.Deployments
import Pages.Org_.Repo_.Deployments.Add
import Pages.Org_.Repo_.Hooks
import Pages.Org_.Repo_.Schedules
import Pages.Org_.Repo_.Schedules.Add
import Pages.Org_.Repo_.Schedules.Edit_
import Pages.Org_.Repo_.Settings
import Pages.Secrets.Engine_.Org.Org_
import Pages.Secrets.Engine_.Org.Org_.Add
import Pages.Secrets.Engine_.Org.Org_.Edit_
import Pages.Secrets.Engine_.Repo.Org_.Repo_
import Pages.Secrets.Engine_.Repo.Org_.Repo_.Add
import Pages.Secrets.Engine_.Repo.Org_.Repo_.Edit_
import Pages.Secrets.Engine_.Shared.Org_.Team_
import Pages.Secrets.Engine_.Shared.Org_.Team_.Add
import Pages.Secrets.Engine_.Shared.Org_.Team_.Edit_


type Msg
    = AccountLogin Pages.Account.Login.Msg
    | AccountSettings Pages.Account.Settings.Msg
    | AccountSourceRepos Pages.Account.SourceRepos.Msg
    | Home Pages.Home.Msg
    | Org_ Pages.Org_.Msg
    | Org_Builds Pages.Org_.Builds.Msg
    | Org_Repo_ Pages.Org_.Repo_.Msg
    | Org_Repo_Deployments Pages.Org_.Repo_.Deployments.Msg
    | Org_Repo_DeploymentsAdd Pages.Org_.Repo_.Deployments.Add.Msg
    | Org_Repo_Schedules Pages.Org_.Repo_.Schedules.Msg
    | Org_Repo_SchedulesAdd Pages.Org_.Repo_.Schedules.Add.Msg
    | Org_Repo_SchedulesEdit_ Pages.Org_.Repo_.Schedules.Edit_.Msg
    | Org_Repo_Hooks Pages.Org_.Repo_.Hooks.Msg
    | Org_Repo_Settings Pages.Org_.Repo_.Settings.Msg
    | Org_Repo_Build_ Pages.Org_.Repo_.Build_.Msg
    | Org_Repo_Build_Services Pages.Org_.Repo_.Build_.Services.Msg
    | Org_Repo_Build_Pipeline Pages.Org_.Repo_.Build_.Pipeline.Msg
    | Org_Repo_Build_Graph Pages.Org_.Repo_.Build_.Graph.Msg
    | SecretsEngine_OrgOrg_ Pages.Secrets.Engine_.Org.Org_.Msg
    | SecretsEngine_OrgOrg_Add Pages.Secrets.Engine_.Org.Org_.Add.Msg
    | SecretsEngine_OrgOrg_Edit_ Pages.Secrets.Engine_.Org.Org_.Edit_.Msg
    | SecretsEngine_RepoOrg_Repo_ Pages.Secrets.Engine_.Repo.Org_.Repo_.Msg
    | SecretsEngine_RepoOrg_Repo_Add Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.Msg
    | SecretsEngine_RepoOrg_Repo_Edit_ Pages.Secrets.Engine_.Repo.Org_.Repo_.Edit_.Msg
    | SecretsEngine_SharedOrg_Team_ Pages.Secrets.Engine_.Shared.Org_.Team_.Msg
    | SecretsEngine_SharedOrg_Team_Add Pages.Secrets.Engine_.Shared.Org_.Team_.Add.Msg
    | SecretsEngine_SharedOrg_Team_Edit_ Pages.Secrets.Engine_.Shared.Org_.Team_.Edit_.Msg
    | NotFound_ Pages.NotFound_.Msg
