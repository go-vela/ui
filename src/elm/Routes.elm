{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Routes exposing (Org, Repo, Route(..), href, match, routeToUrl)

import Html
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Parser exposing ((</>), (<?>), Parser, map, oneOf, parse, s, string, top)
import Url.Parser.Query as Query
import Vela exposing (AuthParams, BuildNumber)



-- TYPES


type alias Org =
    String


type alias Repo =
    String


type Route
    = Overview
    | AddRepositories
    | RepoHooks Org Repo
    | RepositoryBuilds Org Repo
    | Build Org Repo BuildNumber
    | Login
    | Logout
    | Authenticate AuthParams
    | NotFound



-- ROUTES


routes : Parser (Route -> a) a
routes =
    oneOf
        [ map Overview top
        , map AddRepositories (s "account" </> s "add-repos")
        , map Login (s "account" </> s "login")
        , map Logout (s "account" </> s "logout")
        , parseAuth
        , map RepoHooks (string </> string </> s "hooks")
        , map RepositoryBuilds (top </> string </> string)
        , map Build (top </> string </> string </> string)
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

        AddRepositories ->
            "/account/add-repos"

        RepositoryBuilds org repo ->
            "/" ++ org ++ "/" ++ repo

        RepoHooks org repo ->
            "/" ++ org ++ "/" ++ repo ++ "/hooks"

        Build org repo num ->
            "/" ++ org ++ "/" ++ repo ++ "/" ++ num

        Authenticate { code, state } ->
            "/account/authenticate" ++ paramsToQueryString { code = code, state = state }

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


href : Route -> Html.Attribute msg
href route =
    Attr.href (routeToUrl route)
