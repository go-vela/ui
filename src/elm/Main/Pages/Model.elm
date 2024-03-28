{--
SPDX-License-Identifier: Apache-2.0
--}


module Main.Pages.Model exposing (Model(..))

import Pages.Account.Authenticate
import Pages.Account.Login
import Pages.Account.Logout
import Pages.Account.Settings
import Pages.Account.SourceRepos
import Pages.Admin
import Pages.Dash.Secrets.Engine_.Org.Org_
import Pages.Dash.Secrets.Engine_.Org.Org_.Add
import Pages.Dash.Secrets.Engine_.Org.Org_.Name_
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add
import Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add
import Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_
import Pages.Home_
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
import Pages.Org_.Repo_.Pulls
import Pages.Org_.Repo_.Schedules
import Pages.Org_.Repo_.Schedules.Add
import Pages.Org_.Repo_.Schedules.Name_
import Pages.Org_.Repo_.Settings
import Pages.Org_.Repo_.Tags
import View exposing (View)


type Model
    = Home_ Pages.Home_.Model
    | Account_Authenticate Pages.Account.Authenticate.Model
    | Account_Login Pages.Account.Login.Model
    | Account_Logout Pages.Account.Logout.Model
    | Account_Settings Pages.Account.Settings.Model
    | Account_SourceRepos Pages.Account.SourceRepos.Model
    | Admin Pages.Admin.Model
    | Dash_Secrets_Engine__Org_Org_ { engine : String, org : String } Pages.Dash.Secrets.Engine_.Org.Org_.Model
    | Dash_Secrets_Engine__Org_Org__Add { engine : String, org : String } Pages.Dash.Secrets.Engine_.Org.Org_.Add.Model
    | Dash_Secrets_Engine__Org_Org__Name_ { engine : String, org : String, name : String } Pages.Dash.Secrets.Engine_.Org.Org_.Name_.Model
    | Dash_Secrets_Engine__Repo_Org__Repo_ { engine : String, org : String, repo : String } Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Model
    | Dash_Secrets_Engine__Repo_Org__Repo__Add { engine : String, org : String, repo : String } Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.Model
    | Dash_Secrets_Engine__Repo_Org__Repo__Name_ { engine : String, org : String, repo : String, name : String } Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.Model
    | Dash_Secrets_Engine__Shared_Org__Team_ { engine : String, org : String, team : String } Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Model
    | Dash_Secrets_Engine__Shared_Org__Team__Add { engine : String, org : String, team : String } Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.Model
    | Dash_Secrets_Engine__Shared_Org__Team__Name_ { engine : String, org : String, team : String, name : String } Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.Model
    | Org_ { org : String } Pages.Org_.Model
    | Org__Builds { org : String } Pages.Org_.Builds.Model
    | Org__Repo_ { org : String, repo : String } Pages.Org_.Repo_.Model
    | Org__Repo__Deployments { org : String, repo : String } Pages.Org_.Repo_.Deployments.Model
    | Org__Repo__Deployments_Add { org : String, repo : String } Pages.Org_.Repo_.Deployments.Add.Model
    | Org__Repo__Hooks { org : String, repo : String } Pages.Org_.Repo_.Hooks.Model
    | Org__Repo__Pulls { org : String, repo : String } Pages.Org_.Repo_.Pulls.Model
    | Org__Repo__Schedules { org : String, repo : String } Pages.Org_.Repo_.Schedules.Model
    | Org__Repo__Schedules_Add { org : String, repo : String } Pages.Org_.Repo_.Schedules.Add.Model
    | Org__Repo__Schedules_Name_ { org : String, repo : String, name : String } Pages.Org_.Repo_.Schedules.Name_.Model
    | Org__Repo__Settings { org : String, repo : String } Pages.Org_.Repo_.Settings.Model
    | Org__Repo__Tags { org : String, repo : String } Pages.Org_.Repo_.Tags.Model
    | Org__Repo__Build_ { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Model
    | Org__Repo__Build__Graph { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Graph.Model
    | Org__Repo__Build__Pipeline { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Pipeline.Model
    | Org__Repo__Build__Services { org : String, repo : String, build : String } Pages.Org_.Repo_.Build_.Services.Model
    | NotFound_ Pages.NotFound_.Model
    | Redirecting_
    | Loading_
