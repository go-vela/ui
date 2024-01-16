{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Util exposing (view)

import Html exposing (Html, div)
import Html.Attributes exposing (class)
import Route exposing (Route)
import Shared


view : Shared.Model -> Route () -> List (Html msg) -> Html msg
view shared route buttons =
    div [ class "util" ]
        buttons



-- Pages.OrgBuilds org _ _ _ ->
--     viewOrgTabs rm org legacyPage
-- Pages.OrgSecrets _ org _ _ ->
--     viewOrgTabs rm org legacyPage
-- Pages.OrgRepositories org _ _ ->
--     viewOrgTabs rm org legacyPage
-- Pages.RepositoryBuilds org repo _ _ _ ->
--     viewRepoTabs rm org repo legacyPage shared.velaScheduleAllowlist
-- Pages.RepositoryDeployments org repo _ _ ->
--     viewRepoTabs rm org repo legacyPage shared.velaScheduleAllowlist
-- Pages.RepoSecrets _ org repo _ _ ->
--     viewRepoTabs rm org repo legacyPage shared.velaScheduleAllowlist
-- Pages.Schedules org repo _ _ ->
--     viewRepoTabs rm org repo legacyPage shared.velaScheduleAllowlist
-- Pages.Hooks org repo _ _ ->
--     viewRepoTabs rm org repo legacyPage shared.velaScheduleAllowlist
-- Pages.RepoSettings org repo ->
--     viewRepoTabs rm org repo legacyPage shared.velaScheduleAllowlist
-- Pages.Build _ _ _ _ ->
--     Pages.Build.History.view shared.time shared.zone legacyPage 10 shared.repo
-- Pages.BuildServices _ _ _ _ ->
--     Pages.Build.History.view shared.time shared.zone legacyPage 10 shared.repo
-- Pages.BuildPipeline _ _ _ _ _ ->
--     Pages.Build.History.view shared.time shared.zone legacyPage 10 shared.repo
-- Pages.BuildGraph _ _ _ ->
--     Pages.Build.History.view shared.time shared.zone legacyPage 10 shared.repo
-- Pages.AddDeployment _ _ ->
--     text ""
-- Pages.PromoteDeployment _ _ _ ->
--     text ""
-- Pages.Overview ->
--     text ""
-- Pages.SourceRepositories ->
--     text ""
-- Pages.SharedSecrets _ _ _ _ _ ->
--     text ""
-- Pages.AddOrgSecret _ _ ->
--     text ""
-- Pages.AddRepoSecret _ _ _ ->
--     text ""
-- Pages.AddSharedSecret _ _ _ ->
--     text ""
-- Pages.OrgSecret _ _ _ ->
--     text ""
-- Pages.RepoSecret _ _ _ _ ->
--     text ""
-- Pages.SharedSecret _ _ _ _ ->
--     text ""
-- Pages.RepositoryBuildsPulls _ _ _ _ ->
--     text ""
-- Pages.RepositoryBuildsTags _ _ _ _ ->
--     text ""
-- Pages.AddSchedule _ _ ->
--     text ""
-- Pages.Schedule _ _ _ ->
--     text ""
-- Pages.Settings ->
--     text ""
-- Pages.Login ->
--     text ""
-- Pages.NotFound ->
--     text ""
