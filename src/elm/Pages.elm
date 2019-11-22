{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages exposing (Page(..), toRoute)

import Routes exposing (Route(..))
import Vela exposing (AuthParams, BuildNumber, Org, Repo)


type Page
    = Overview
    | AddRepositories
    | RepoHooks Org Repo
    | RepositoryBuilds Org Repo
    | Build Org Repo BuildNumber
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

        RepoHooks org repo ->
            Routes.RepoHooks org repo

        RepositoryBuilds org repo ->
            Routes.RepositoryBuilds org repo

        Build org repo buildNumber ->
            Routes.Build org repo buildNumber

        Login ->
            Routes.Login

        Logout ->
            Routes.Logout

        Authenticate { code, state } ->
            Routes.Authenticate { code = code, state = state }

        NotFound ->
            Routes.NotFound
