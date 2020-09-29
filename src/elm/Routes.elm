{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Routes exposing (Route(..), href, match, routeToUrl)

import Api.Pagination as Pagination
import Html
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Builder as UB
import Url.Parser exposing ((</>), (<?>), Parser, fragment, map, oneOf, parse, s, string, top)
import Url.Parser.Query as Query
import Vela exposing (AuthParams, BuildNumber, Engine, Event, FocusFragment, Name, Org, Repo, Team)



-- TYPES


type Route
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
    | Settings
    | Login
    | Logout
    | Authenticate AuthParams
    | NotFound



-- ROUTES


routes : Parser (Route -> a) a
routes =
    oneOf
        [ map Overview top
        , map SourceRepositories (s "account" </> s "source-repos")
        , map Login (s "account" </> s "login")
        , map Logout (s "account" </> s "logout")
        , map Settings (s "account" </> s "settings")
        , parseAuth
        , map Hooks (string </> string </> s "hooks" <?> Query.int "page" <?> Query.int "per_page")
        , map OrgSecrets (s "-" </> s "secrets" </> string </> s "org" </> string <?> Query.int "page" <?> Query.int "per_page")
        , map RepoSecrets (s "-" </> s "secrets" </> string </> s "repo" </> string </> string <?> Query.int "page" <?> Query.int "per_page")
        , map SharedSecrets (s "-" </> s "secrets" </> string </> s "shared" </> string </> string <?> Query.int "page" <?> Query.int "per_page")
        , map AddOrgSecret (s "-" </> s "secrets" </> string </> s "org" </> string </> s "add")
        , map AddRepoSecret (s "-" </> s "secrets" </> string </> s "repo" </> string </> string </> s "add")
        , map AddSharedSecret (s "-" </> s "secrets" </> string </> s "shared" </> string </> string </> s "add")
        , map OrgSecret (s "-" </> s "secrets" </> string </> s "org" </> string </> string)
        , map RepoSecret (s "-" </> s "secrets" </> string </> s "repo" </> string </> string </> string)
        , map SharedSecret (s "-" </> s "secrets" </> string </> s "shared" </> string </> string </> string)
        , map RepoSettings (string </> string </> s "settings")
        , map RepositoryBuilds (string </> string <?> Query.int "page" <?> Query.int "per_page" <?> Query.string "event")
        , map Build (string </> string </> string </> fragment identity)
        , map NotFound (s "404")
        ]


match : Url -> Route
match url =
    parse routes url |> Maybe.withDefault NotFound


parseAuth : Parser (Route -> a) a
parseAuth =
    map
        (\code state ->
            Authenticate { code = code, state = state }
        )
        (s "account"
            </> s "authenticate"
            <?> Query.string "code"
            <?> Query.string "state"
        )



-- HELPER


routeToUrl : Route -> String
routeToUrl route =
    case route of
        Overview ->
            "/"

        SourceRepositories ->
            "/account/source-repos"

        RepoSettings org repo ->
            "/" ++ org ++ "/" ++ repo ++ "/settings"

        OrgSecrets engine org maybePage maybePerPage ->
            "/-/secrets/" ++ engine ++ "/org/" ++ org ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage)

        RepoSecrets engine org repo maybePage maybePerPage ->
            "/-/secrets/" ++ engine ++ "/repo/" ++ org ++ "/" ++ repo ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage)

        SharedSecrets engine org team maybePage maybePerPage ->
            "/-/secrets/" ++ engine ++ "/shared/" ++ org ++ "/" ++ team ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage)

        AddOrgSecret engine org ->
            "/-/secrets/" ++ engine ++ "/org/" ++ org ++ "/add"

        AddRepoSecret engine org repo ->
            "/-/secrets/" ++ engine ++ "/repo/" ++ org ++ "/" ++ repo ++ "/add"

        AddSharedSecret engine org team ->
            "/-/secrets/" ++ engine ++ "/shared/" ++ org ++ "/" ++ team ++ "/add"

        OrgSecret engine org name ->
            "/-/secrets/" ++ engine ++ "/org/" ++ org ++ "/" ++ name

        RepoSecret engine org repo name ->
            "/-/secrets/" ++ engine ++ "/repo/" ++ org ++ "/" ++ repo ++ "/" ++ name

        SharedSecret engine org team name ->
            "/-/secrets/" ++ engine ++ "/shared/" ++ org ++ "/" ++ team ++ "/" ++ name

        RepositoryBuilds org repo maybePage maybePerPage maybeEvent ->
            "/" ++ org ++ "/" ++ repo ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage ++ eventToQueryParam maybeEvent)

        Hooks org repo maybePage maybePerPage ->
            "/" ++ org ++ "/" ++ repo ++ "/hooks" ++ UB.toQuery (Pagination.toQueryParams maybePage maybePerPage)

        Build org repo buildNumber logFocus ->
            "/" ++ org ++ "/" ++ repo ++ "/" ++ buildNumber ++ Maybe.withDefault "" logFocus

        Authenticate { code, state } ->
            "/account/authenticate" ++ paramsToQueryString { code = code, state = state }

        Settings ->
            "/account/settings"

        Login ->
            "/account/login"

        Logout ->
            "/account/logout"

        NotFound ->
            "/404"


paramsToQueryString : AuthParams -> String
paramsToQueryString params =
    case ( params.code, params.state ) of
        ( Nothing, Nothing ) ->
            ""

        ( Just code, Just state ) ->
            "?code=" ++ code ++ "&state=" ++ state

        ( Just code, Nothing ) ->
            "?code" ++ code

        _ ->
            ""


eventToQueryParam : Maybe Event -> List UB.QueryParameter
eventToQueryParam maybeEvent =
    if maybeEvent /= Nothing then
        [ UB.string "event" <| Maybe.withDefault "" maybeEvent ]

    else
        []


href : Route -> Html.Attribute msg
href route =
    Attr.href (routeToUrl route)
