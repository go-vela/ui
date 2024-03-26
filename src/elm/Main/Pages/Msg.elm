{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Msg exposing (Msg(..))

import Pages.Account.Login
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Dash.Secrets.Engine_.Org.Org_
import Pages.Dash.Secrets.Engine_.Org.Org_.Add
import Pages.Dash.Secrets.Engine_.Org.Org_.Name_
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_
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
import Pages.Org_.Repo_.Schedules.Name_
import Pages.Org_.Repo_.Settings


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
    | Org_Repo_SchedulesName_ Pages.Org_.Repo_.Schedules.Name_.Msg
    | Org_Repo_Hooks Pages.Org_.Repo_.Hooks.Msg
    | Org_Repo_Settings Pages.Org_.Repo_.Settings.Msg
    | Org_Repo_Build_ Pages.Org_.Repo_.Build_.Msg
    | Org_Repo_Build_Services Pages.Org_.Repo_.Build_.Services.Msg
    | Org_Repo_Build_Pipeline Pages.Org_.Repo_.Build_.Pipeline.Msg
    | Org_Repo_Build_Graph Pages.Org_.Repo_.Build_.Graph.Msg
    | DashSecretsEngine_OrgOrg_ Pages.Dash.Secrets.Engine_.Org.Org_.Msg
    | DashSecretsEngine_OrgOrg_Add Pages.Dash.Secrets.Engine_.Org.Org_.Add.Msg
    | DashSecretsEngine_OrgOrg_Name_ Pages.Dash.Secrets.Engine_.Org.Org_.Name_.Msg
    | DashSecretsEngine_RepoOrg_Repo_ Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Msg
    | DashSecretsEngine_RepoOrg_Repo_Add Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.Msg
    | DashSecretsEngine_RepoOrg_Repo_Name_ Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.Msg
    | DashSecretsEngine_SharedOrg_Team_ Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Msg
    | DashSecretsEngine_SharedOrg_Team_Add Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.Msg
    | DashSecretsEngine_SharedOrg_Team_Name_ Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.Msg
    | NotFound_ Pages.NotFound_.Msg
