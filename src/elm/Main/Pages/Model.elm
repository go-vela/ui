{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Model exposing (Model(..))

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


type Model
    = AccountLogin Pages.Account.Login.Model
    | AccountSettings Pages.Account.Settings.Model
    | AccountSourceRepos Pages.Account.SourceRepos.Model
    | Home Pages.Home.Model
    | Org_ { org : String } Pages.Org_.Model
    | Org_Builds { org : String } Pages.Org_.Builds.Model
    | Org_Repo_ { org : String, repo : String } Pages.Org_.Repo_.Model
    | Org_Repo_Deployments { org : String, repo : String } Pages.Org_.Repo_.Deployments.Model
    | Org_Repo_DeploymentsAdd { org : String, repo : String } Pages.Org_.Repo_.Deployments.Add.Model
    | Org_Repo_Schedules { org : String, repo : String } Pages.Org_.Repo_.Schedules.Model
    | Org_Repo_SchedulesAdd { org : String, repo : String } Pages.Org_.Repo_.Schedules.Add.Model
    | Org_Repo_SchedulesName_ { org : String, repo : String, name : String } Pages.Org_.Repo_.Schedules.Name_.Model
    | Org_Repo_Hooks { org : String, repo : String } Pages.Org_.Repo_.Hooks.Model
    | Org_Repo_Settings { org : String, repo : String } Pages.Org_.Repo_.Settings.Model
    | Org_Repo_Build_ { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Model
    | Org_Repo_Build_Services { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Services.Model
    | Org_Repo_Build_Pipeline { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Pipeline.Model
    | Org_Repo_Build_Graph { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Graph.Model
    | SecretsEngine_OrgOrg_ { engine : String, org : String } Pages.Dash.Secrets.Engine_.Org.Org_.Model
    | SecretsEngine_OrgOrg_Add { engine : String, org : String } Pages.Dash.Secrets.Engine_.Org.Org_.Add.Model
    | SecretsEngine_OrgOrg_Name_ { engine : String, org : String, name : String } Pages.Dash.Secrets.Engine_.Org.Org_.Name_.Model
    | SecretsEngine_RepoOrg_Repo_ { engine : String, org : String, repo : String } Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Model
    | SecretsEngine_RepoOrg_Repo_Add { engine : String, org : String, repo : String } Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.Model
    | SecretsEngine_RepoOrg_Repo_Name_ { engine : String, org : String, repo : String, name : String } Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.Model
    | SecretsEngine_SharedOrg_Team_ { engine : String, org : String, team : String } Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Model
    | SecretsEngine_SharedOrg_Team_Add { engine : String, org : String, team : String } Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.Model
    | SecretsEngine_SharedOrg_Team_Name_ { engine : String, org : String, team : String, name : String } Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.Model
    | NotFound_ Pages.NotFound_.Model
    | Redirecting_
    | Loading_
