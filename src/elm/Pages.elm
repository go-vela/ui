{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages exposing (Page(..), strip, toRoute)

import Api.Pagination as Pagination
import Focus exposing (ExpandTemplatesQuery, Fragment, RefQuery)
import Routes exposing (Route)
import Vela exposing (BuildNumber, Engine, Event, FocusFragment, Name, Org, Repo, Team)


type Page
    = Overview
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
    | OrgBuilds Org (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event)
    | RepositoryDeployments Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Build Org Repo BuildNumber FocusFragment
    | BuildServices Org Repo BuildNumber FocusFragment
    | BuildPipeline Org Repo BuildNumber (Maybe RefQuery) (Maybe ExpandTemplatesQuery) (Maybe Fragment)
    | Pipeline Org Repo (Maybe RefQuery) (Maybe ExpandTemplatesQuery) (Maybe Fragment)
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

        OrgBuilds org maybePage maybePerPage maybeEvent ->
            Routes.OrgBuilds org maybePage maybePerPage maybeEvent

        RepositoryDeployments org repo maybePage maybePerPage ->
            Routes.RepositoryDeployments org repo maybePage maybePerPage

        Build org repo buildNumber logFocus ->
            Routes.Build org repo buildNumber logFocus

        BuildServices org repo buildNumber logFocus ->
            Routes.BuildServices org repo buildNumber logFocus

        BuildPipeline org repo buildNumber ref expanded lineFocus ->
            Routes.BuildPipeline org repo buildNumber ref expanded lineFocus

        Pipeline org repo ref expanded lineFocus ->
            Routes.Pipeline org repo ref expanded lineFocus

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

        RepositoryDeployments org repo _ _ ->
            RepositoryDeployments org repo Nothing Nothing

        Build org repo buildNumber _ ->
            Build org repo buildNumber Nothing

        BuildServices org repo buildNumber _ ->
            BuildServices org repo buildNumber Nothing

        BuildPipeline org repo buildNumber _ _ _ ->
            BuildPipeline org repo buildNumber Nothing Nothing Nothing

        Pipeline org repo _ _ _ ->
            Pipeline org repo Nothing Nothing Nothing

        Settings ->
            Settings

        Login ->
            Login

        NotFound ->
            NotFound
