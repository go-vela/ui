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
import Pages.Org_.Repo_.Audit
import Pages.Org_.Repo_.Build_
import Pages.Org_.Repo_.Build_.Graph
import Pages.Org_.Repo_.Build_.Pipeline
import Pages.Org_.Repo_.Build_.Services
import Pages.Org_.Repo_.Deployments
import Pages.Org_.Repo_.Deployments.Add
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
    | Org_Repo_SchedulesEdit_ { org : String, repo : String, name : String } Pages.Org_.Repo_.Schedules.Edit_.Model
    | Org_Repo_Audit { org : String, repo : String } Pages.Org_.Repo_.Audit.Model
    | Org_Repo_Settings { org : String, repo : String } Pages.Org_.Repo_.Settings.Model
    | Org_Repo_Build_ { org : String, repo : String, buildNumber : String } Pages.Org_.Repo_.Build_.Model
    | Org_Repo_Build_Services { org : String, repo : String, buildNumber : String } Pages.Org_.Repo_.Build_.Services.Model
    | Org_Repo_Build_Pipeline { org : String, repo : String, buildNumber : String } Pages.Org_.Repo_.Build_.Pipeline.Model
    | Org_Repo_Build_Graph { org : String, repo : String, buildNumber : String } Pages.Org_.Repo_.Build_.Graph.Model
    | SecretsEngine_OrgOrg_ { engine : String, org : String } Pages.Secrets.Engine_.Org.Org_.Model
    | SecretsEngine_OrgOrg_Add { engine : String, org : String } Pages.Secrets.Engine_.Org.Org_.Add.Model
    | SecretsEngine_OrgOrg_Edit_ { engine : String, org : String, name : String } Pages.Secrets.Engine_.Org.Org_.Edit_.Model
    | SecretsEngine_RepoOrg_Repo_ { engine : String, org : String, repo : String } Pages.Secrets.Engine_.Repo.Org_.Repo_.Model
    | SecretsEngine_RepoOrg_Repo_Add { engine : String, org : String, repo : String } Pages.Secrets.Engine_.Repo.Org_.Repo_.Add.Model
    | SecretsEngine_RepoOrg_Repo_Edit_ { engine : String, org : String, repo : String, name : String } Pages.Secrets.Engine_.Repo.Org_.Repo_.Edit_.Model
    | NotFound_ Pages.NotFound_.Model
    | Redirecting_
    | Loading_
