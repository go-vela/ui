{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages exposing (Page(..), toRoute)

import Api.Pagination as Pagination
import Routes exposing (Route(..))
import Vela exposing (AuthParams, BuildNumber, Engine, Event, FocusFragment, Key, Name, Org, Repo, Team)


type Page
    = Overview
    | AddRepositories
    | Hooks Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | OrgSecrets Engine Org
    | RepoSecrets Engine Org Repo
    | SharedSecrets Engine Org Team
    | AddOrgSecret Engine Org
    | AddRepoSecret Engine Org Repo
    | AddSharedSecret Engine Org Team
    | OrgSecret Engine Org Name
    | RepoSecret Engine Org Repo Name
    | SharedSecret Engine Org Team Name
    | RepoSettings Org Repo
    | RepositoryBuilds Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event)
    | Build Org Repo BuildNumber FocusFragment
    | Settings
    | Login
    | Logout
    | Authenticate AuthParams
    | NotFound



-- HELPERS


{-| toRoute : maps a Page to the appropriate breadcrumb trail
-}
toRoute : Page -> Route
toRoute page =
    case page of
        Overview ->
            Routes.Overview

        AddRepositories ->
            Routes.AddRepositories

        Hooks org repo maybePage maybePerPage ->
            Routes.Hooks org repo maybePage maybePerPage

        RepoSettings org repo ->
            Routes.RepoSettings org repo

        OrgSecrets engine org ->
            Routes.OrgSecrets engine org

        RepoSecrets engine org repo ->
            Routes.RepoSecrets engine org repo

        SharedSecrets engine org repo ->
            Routes.SharedSecrets engine org repo

        AddOrgSecret engine org ->
            Routes.AddOrgSecret engine org

        AddRepoSecret engine org repo ->
            Routes.AddRepoSecret engine org repo

        AddSharedSecret engine org team ->
            Routes.AddSharedSecret engine org team

        OrgSecret engine org name ->
            Routes.OrgSecret engine org name

        RepoSecret engine org repo name ->
            Routes.RepoSecret engine org repo name

        SharedSecret engine org team name ->
            Routes.SharedSecret engine org team name

        RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            Routes.RepositoryBuilds org repo maybePage maybePerPage maybeEvent

        Build org repo buildNumber logFocus ->
            Routes.Build org repo buildNumber logFocus

        Settings ->
            Routes.Settings

        Login ->
            Routes.Login

        Logout ->
            Routes.Logout

        Authenticate { code, state } ->
            Routes.Authenticate { code = code, state = state }

        NotFound ->
            Routes.NotFound
