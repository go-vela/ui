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
    = Account_Login Pages.Account.Login.Msg
    | Account_Settings Pages.Account.Settings.Msg
    | Account_SourceRepos Pages.Account.SourceRepos.Msg
    | Dash_Secrets_Engine__Org_Org_ Pages.Dash.Secrets.Engine_.Org.Org_.Msg
    | Dash_Secrets_Engine__Org_Org__Add Pages.Dash.Secrets.Engine_.Org.Org_.Add.Msg
    | Dash_Secrets_Engine__Org_Org__Name_ Pages.Dash.Secrets.Engine_.Org.Org_.Name_.Msg
    | Dash_Secrets_Engine__Repo_Org__Repo_ Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Msg
    | Dash_Secrets_Engine__Repo_Org__Repo__Add Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Add.Msg
    | Dash_Secrets_Engine__Repo_Org__Repo__Name_ Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_.Name_.Msg
    | Dash_Secrets_Engine__Shared_Org__Team_ Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Msg
    | Dash_Secrets_Engine__Shared_Org__Team__Add Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Add.Msg
    | Dash_Secrets_Engine__Shared_Org__Team__Name_ Pages.Dash.Secrets.Engine_.Shared.Org_.Team_.Name_.Msg
    | Home Pages.Home.Msg
    | Org_ Pages.Org_.Msg
    | Org__Builds Pages.Org_.Builds.Msg
    | Org__Repo_ Pages.Org_.Repo_.Msg
    | Org__Repo__Deployments Pages.Org_.Repo_.Deployments.Msg
    | Org__Repo__Deployments_Add Pages.Org_.Repo_.Deployments.Add.Msg
    | Org__Repo__Hooks Pages.Org_.Repo_.Hooks.Msg
    | Org__Repo__Schedules Pages.Org_.Repo_.Schedules.Msg
    | Org__Repo__Schedules_Add Pages.Org_.Repo_.Schedules.Add.Msg
    | Org__Repo__Schedules_Name_ Pages.Org_.Repo_.Schedules.Name_.Msg
    | Org__Repo__Settings Pages.Org_.Repo_.Settings.Msg
    | Org__Repo__Build_ Pages.Org_.Repo_.Build_.Msg
    | Org__Repo__Build__Graph Pages.Org_.Repo_.Build_.Graph.Msg
    | Org__Repo__Build__Pipeline Pages.Org_.Repo_.Build_.Pipeline.Msg
    | Org__Repo__Build__Services Pages.Org_.Repo_.Build_.Services.Msg
    | NotFound_ Pages.NotFound_.Msg
