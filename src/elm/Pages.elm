{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages exposing (Page(..), strip, toRoute)

import Api.Pagination as Pagination
import Focus exposing (ExpandTemplatesQuery, Fragment)
import Routes exposing (Route)
import Vela exposing (BuildNumber, Engine, Event, FocusFragment, Name, Org, Repo, ScheduleName, Team)


type Page
    = Overview
    | Dashboard String
    | SourceRepositories
    | OrgRepositories Org (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Hooks Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | OrgSecrets Engine Org (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | RepoSecrets Engine Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | SharedSecrets Engine Org Team (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | AddOrgSecret Engine Org
    | AddRepoSecret Engine Org Repo
    | AddDeployment Org Repo
    | PromoteDeployment Org Repo BuildNumber
    | AddSharedSecret Engine Org Team
    | OrgSecret Engine Org Name
    | RepoSecret Engine Org Repo Name
    | SharedSecret Engine Org Team Name
    | RepoSettings Org Repo
    | RepositoryBuilds Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event)
    | RepositoryBuildsPulls Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | RepositoryBuildsTags Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | OrgBuilds Org (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event)
    | RepositoryDeployments Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Build Org Repo BuildNumber FocusFragment
    | BuildServices Org Repo BuildNumber FocusFragment
    | BuildPipeline Org Repo BuildNumber (Maybe ExpandTemplatesQuery) (Maybe Fragment)
    | BuildGraph Org Repo BuildNumber
    | AddSchedule Org Repo
    | Schedule Org Repo ScheduleName
    | Schedules Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Settings
    | Login
    | NotFound



-- HELPERS


{-| toRoute : maps a Page to the appropriate breadcrumb trail
-}
toRoute : Page -> Route
toRoute page =
    case page of
        Overview ->
            Routes.Overview

        Dashboard id ->
            Routes.Dashboard id

        SourceRepositories ->
            Routes.SourceRepositories

        OrgRepositories org maybePage maybePerPage ->
            Routes.OrgRepositories org maybePage maybePerPage

        Hooks org repo maybePage maybePerPage ->
            Routes.Hooks org repo maybePage maybePerPage

        RepoSettings org repo ->
            Routes.RepoSettings org repo

        OrgSecrets engine org maybePage maybePerPage ->
            Routes.OrgSecrets engine org maybePage maybePerPage

        RepoSecrets engine org repo maybePage maybePerPage ->
            Routes.RepoSecrets engine org repo maybePage maybePerPage

        SharedSecrets engine org repo maybePage maybePerPage ->
            Routes.SharedSecrets engine org repo maybePage maybePerPage

        AddOrgSecret engine org ->
            Routes.AddOrgSecret engine org

        AddRepoSecret engine org repo ->
            Routes.AddRepoSecret engine org repo

        AddSharedSecret engine org team ->
            Routes.AddSharedSecret engine org team

        AddDeployment org repo ->
            Routes.AddDeploymentRoute org repo

        PromoteDeployment org repo deploymentId ->
            Routes.PromoteDeployment org repo deploymentId

        OrgSecret engine org name ->
            Routes.OrgSecret engine org name

        RepoSecret engine org repo name ->
            Routes.RepoSecret engine org repo name

        SharedSecret engine org team name ->
            Routes.SharedSecret engine org team name

        RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            Routes.RepositoryBuilds org repo maybePage maybePerPage maybeEvent

        RepositoryBuildsPulls org repo maybePage maybePerPage ->
            Routes.RepositoryBuildsPulls org repo maybePage maybePerPage

        RepositoryBuildsTags org repo maybePage maybePerPage ->
            Routes.RepositoryBuildsTags org repo maybePage maybePerPage

        OrgBuilds org maybePage maybePerPage maybeEvent ->
            Routes.OrgBuilds org maybePage maybePerPage maybeEvent

        RepositoryDeployments org repo maybePage maybePerPage ->
            Routes.RepositoryDeployments org repo maybePage maybePerPage

        Build org repo buildNumber logFocus ->
            Routes.Build org repo buildNumber logFocus

        BuildServices org repo buildNumber logFocus ->
            Routes.BuildServices org repo buildNumber logFocus

        BuildPipeline org repo buildNumber expanded lineFocus ->
            Routes.BuildPipeline org repo buildNumber expanded lineFocus

        BuildGraph org repo buildNumber ->
            Routes.BuildGraph org repo buildNumber

        AddSchedule org repo ->
            Routes.AddSchedule org repo

        Schedules org repo maybePage maybePerPage ->
            Routes.Schedules org repo maybePage maybePerPage

        Schedule org repo name ->
            Routes.Schedule org repo name

        Settings ->
            Routes.Settings

        Login ->
            Routes.Login

        NotFound ->
            Routes.NotFound


{-| strip : maps a Page to itself with optional parameters stripped
-}
strip : Page -> Page
strip page =
    case page of
        Overview ->
            Overview

        Dashboard _ ->
            Dashboard ""

        SourceRepositories ->
            SourceRepositories

        OrgRepositories org _ _ ->
            OrgRepositories org Nothing Nothing

        Hooks org repo _ _ ->
            Hooks org repo Nothing Nothing

        RepoSettings org repo ->
            RepoSettings org repo

        OrgSecrets engine org _ _ ->
            OrgSecrets engine org Nothing Nothing

        RepoSecrets engine org repo _ _ ->
            RepoSecrets engine org repo Nothing Nothing

        SharedSecrets engine org repo _ _ ->
            SharedSecrets engine org repo Nothing Nothing

        AddOrgSecret engine org ->
            AddOrgSecret engine org

        AddRepoSecret engine org repo ->
            AddRepoSecret engine org repo

        AddDeployment org repo ->
            AddDeployment org repo

        PromoteDeployment org repo deploymentId ->
            PromoteDeployment org repo deploymentId

        AddSharedSecret engine org team ->
            AddSharedSecret engine org team

        OrgSecret engine org name ->
            OrgSecret engine org name

        RepoSecret engine org repo name ->
            RepoSecret engine org repo name

        SharedSecret engine org team name ->
            SharedSecret engine org team name

        OrgBuilds org _ _ _ ->
            OrgBuilds org Nothing Nothing Nothing

        RepositoryBuilds org repo _ _ _ ->
            RepositoryBuilds org repo Nothing Nothing Nothing

        RepositoryBuildsPulls org repo _ _ ->
            RepositoryBuildsPulls org repo Nothing Nothing

        RepositoryBuildsTags org repo _ _ ->
            RepositoryBuildsTags org repo Nothing Nothing

        RepositoryDeployments org repo _ _ ->
            RepositoryDeployments org repo Nothing Nothing

        Build org repo buildNumber _ ->
            Build org repo buildNumber Nothing

        BuildServices org repo buildNumber _ ->
            BuildServices org repo buildNumber Nothing

        BuildPipeline org repo buildNumber _ _ ->
            BuildPipeline org repo buildNumber Nothing Nothing

        BuildGraph org repo buildNumber ->
            BuildGraph org repo buildNumber

        AddSchedule org repo ->
            AddSchedule org repo

        Schedules org repo _ _ ->
            Schedules org repo Nothing Nothing

        Schedule org repo id ->
            Schedule org repo id

        Settings ->
            Settings

        Login ->
            Login

        NotFound ->
            NotFound
