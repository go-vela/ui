{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages exposing (Page(..), toRoute)

import Api.Pagination as Pagination
import Routes exposing (Route(..))
import Vela exposing (AuthParams, BuildNumber, Event, FocusFragment, Key, Name, Org, Repo, Team)


type Page
    = Overview
    | AddRepositories
    | Hooks Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | OrgSecrets Org
    | RepoSecrets Org Repo
    | SharedSecrets Org Team
    | AddSecret
    | UpdateSecret Org Key Name
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

        OrgSecrets org ->
            Routes.RepoSecrets org "repo"

        RepoSecrets org repo ->
            Routes.RepoSecrets org repo

        SharedSecrets org repo ->
            Routes.RepoSecrets org repo

        AddSecret ->
            Routes.RepoSecrets "org" "repo"

        UpdateSecret org key name ->
            Routes.RepoSecrets org "repo"

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
