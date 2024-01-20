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
import Pages.Org_.Repo_
import Pages.Org_.Repo_.Deployments


type Msg
    = AccountLogin Pages.Account.Login.Msg
    | AccountSettings Pages.Account.Settings.Msg
    | AccountSourceRepos Pages.Account.SourceRepos.Msg
    | Home Pages.Home.Msg
    | Org_ Pages.Org_.Msg
    | Org_Repo_ Pages.Org_.Repo_.Msg
    | Org_Repo_Deployments Pages.Org_.Repo_.Deployments.Msg
    | NotFound_ Pages.NotFound_.Msg
