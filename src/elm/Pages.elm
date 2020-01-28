{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages exposing (Page(..), toRoute)

import Api.Pagination as Pagination
import Routes exposing (Route(..))
import Vela exposing (AuthParams, BuildNumber, FocusFragment, Org, Repo)


type Page
    = Overview
    | AddRepositories
    | Hooks Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Settings Org Repo
    | RepositoryBuilds Org Repo (Maybe Pagination.Page) (Maybe Pagination.PerPage)
    | Build Org Repo BuildNumber FocusFragment
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

        Settings org repo ->
            Routes.Settings org repo

        RepositoryBuilds org repo maybePage maybePerPage ->
            Routes.RepositoryBuilds org repo maybePage maybePerPage

        Build org repo buildNumber lineFocus ->
            Routes.Build org repo buildNumber lineFocus

        Login ->
            Routes.Login

        Logout ->
            Routes.Logout

        Authenticate { code, state } ->
            Routes.Authenticate { code = code, state = state }

        NotFound ->
            Routes.NotFound
