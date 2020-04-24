
{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help.Commands exposing (Command, Commands, commands)

import Pages exposing (Page(..))
import Vela exposing (BuildNumber, Org, Repo)


type alias Command =
    { name : String
    , content : Maybe String
    , docs : Maybe String
    , issue : Maybe String
    }


type alias Commands =
    List Command


{-| commands : takes current page and returns list of cli commands to help with resources on that page
-}
commands : Page -> Commands
commands page =
    case page of
        Pages.Overview ->
            [ listFavorites ]

        Pages.AddRepositories ->
            [ listFavorites ]

        Pages.Hooks org repo _ _ ->
            [ validate, listHooks org repo ]

        Pages.RepositoryBuilds org repo _ _ _ ->
            [ listBuilds org repo ]

        Pages.Build org repo buildNumber _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber, listSteps org repo buildNumber, viewStep org repo buildNumber ]

        Pages.RepoSettings org repo ->
            [ viewRepo org repo, repairRepo org repo, chownRepo org repo ]

        Pages.OrgSecrets engine org ->
            -- TODO: probably want this filled in
            []

        Pages.RepoSecrets engine org repo ->
            -- TODO: probably want this filled in
            []

        Pages.SharedSecrets engine org key ->
            -- TODO: probably want this filled in
            []

        Pages.AddOrgSecret engine org ->
            -- TODO: probably want this filled in
            []

        Pages.AddRepoSecret engine org repo ->
            -- TODO: probably want this filled in
            []

        Pages.AddSharedSecret engine org team ->
            -- TODO: probably want this filled in
            []

        Pages.OrgSecret engine org name ->
            -- TODO: probably want this filled in
            []

        Pages.RepoSecret engine org repo name ->
            -- TODO: probably want this filled in
            []

        Pages.SharedSecret engine org team name ->
            -- TODO: probably want this filled in
            []

        Pages.Settings ->
            -- TODO: probably want this filled in
            []

        Pages.Authenticate _ ->
            []

        Pages.Login ->
            [ authenticate ]

        Pages.Logout ->
            []

        Pages.NotFound ->
            []


{-| listFavorites : returns cli command for listing favorites

    not yet supported

-}
listFavorites : Command
listFavorites =
    let
        name =
            "List Favorites"

        issue =
            Just "53"
    in
    Command name noCmd noDocs issue


{-| listBuilds : returns cli command for listing builds

    eg.
    vela get builds --org octocat --repo hello-world

-}
listBuilds : Org -> Repo -> Command
listBuilds org repo =
    let
        name =
            "List Builds"

        content =
            Just <| "vela get builds " ++ repoArgs org repo

        docs =
            Just "build/get"
    in
    Command name content docs noIssue


{-| viewBuild : returns cli command for viewing a build

    eg.
    vela get builds --org octocat --repo hello-world

-}
viewBuild : Org -> Repo -> BuildNumber -> Command
viewBuild org repo buildNumber =
    let
        name =
            "View Build"

        content =
            Just <| "vela view build " ++ buildArgs org repo buildNumber

        docs =
            Just "build/view"
    in
    Command name content docs noIssue


{-| restartBuild : returns cli command for restarting a build

    eg.
    vela restart build --org octocat --repo hello-world --build 14

-}
restartBuild : Org -> Repo -> BuildNumber -> Command
restartBuild org repo buildNumber =
    let
        name =
            "Restart Build"

        content =
            Just <| "vela restart build " ++ buildArgs org repo buildNumber

        docs =
            Just "build/restart"
    in
    Command name content docs noIssue


{-| listSteps : returns cli command for listing steps

    eg.
    vela get steps --org octocat --repo hello-world --build 14

-}
listSteps : Org -> Repo -> BuildNumber -> Command
listSteps org repo buildNumber =
    let
        name =
            "List Steps"

        content =
            Just <| "vela get steps " ++ buildArgs org repo buildNumber

        docs =
            Just "steps/get"
    in
    Command name content docs noIssue


{-| viewStep : returns cli command for viewing a step

    eg.
    vela view step --org octocat --repo hello-world --build 14 --step 1

-}
viewStep : Org -> Repo -> BuildNumber -> Command
viewStep org repo buildNumber =
    let
        name =
            "View Step"

        content =
            Just <| "vela view step " ++ buildArgs org repo buildNumber ++ " --step 1"

        docs =
            Just "steps/get"
    in
    Command name content docs noIssue


{-| viewRepo : returns cli command for viewing a repo

    eg.
    vela view repo --org octocat --repo hello-world

-}
viewRepo : Org -> Repo -> Command
viewRepo org repo =
    let
        name =
            "View Repo"

        content =
            Just <| "vela view repo " ++ repoArgs org repo

        docs =
            Just "repo/view"
    in
    Command name content docs noIssue


{-| repairRepo : returns cli command for repairing a repo

    eg.
    vela repair repo --org octocat --repo hello-world

-}
repairRepo : Org -> Repo -> Command
repairRepo org repo =
    let
        name =
            "Repair Repo"

        content =
            Just <| "vela repair repo " ++ repoArgs org repo

        docs =
            Just "repo/repair"
    in
    Command name content docs noIssue


{-| chownRepo : returns cli command for chowning a repo

    eg.
    vela chown repo --org octocat --repo hello-world

-}
chownRepo : Org -> Repo -> Command
chownRepo org repo =
    let
        name =
            "Chown Repo"

        content =
            Just <| "vela chown repo " ++ repoArgs org repo

        docs =
            Just "repo/chown"
    in
    Command name content docs noIssue


{-| validate : returns cli command for validating vela yaml

    eg.
    vela validate

-}
validate : Command
validate =
    let
        name =
            "Validate Pipeline"

        content =
            Just "vela validate"

        docs =
            Just "validate"
    in
    Command name content docs noIssue


{-| listHooks : returns cli command for listing hooks

    not yet supported

-}
listHooks : Org -> Repo -> Command
listHooks _ _ =
    let
        name =
            "List Hooks"

        issue =
            Just "52"
    in
    Command name noCmd noDocs issue


{-| authenticate : returns cli command for authenticating

    eg.
    vela login

-}
authenticate : Command
authenticate =
    let
        name =
            "Authenticate"

        content =
            Just "vela login"

        docs =
            Just "authentication"
    in
    Command name content docs noIssue


{-| repoArgs : returns cli args for requesting repo resources

    eg.
    --org octocat --repo hello-world

-}
repoArgs : Org -> Repo -> String
repoArgs org repo =
    "--org " ++ org ++ " --repo " ++ repo


{-| buildArgs : returns cli args for requesting build resources

    eg.
    --org octocat --repo hello-world --build 14

-}
buildArgs : Org -> Repo -> BuildNumber -> String
buildArgs org repo buildNumber =
    repoArgs org repo ++ " --build " ++ buildNumber


noCmd : Maybe String
noCmd =
    Nothing


noDocs : Maybe String
noDocs =
    Nothing


noIssue : Maybe String
noIssue =
    Nothing
