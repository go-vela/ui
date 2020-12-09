{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages exposing (Page(..), strip, onPage, toRoute)

import Api.Pagination as Pagination
import Focus exposing (ExpandTemplatesQuery, Fragment, RefQuery)
import Routes exposing (Route(..))
import Vela exposing (AuthParams, BuildNumber, Engine, Event, FocusFragment, Name,Ref, Org, Repo, Team)

import Html
import Html.Attributes exposing (class)

type Page
    = Overview
    | SourceRepositories
    | Hooks Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | OrgSecrets Engine Org (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | RepoSecrets Engine Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | SharedSecrets Engine Org Team (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | AddOrgSecret Engine Org
    | AddRepoSecret Engine Org Repo
    | AddSharedSecret Engine Org Team
    | OrgSecret Engine Org Name
    | RepoSecret Engine Org Repo Name
    | SharedSecret Engine Org Team Name
    | RepoSettings Org Repo
    | RepositoryBuilds Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage) (Maybe Event)
    | Build Org Repo BuildNumber FocusFragment
    | Pipeline Org Repo (Maybe BuildNumber) (Maybe Ref) (Maybe ExpandTemplatesQuery) (Maybe Fragment)
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

        SourceRepositories ->
            Routes.SourceRepositories

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

        Pipeline org repo buildNumber ref expanded lineFocus ->
            Routes.Pipeline org repo buildNumber ref expanded lineFocus

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


{-| strip : maps a Page to itself with optional parameters stripped
-}
strip : Page -> Page
strip page =
    case page of
        Overview ->
            Overview

        SourceRepositories ->
            SourceRepositories

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

        AddSharedSecret engine org team ->
            AddSharedSecret engine org team

        OrgSecret engine org name ->
            OrgSecret engine org name

        RepoSecret engine org repo name ->
            RepoSecret engine org repo name

        SharedSecret engine org team name ->
            SharedSecret engine org team name

        RepositoryBuilds org repo _ _ _ ->
            RepositoryBuilds org repo Nothing Nothing Nothing

        Build org repo buildNumber _ ->
            Build org repo buildNumber Nothing

        Pipeline org repo buildNumber ref _ _ ->
            Pipeline org repo buildNumber ref Nothing Nothing

        Settings ->
            Settings

        Login ->
            Login

        Logout ->
            Logout

        Authenticate _ ->
            Authenticate { code = Nothing, state = Nothing }

        NotFound ->
            NotFound

onPage : Page -> Page -> Bool
onPage p1 p2 =
    strip p1 ==  strip p2 


