{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
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

import Pages exposing (Page)
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
        , ScheduleName
        , SecretType
        , StepNumber
        , secretTypeToString
        )


{-| Model : wrapper for help args, meant to slim down the input required to render contextual help for each page
-}
type alias Model msg =
    { user : Arg
    , sourceRepos : Arg
    , orgRepos : Arg
    , builds : Arg
    , deployments : Arg
    , build : Arg
    , repo : Arg
    , hooks : Arg
    , secrets : Arg
    , show : Bool
    , toggle : Maybe Bool -> msg
    , copy : Copy msg
    , noOp : msg
    , page : Page
    , velaDocsURL : String
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
            []

        Pages.OrgRepositories _ _ _ ->
            []

        Pages.Hooks org repo _ _ ->
            [ validate, listHooks org repo, viewHook org repo ]

        Pages.OrgBuilds _ _ _ _ ->
            []

        Pages.RepositoryBuilds org repo _ _ _ ->
            [ listBuilds org repo ]

        Pages.RepositoryBuildsPulls org repo _ _ ->
            [ listBuilds org repo ]

        Pages.RepositoryBuildsTags org repo _ _ ->
            [ listBuilds org repo ]

        Pages.RepositoryDeployments org repo _ _ ->
            [ listDeployments org repo ]

        Pages.Build org repo buildNumber _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber, cancelBuild org repo buildNumber, listSteps org repo buildNumber, viewStep org repo buildNumber ]

        Pages.BuildServices org repo buildNumber _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber, cancelBuild org repo buildNumber, listServices org repo buildNumber, viewService org repo buildNumber ]

        Pages.BuildPipeline org repo buildNumber _ _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber ]

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

        Pages.AddDeployment org repo ->
            [ addDeployment org repo ]

        Pages.PromoteDeployment org repo _ ->
            [ addDeployment org repo ]

        Pages.AddSharedSecret secretEngine org team ->
            [ addSecret secretEngine Vela.SharedSecret org <| Just team ]

        Pages.OrgSecret secretEngine org name ->
            [ viewSecret secretEngine Vela.OrgSecret org Nothing name, updateSecret secretEngine Vela.OrgSecret org Nothing name ]

        Pages.RepoSecret secretEngine org repo name ->
            [ viewSecret secretEngine Vela.RepoSecret org (Just repo) name, updateSecret secretEngine Vela.RepoSecret org (Just repo) name ]

        Pages.SharedSecret secretEngine org team name ->
            [ viewSecret secretEngine Vela.SharedSecret org (Just team) name, updateSecret secretEngine Vela.SharedSecret org (Just team) name ]

        Pages.Settings ->
            []

        Pages.Login ->
            [ authenticate ]

        Pages.NotFound ->
            []

        Pages.AddSchedule org repo ->
            [ addSchedule org repo ]

        Pages.Schedule org repo name ->
            [ viewSchedule org repo name, updateSchedule org repo name ]

        Pages.Schedules org repo _ _ ->
            [ listSchedules org repo ]


{-| listFavorites : returns cli command for listing favorites

    not yet supported

-}
listFavorites : Command
listFavorites =
    let
        name =
            "List Favorites"

        issue =
            Just "17"
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
            Just "/build/get"
    in
    Command name content docs noIssue


{-| listDeployments : returns cli command for listing deployments

    eg.
    vela get builds --org octocat --repo hello-world

-}
listDeployments : Org -> Repo -> Command
listDeployments org repo =
    let
        name =
            "List Deployments"

        content =
            Just <| "vela get deployments " ++ repoArgs org repo

        docs =
            Just "/deployment/get"
    in
    Command name content docs noIssue


{-| viewBuild : returns cli command for viewing a build

    eg.
    vela view build --org octocat --repo hello-world --build 1

-}
viewBuild : Org -> Repo -> BuildNumber -> Command
viewBuild org repo buildNumber =
    let
        name =
            "View Build"

        content =
            Just <| "vela view build " ++ buildArgs org repo buildNumber

        docs =
            Just "/build/view"
    in
    Command name content docs noIssue


{-| restartBuild : returns cli command for restarting a build

    eg.
    vela restart build --org octocat --repo hello-world --build 1

-}
restartBuild : Org -> Repo -> BuildNumber -> Command
restartBuild org repo buildNumber =
    let
        name =
            "Restart Build"

        content =
            Just <| "vela restart build " ++ buildArgs org repo buildNumber

        docs =
            Just "/build/restart"
    in
    Command name content docs noIssue


{-| cancelBuild : returns cli command for canceling a build

    eg.
    vela cancel build --org octocat --repo hello-world --build 1

-}
cancelBuild : Org -> Repo -> BuildNumber -> Command
cancelBuild org repo buildNumber =
    let
        name =
            "Cancel Build"

        content =
            Just <| "vela cancel build " ++ buildArgs org repo buildNumber

        docs =
            Just "/build/cancel"
    in
    Command name content docs noIssue


{-| listSteps : returns cli command for listing steps

    eg.
    vela get steps --org octocat --repo hello-world --build 1

-}
listSteps : Org -> Repo -> BuildNumber -> Command
listSteps org repo buildNumber =
    let
        name =
            "List Steps"

        content =
            Just <| "vela get steps " ++ buildArgs org repo buildNumber

        docs =
            Just "/step/get"
    in
    Command name content docs noIssue


{-| viewStep : returns cli command for viewing a step

    eg.
    vela view step --org octocat --repo hello-world --build 1 --step 1

-}
viewStep : Org -> Repo -> BuildNumber -> Command
viewStep org repo buildNumber =
    let
        name =
            "View Step"

        content =
            Just <| "vela view step " ++ stepArgs org repo buildNumber "1"

        docs =
            Just "/step/view"
    in
    Command name content docs noIssue


{-| listServices : returns cli command for listing services

    eg.
    vela get services --org octocat --repo hello-world --build 1

-}
listServices : Org -> Repo -> BuildNumber -> Command
listServices org repo buildNumber =
    let
        name =
            "List Services"

        content =
            Just <| "vela get services " ++ buildArgs org repo buildNumber

        docs =
            Just "/service/get"
    in
    Command name content docs noIssue


{-| viewService : returns cli command for viewing a service

    eg.
    vela view service --org octocat --repo hello-world --build 14 --service 1

-}
viewService : Org -> Repo -> BuildNumber -> Command
viewService org repo buildNumber =
    let
        name =
            "View Service"

        content =
            Just <| "vela view service " ++ serviceArgs org repo buildNumber "1"

        docs =
            Just "/service/view"
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
            Just "/repo/view"
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
            Just "/repo/repair"
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
            Just "/repo/chown"
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

    eg.
    vela get hooks --org octocat --repo hello-world

-}
listHooks : Org -> Repo -> Command
listHooks org repo =
    let
        name =
            "List Hooks"

        content =
            Just <| "vela get hooks " ++ repoArgs org repo

        docs =
            Just "/hook/get"
    in
    Command name content docs noIssue


{-| viewHook : returns cli command for viewing a build

    eg.
    vela view hook --org octocat --repo hello-world --hook 1

-}
viewHook : Org -> Repo -> Command
viewHook org repo =
    let
        name =
            "View Hook"

        content =
            Just <| "vela view hook " ++ hookArgs org repo "1"

        docs =
            Just "/hook/view"
    in
    Command name content docs noIssue


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
            Just "/secret/get"
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
            Just "/secret/add"
    in
    Command name content docs noIssue


{-| addDeployment : returns cli command for adding a deployment

    eg.
    vela add deployment vela add deployment --repo some-repp --org some-org

-}
addDeployment : Org -> Repo -> Command
addDeployment org repo =
    let
        name =
            "Add Deployment"

        content =
            Just <| "vela add deployment --org" ++ org ++ " --repo " ++ repo

        docs =
            Just "/deployment/add"
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
            Just "/secret/view"
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
            Just "/secret/update"
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
            Just "/authentication"
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
    --org octocat --repo hello-world --build 1

-}
buildArgs : Org -> Repo -> BuildNumber -> String
buildArgs org repo buildNumber =
    repoArgs org repo ++ " --build " ++ buildNumber


{-| stepArgs : returns cli args for requesting a step resource

    eg.
    --org octocat --repo hello-world --build 1 --step 1

-}
stepArgs : Org -> Repo -> BuildNumber -> StepNumber -> String
stepArgs org repo buildNumber stepNumber =
    buildArgs org repo buildNumber ++ " --step " ++ stepNumber


{-| serviceArgs : returns cli args for requesting a service resource

    eg.
    --org octocat --repo hello-world --build 1 --service 1

-}
serviceArgs : Org -> Repo -> BuildNumber -> StepNumber -> String
serviceArgs org repo buildNumber stepNumber =
    buildArgs org repo buildNumber ++ " --service " ++ stepNumber


{-| hookArgs : returns cli args for requesting a hook resource

    eg.
    --org octocat --repo hello-world --build 1 --hook 1

-}
hookArgs : Org -> Repo -> String -> String
hookArgs org repo hookNumber =
    repoArgs org repo ++ " --hook " ++ hookNumber


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


{-| listSchedules : returns cli command for listing schedules

    eg.
      vela list schedules --org <org> --repo <repo>

-}
listSchedules : Org -> Repo -> Command
listSchedules org repo =
    let
        name =
            "List Schedules"

        content =
            Just <| "vela get schedules " ++ repoArgs org repo

        docs =
            Just "/schedule/get"
    in
    Command name content docs noIssue


{-| viewSchedule : returns cli command for viewing a schedule

      vela view schedule --org <org> --repo <repo>  --schedule <name>

-}
viewSchedule : Org -> Repo -> ScheduleName -> Command
viewSchedule org repo name =
    let
        name_ =
            "View " ++ name ++ " Schedule"

        content =
            Just <| "vela view schedule " ++ repoArgs org repo ++ " --name " ++ name

        docs =
            Just "/schedule/view"
    in
    Command name_ content docs noIssue


{-| updateSchedule : returns cli command for updating an existing schedule

    eg.
      vela update schedule --org <org> --repo <repo> --schedule <name> --entry <entry>

-}
updateSchedule : Org -> Repo -> ScheduleName -> Command
updateSchedule org repo name =
    let
        name_ =
            "Update " ++ name ++ " Schedule"

        content =
            Just <| "vela update schedule " ++ repoArgs org repo ++ " --name " ++ name ++ " --entry '<cron expression>'"

        docs =
            Just "/schedule/update"
    in
    Command name_ content docs noIssue


{-| addSchedule : returns cli command for adding an new schedule

    eg.
      vela add schedule --org <org> --repo <repo> --schedule <name> --entry <entry>

-}
addSchedule : Org -> Repo -> Command
addSchedule org repo =
    let
        name_ =
            "Add a New Schedule"

        content =
            Just <| "vela add schedule " ++ repoArgs org repo ++ " --name <name> --entry '<cron expression>'"

        docs =
            Just "/schedule/add"
    in
    Command name_ content docs noIssue


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
cliDocsUrl : String -> String -> String
cliDocsUrl docsBase page =
    cliDocsBaseUrl docsBase ++ page


{-| usageDocsUrl : takes page and returns usage docs url
-}
usageDocsUrl : String -> String -> String
usageDocsUrl docsBase page =
    usageDocsBase docsBase ++ page


{-| cliDocsBaseUrl : returns base url for cli docs
-}
cliDocsBaseUrl : String -> String
cliDocsBaseUrl docsBase =
    docsBase ++ "/reference/cli"


{-| usageDocsBase : returns base url for usage docs
-}
usageDocsBase : String -> String
usageDocsBase docsBase =
    docsBase ++ "/usage"


{-| usageDocsBase : returns base url for cli issues
-}
issuesBaseUrl : String
issuesBaseUrl =
    "https://github.com/go-vela/community/issues"


{-| resourceLoaded : takes help args and returns if the resource has been successfully loaded
-}
resourceLoaded : Model msg -> Bool
resourceLoaded args =
    case args.page of
        Pages.Overview ->
            args.user.success

        Pages.SourceRepositories ->
            args.sourceRepos.success

        Pages.OrgRepositories _ _ _ ->
            args.orgRepos.success

        Pages.OrgBuilds _ _ _ _ ->
            args.builds.success

        Pages.RepositoryBuilds _ _ _ _ _ ->
            args.builds.success

        Pages.RepositoryBuildsPulls _ _ _ _ ->
            args.builds.success

        Pages.RepositoryBuildsTags _ _ _ _ ->
            args.builds.success

        Pages.RepositoryDeployments _ _ _ _ ->
            args.deployments.success

        Pages.Build _ _ _ _ ->
            args.build.success

        Pages.BuildServices _ _ _ _ ->
            args.build.success

        Pages.BuildPipeline _ _ _ _ _ ->
            args.build.success

        Pages.AddOrgSecret secretEngine org ->
            noBlanks [ secretEngine, org ]

        Pages.AddRepoSecret secretEngine org repo ->
            noBlanks [ secretEngine, org, repo ]

        Pages.AddSharedSecret secretEngine org team ->
            noBlanks [ secretEngine, org, team ]

        Pages.AddDeployment org repo ->
            noBlanks [ org, repo ]

        Pages.PromoteDeployment org repo _ ->
            noBlanks [ org, repo ]

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

        Pages.NotFound ->
            False

        Pages.AddSchedule org repo ->
            noBlanks [ org, repo ]

        Pages.Schedule org repo name ->
            noBlanks [ org, repo, name ]

        Pages.Schedules org repo _ _ ->
            noBlanks [ org, repo ]


{-| resourceLoading : takes help args and returns if the resource is loading
-}
resourceLoading : Model msg -> Bool
resourceLoading args =
    case args.page of
        Pages.Overview ->
            args.user.loading

        Pages.SourceRepositories ->
            args.sourceRepos.loading

        Pages.OrgRepositories _ _ _ ->
            args.sourceRepos.loading

        Pages.OrgBuilds _ _ _ _ ->
            args.builds.loading

        Pages.RepositoryBuilds _ _ _ _ _ ->
            args.builds.loading

        Pages.RepositoryBuildsPulls _ _ _ _ ->
            args.builds.loading

        Pages.RepositoryBuildsTags _ _ _ _ ->
            args.builds.loading

        Pages.RepositoryDeployments _ _ _ _ ->
            args.deployments.loading

        Pages.Build _ _ _ _ ->
            args.build.loading

        Pages.BuildServices _ _ _ _ ->
            args.build.loading

        Pages.BuildPipeline _ _ _ _ _ ->
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

        Pages.AddDeployment org repo ->
            anyBlank [ org, repo ]

        Pages.PromoteDeployment org repo _ ->
            anyBlank [ org, repo ]

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

        Pages.NotFound ->
            False

        Pages.AddSchedule _ _ ->
            False

        Pages.Schedule _ _ _ ->
            False

        Pages.Schedules _ _ _ _ ->
            False
