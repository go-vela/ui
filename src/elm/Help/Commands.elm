{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help.Commands exposing
    ( Arg
    , Command
    , Commands
    , Model
    , cliDocsUrl
    , commands
    , issuesBaseUrl
    , resourceLoaded
    , resourceLoading
    , usageDocsUrl
    )

import Pages exposing (Page(..))
import String.Extra
import Util exposing (anyBlank, noBlanks)
import Vela
    exposing
        ( BuildNumber
        , Copy
        , Engine
        , Key
        , Name
        , Org
        , Repo
        , SecretType(..)
        , secretTypeToString
        )


{-| Model : wrapper for help args, meant to slim down the input required to render contextual help for each page
-}
type alias Model msg =
    { user : Arg
    , sourceRepos : Arg
    , builds : Arg
    , build : Arg
    , repo : Arg
    , hooks : Arg
    , secrets : Arg
    , show : Bool
    , toggle : Maybe Bool -> msg
    , copy : Copy msg
    , noOp : msg
    , page : Page
    }


{-| Arg : type alias for extracting remotedata information
-}
type alias Arg =
    { loading : Bool
    , success : Bool
    }


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

        Pages.SourceRepositories ->
            [ listFavorites ]

        Pages.Hooks org repo _ _ ->
            [ validate, listHooks org repo ]

        Pages.RepositoryBuilds org repo _ _ _ ->
            [ listBuilds org repo ]

        Pages.Build org repo buildNumber _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber, listSteps org repo buildNumber, viewStep org repo buildNumber ]

        Pages.RepoSettings org repo ->
            [ viewRepo org repo, repairRepo org repo, chownRepo org repo ]

        Pages.OrgSecrets secretEngine org _ _ ->
            [ listSecrets secretEngine Vela.OrgSecret org Nothing ]

        Pages.RepoSecrets secretEngine org repo _ _ ->
            [ listSecrets secretEngine Vela.RepoSecret org <| Just repo ]

        Pages.SharedSecrets secretEngine org key _ _ ->
            [ listSecrets secretEngine Vela.SharedSecret org <| Just key ]

        Pages.AddOrgSecret secretEngine org ->
            [ addSecret secretEngine Vela.OrgSecret org Nothing ]

        Pages.AddRepoSecret secretEngine org repo ->
            [ addSecret secretEngine Vela.RepoSecret org <| Just repo ]

        Pages.AddSharedSecret secretEngine org team ->
            [ addSecret secretEngine Vela.SharedSecret org <| Just team ]

        Pages.OrgSecret secretEngine org name ->
            [ viewSecret secretEngine Vela.OrgSecret org Nothing name, updateSecret secretEngine Vela.OrgSecret org Nothing name ]

        Pages.RepoSecret secretEngine org repo name ->
            [ viewSecret secretEngine Vela.RepoSecret org (Just repo) name, updateSecret secretEngine Vela.RepoSecret org (Just repo) name ]

        Pages.SharedSecret secretEngine org team name ->
            [ viewSecret secretEngine Vela.SharedSecret org (Just team) name, updateSecret secretEngine Vela.SharedSecret org (Just team) name ]

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
    vela view step --org octocat --repo hello-world --build 14 --step-number 1

-}
viewStep : Org -> Repo -> BuildNumber -> Command
viewStep org repo buildNumber =
    let
        name =
            "View Step"

        content =
            Just <| "vela view step " ++ buildArgs org repo buildNumber ++ " --step-number 1"

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


{-| listSecrets : returns cli command for listing secrets

    eg.
    vela get secrets --secret.engine native --secret.type repo --org octocat --team ghe-admins

-}
listSecrets : Engine -> SecretType -> Org -> Maybe Key -> Command
listSecrets secretEngine secretType org key =
    let
        name =
            "List " ++ (String.Extra.toSentenceCase <| secretTypeToString secretType) ++ " Secrets"

        content =
            Just <| "vela get secrets " ++ secretBaseArgs secretEngine secretType org key

        docs =
            Just "secret/get"
    in
    Command name content docs noIssue


{-| addSecret : returns cli command for adding a secret

    eg.
    vela add secret --secret.engine native --secret.type repo --org octocat --team ghe-admins --name password --value vela --event push

-}
addSecret : Engine -> SecretType -> Org -> Maybe Key -> Command
addSecret secretEngine secretType org key =
    let
        name =
            "Add " ++ (String.Extra.toSentenceCase <| secretTypeToString secretType) ++ " Secret"

        content =
            Just <| "vela add secret " ++ secretBaseArgs secretEngine secretType org key ++ addSecretArgs

        docs =
            Just "secret/add"
    in
    Command name content docs noIssue


{-| viewSecret : returns cli command for viewing a secret

    eg.
    vela view secret --secret.engine native --secret.type org --org octocat --name password
    vela view secret --secret.engine native --secret.type repo --org octocat --repo hello-world --name password
    vela view secret --secret.engine native --secret.type shared --org octocat --team ghe-admins --name password

-}
viewSecret : Engine -> SecretType -> Org -> Maybe Key -> Name -> Command
viewSecret secretEngine secretType org key name_ =
    let
        name =
            "View " ++ (String.Extra.toSentenceCase <| secretTypeToString secretType) ++ " Secret"

        content =
            Just <| "vela view secret " ++ secretBaseArgs secretEngine secretType org key ++ " --name " ++ name_

        docs =
            Just "secret/view"
    in
    Command name content docs noIssue


{-| updateSecret : returns cli command for updating an existing secret

    eg.
    vela update secret --secret.engine native --secret.type org --org octocat --name password --value new_value
    vela update secret --secret.engine native --secret.type repo --org octocat --repo hello-world --name password --value new_value
    vela update secret --secret.engine native --secret.type shared --org octocat --team ghe-admins --name password --value new_value

-}
updateSecret : Engine -> SecretType -> Org -> Maybe Key -> Name -> Command
updateSecret secretEngine secretType org key name_ =
    let
        name =
            "Update " ++ (String.Extra.toSentenceCase <| secretTypeToString secretType) ++ " Secret"

        content =
            Just <| "vela update secret " ++ secretBaseArgs secretEngine secretType org key ++ " --name " ++ name_ ++ " --value new_value"

        docs =
            Just "secret/update"
    in
    Command name content docs noIssue


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


{-| secretBaseArgs : returns cli args for requesting secrets

    eg.
    --secret.type org --org octocat
    --secret.type repo --org octocat --repo hello-world
    --secret.type shared --org octocat --team ghe-admins

-}
secretBaseArgs : Engine -> SecretType -> Org -> Maybe Key -> String
secretBaseArgs secretEngine secretType org key =
    let
        keyFlag =
            case secretType of
                Vela.OrgSecret ->
                    ""

                Vela.RepoSecret ->
                    " --repo " ++ Maybe.withDefault "" key

                Vela.SharedSecret ->
                    " --team " ++ Maybe.withDefault "" key
    in
    "--secret.engine " ++ secretEngine ++ " --secret.type " ++ secretTypeToString secretType ++ " --org " ++ org ++ keyFlag


{-| addSecretArgs : returns cli args for adding a secret

    eg.
     --name password --value vela --event push

-}
addSecretArgs : String
addSecretArgs =
    " --name password --value vela --event push"


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


{-| cliDocsUrl : takes page and returns cli docs url
-}
cliDocsUrl : String -> String
cliDocsUrl page =
    cliDocsBase ++ page


{-| usageDocsUrl : takes page and returns usage docs url
-}
usageDocsUrl : String -> String
usageDocsUrl page =
    usageDocsBase ++ page


docsBase : String
docsBase =
    "https://go-vela.github.io/docs/"


{-| cliDocsBase : returns base url for cli docs
-}
cliDocsBase : String
cliDocsBase =
    docsBase ++ "cli/"


{-| usageDocsBase : returns base url for usage docs
-}
usageDocsBase : String
usageDocsBase =
    docsBase ++ "usage/"


{-| usageDocsBase : returns base url for cli issues
-}
issuesBaseUrl : String
issuesBaseUrl =
    "https://github.com/go-vela/community/issues/"


{-| resourceLoaded : takes help args and returns if the resource has been successfully loaded
-}
resourceLoaded : Model msg -> Bool
resourceLoaded args =
    case args.page of
        Pages.Overview ->
            args.user.success

        Pages.SourceRepositories ->
            args.sourceRepos.success

        Pages.RepositoryBuilds _ _ _ _ _ ->
            args.builds.success

        Pages.Build _ _ _ _ ->
            args.build.success

        Pages.AddOrgSecret secretEngine org ->
            noBlanks [ secretEngine, org ]

        Pages.AddRepoSecret secretEngine org repo ->
            noBlanks [ secretEngine, org, repo ]

        Pages.AddSharedSecret secretEngine org team ->
            noBlanks [ secretEngine, org, team ]

        Pages.OrgSecrets secretEngine org _ _ ->
            noBlanks [ secretEngine, org ]

        Pages.RepoSecrets secretEngine org repo _ _ ->
            noBlanks [ secretEngine, org, repo ]

        Pages.SharedSecrets secretEngine org team _ _ ->
            noBlanks [ secretEngine, org, team ]

        Pages.OrgSecret secretEngine org name ->
            noBlanks [ secretEngine, org, name ]

        Pages.RepoSecret secretEngine org repo name ->
            noBlanks [ secretEngine, org, repo, name ]

        Pages.SharedSecret secretEngine org team name ->
            noBlanks [ secretEngine, org, team, name ]

        Pages.RepoSettings _ _ ->
            args.repo.success

        Pages.Hooks _ _ _ _ ->
            args.hooks.success

        Pages.Settings ->
            True

        Pages.Login ->
            True

        Pages.Logout ->
            True

        Pages.Authenticate _ ->
            True

        Pages.NotFound ->
            False


{-| resourceLoading : takes help args and returns if the resource is loading
-}
resourceLoading : Model msg -> Bool
resourceLoading args =
    case args.page of
        Pages.Overview ->
            args.user.loading

        Pages.SourceRepositories ->
            args.sourceRepos.loading

        Pages.RepositoryBuilds _ _ _ _ _ ->
            args.builds.loading

        Pages.Build _ _ _ _ ->
            args.build.loading

        Pages.OrgSecrets _ _ _ _ ->
            args.secrets.loading

        Pages.RepoSecrets _ _ _ _ _ ->
            args.secrets.loading

        Pages.SharedSecrets _ _ _ _ _ ->
            args.secrets.loading

        Pages.AddOrgSecret secretEngine org ->
            anyBlank [ secretEngine, org ]

        Pages.AddRepoSecret secretEngine org repo ->
            anyBlank [ secretEngine, org, repo ]

        Pages.AddSharedSecret secretEngine org team ->
            anyBlank [ secretEngine, org, team ]

        Pages.OrgSecret secretEngine org name ->
            anyBlank [ secretEngine, org, name ]

        Pages.RepoSecret secretEngine org repo name ->
            anyBlank [ secretEngine, org, repo, name ]

        Pages.SharedSecret secretEngine org team name ->
            anyBlank [ secretEngine, org, team, name ]

        Pages.RepoSettings _ _ ->
            args.repo.loading

        Pages.Hooks _ _ _ _ ->
            args.hooks.loading

        Pages.Settings ->
            False

        Pages.Login ->
            False

        Pages.Logout ->
            True

        Pages.Authenticate _ ->
            True

        Pages.NotFound ->
            False
