{--
SPDX-License-Identifier: Apache-2.0
--}


module Vela exposing
    ( AddSchedulePayload
    , Build
    , BuildGraph
    , BuildGraphEdge
    , BuildGraphInteraction
    , BuildGraphModel
    , BuildGraphNode
    , BuildModel
    , BuildNumber
    , Builds
    , BuildsModel
    , CurrentUser
    , Deployment
    , DeploymentId
    , DeploymentPayload
    , DeploymentsModel
    , EnableRepositoryPayload
    , Enabled
    , Enabling(..)
    , Engine
    , Event
    , Field
    , FocusFragment
    , Hook
    , HookNumber
    , Hooks
    , HooksModel
    , Key
    , KeyValuePair
    , Log
    , LogFocus
    , Logs
    , Name
    , Org
    , OrgReposModel
    , PipelineConfig
    , PipelineModel
    , PipelineTemplates
    , Ref
    , Repo
    , RepoModel
    , RepoResourceIdentifier
    , Repositories
    , Repository
    , Resource
    , Resources
    , Schedule
    , ScheduleName
    , Schedules
    , Secret
    , SecretPayload
    , SecretType(..)
    , Secrets
    , Service
    , ServiceNumber
    , Services
    , SourceRepositories
    , Status(..)
    , Step
    , StepNumber
    , Steps
    , Team
    , Template
    , Templates
    , Type
    , UpdateRepositoryPayload
    , UpdateSchedulePayload
    , UpdateUserPayload
    , buildDeploymentPayload
    , buildEnableRepositoryPayload
    , buildSecretPayload
    , buildUpdateFavoritesPayload
    , buildUpdateRepoBoolPayload
    , buildUpdateRepoIntPayload
    , buildUpdateRepoStringPayload
    , buildUpdateSchedulePayload
    , decodeBuild
    , decodeBuildGraph
    , decodeBuilds
    , decodeCurrentUser
    , decodeDeployment
    , decodeDeployments
    , decodeGraphInteraction
    , decodeHooks
    , decodeLog
    , decodeOnGraphInteraction
    , decodePipelineConfig
    , decodePipelineExpand
    , decodePipelineTemplates
    , decodeRepositories
    , decodeRepository
    , decodeSchedule
    , decodeSchedules
    , decodeSecret
    , decodeSecrets
    , decodeService
    , decodeServices
    , decodeSourceRepositories
    , decodeStep
    , decodeSteps
    , defaultBuildGraph
    , defaultEnableRepositoryPayload
    , defaultPipeline
    , defaultPipelineTemplates
    , defaultRepoModel
    , defaultSecret
    , defaultStep
    , enableUpdate
    , encodeBuildGraphRenderData
    , encodeDeploymentPayload
    , encodeEnableRepository
    , encodeSecretPayload
    , encodeUpdateRepository
    , encodeUpdateSchedule
    , encodeUpdateUser
    , isComplete
    , newStepLog
    , secretToKey
    , secretTypeToString
    , secretsErrorLabel
    , statusToString
    , stringToStatus
    , updateBuild
    , updateBuildGraph
    , updateBuildGraphFilter
    , updateBuildGraphShowServices
    , updateBuildGraphShowSteps
    , updateBuildNumber
    , updateBuildPipelineConfig
    , updateBuildPipelineExpand
    , updateBuildPipelineFocusFragment
    , updateBuildPipelineLineFocus
    , updateBuildServices
    , updateBuildServicesFocusFragment
    , updateBuildServicesFollowing
    , updateBuildServicesLogs
    , updateBuildSteps
    , updateBuildStepsFocusFragment
    , updateBuildStepsFollowing
    , updateBuildStepsLogs
    , updateBuilds
    , updateBuildsEvent
    , updateBuildsPage
    , updateBuildsPager
    , updateBuildsPerPage
    , updateBuildsShowTimeStamp
    , updateDeployments
    , updateDeploymentsPage
    , updateDeploymentsPager
    , updateDeploymentsPerPage
    , updateHooks
    , updateHooksPage
    , updateHooksPager
    , updateHooksPerPage
    , updateOrgRepo
    , updateOrgReposPage
    , updateOrgReposPager
    , updateOrgReposPerPage
    , updateOrgRepositories
    , updateRepo
    , updateRepoCounter
    , updateRepoEnabling
    , updateRepoInitialized
    , updateRepoLimit
    , updateRepoModels
    , updateRepoTimeout
    )

import Api.Pagination as Pagination
import Bytes.Encode
import Dict exposing (Dict)
import Json.Decode exposing (Decoder, andThen, bool, int, string, succeed)
import Json.Decode.Extra exposing (dict2)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode
import LinkHeader exposing (WebLink)
import RemoteData exposing (RemoteData(..), WebData)
import Utils.Errors as Errors
import Visualization.DOT as DOT



-- COMMON


type alias Org =
    String


type alias Repo =
    String


type alias Team =
    String


type alias Engine =
    String


type alias Name =
    String


type alias Event =
    String


type alias BuildNumber =
    String


type alias HookNumber =
    String


type alias DeploymentId =
    String


type alias StepNumber =
    String


type alias ServiceNumber =
    String


type alias Type =
    String


type alias Key =
    String


type alias Ref =
    String


type alias Task =
    String


type alias Commit =
    String


type alias Description =
    String


type alias Payload =
    List KeyValuePair


type alias Target =
    String


type alias ScheduleName =
    String



-- CURRENTUSER


type alias CurrentUser =
    { id : Int
    , name : String
    , favorites : List String
    , active : Bool
    , admin : Bool
    }


decodeCurrentUser : Decoder CurrentUser
decodeCurrentUser =
    Json.Decode.succeed CurrentUser
        |> required "id" int
        |> required "name" string
        |> optional "favorites" (Json.Decode.list string) []
        |> required "active" bool
        |> required "admin" bool


type alias UpdateUserPayload =
    { name : Maybe String
    , favorites : Maybe (List String)
    }


defaultUpdateUserPayload : UpdateUserPayload
defaultUpdateUserPayload =
    UpdateUserPayload Nothing Nothing


encodeUpdateUser : UpdateUserPayload -> Json.Encode.Value
encodeUpdateUser user =
    Json.Encode.object
        [ ( "favorites", encodeOptionalList Json.Encode.string user.favorites )
        ]


buildUpdateFavoritesPayload : List String -> UpdateUserPayload
buildUpdateFavoritesPayload value =
    { defaultUpdateUserPayload | favorites = Just value }



-- REPOSITORY


{-| RepoModel : model to contain repository information that is crucial for rendering repo pages
-}
type alias RepoModel =
    { org : Org
    , name : Repo
    , repo : WebData Repository
    , orgRepos : OrgReposModel
    , hooks : HooksModel
    , builds : BuildsModel
    , deployments : DeploymentsModel
    , build : BuildModel
    , initialized : Bool
    }


{-| OrgReposModel : model to contain repositories belonging to an org crucial for rendering the repositories tab on the org page
-}
type alias OrgReposModel =
    { orgRepos : WebData (List Repository)
    , pager : List WebLink
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    }


defaultOrgReposModel : OrgReposModel
defaultOrgReposModel =
    OrgReposModel RemoteData.NotAsked [] Nothing Nothing


{-| BuildModel : model to contain build information that is crucial for rendering a pipeline
-}
type alias BuildModel =
    { buildNumber : BuildNumber
    , build : WebData Build
    , steps : StepsModel
    , services : ServicesModel
    , graph : BuildGraphModel
    }


type alias StepsModel =
    { steps : WebData Steps
    , logs : Logs
    , focusFragment : FocusFragment
    , followingStep : Int
    }


type alias ServicesModel =
    { services : WebData Services
    , logs : Logs
    , focusFragment : FocusFragment
    , followingService : Int
    }


updateRepoModels : { a | repo : RepoModel } -> RepoModel -> BuildModel -> BuildGraphModel -> { a | repo : RepoModel }
updateRepoModels m rm bm gm =
    { m
        | repo =
            { rm
                | build =
                    { bm
                        | graph =
                            gm
                    }
            }
    }


defaultBuildModel : BuildModel
defaultBuildModel =
    BuildModel "" NotAsked defaultStepsModel defaultServicesModel defaultBuildGraphModel


defaultRepoModel : RepoModel
defaultRepoModel =
    RepoModel "" "" NotAsked defaultOrgReposModel defaultHooks defaultBuilds defaultDeployments defaultBuildModel False


defaultStepsModel : StepsModel
defaultStepsModel =
    StepsModel NotAsked [] Nothing 0


defaultServicesModel : ServicesModel
defaultServicesModel =
    ServicesModel NotAsked [] Nothing 0


updateRepoInitialized : Bool -> RepoModel -> RepoModel
updateRepoInitialized update rm =
    { rm | initialized = update }


updateOrgRepo : Org -> Repo -> RepoModel -> RepoModel
updateOrgRepo org repo rm =
    { rm | org = org, name = repo }


updateRepo : WebData Repository -> RepoModel -> RepoModel
updateRepo update rm =
    { rm | repo = update }


updateOrgRepositories : WebData (List Repository) -> RepoModel -> RepoModel
updateOrgRepositories update rm =
    let
        orm =
            rm.orgRepos
    in
    { rm | orgRepos = { orm | orgRepos = update } }


updateRepoLimit : Maybe Int -> RepoModel -> RepoModel
updateRepoLimit update rm =
    let
        repo =
            rm.repo
    in
    { rm
        | repo =
            case repo of
                RemoteData.Success r ->
                    RemoteData.succeed { r | inLimit = update }

                _ ->
                    repo
    }


updateRepoTimeout : Maybe Int -> RepoModel -> RepoModel
updateRepoTimeout update rm =
    let
        repo =
            rm.repo
    in
    { rm
        | repo =
            case repo of
                RemoteData.Success r ->
                    RemoteData.succeed { r | inTimeout = update }

                _ ->
                    repo
    }


updateRepoCounter : Maybe Int -> RepoModel -> RepoModel
updateRepoCounter update rm =
    let
        repo =
            rm.repo
    in
    { rm
        | repo =
            case repo of
                RemoteData.Success r ->
                    RemoteData.succeed { r | inCounter = update }

                _ ->
                    repo
    }


updateRepoEnabling : Enabling -> RepoModel -> RepoModel
updateRepoEnabling update rm =
    let
        repo =
            rm.repo
    in
    case repo of
        RemoteData.Success r ->
            { rm | repo = RemoteData.succeed { r | enabling = update } }

        _ ->
            rm


updateBuild : WebData Build -> RepoModel -> RepoModel
updateBuild update rm =
    let
        b =
            rm.build
    in
    { rm | build = { b | build = update } }


updateBuildNumber : BuildNumber -> RepoModel -> RepoModel
updateBuildNumber update rm =
    let
        b =
            rm.build
    in
    { rm | build = { b | buildNumber = update } }


updateBuildStepsFocusFragment : FocusFragment -> RepoModel -> RepoModel
updateBuildStepsFocusFragment update rm =
    let
        b =
            rm.build

        s =
            b.steps
    in
    { rm | build = { b | steps = { s | focusFragment = update } } }


updateBuildStepsFollowing : Int -> RepoModel -> RepoModel
updateBuildStepsFollowing update rm =
    let
        b =
            rm.build

        s =
            b.steps
    in
    { rm | build = { b | steps = { s | followingStep = update } } }


updateBuildStepsLogs : Logs -> RepoModel -> RepoModel
updateBuildStepsLogs update rm =
    let
        b =
            rm.build

        s =
            b.steps
    in
    { rm | build = { b | steps = { s | logs = update } } }


updateBuilds : WebData Builds -> RepoModel -> RepoModel
updateBuilds update rm =
    let
        bm =
            rm.builds
    in
    { rm | builds = { bm | builds = update } }


updateBuildsPager : List WebLink -> RepoModel -> RepoModel
updateBuildsPager update rm =
    let
        bm =
            rm.builds
    in
    { rm | builds = { bm | pager = update } }


updateBuildsShowTimeStamp : RepoModel -> RepoModel
updateBuildsShowTimeStamp rm =
    let
        bm =
            rm.builds
    in
    { rm | builds = { bm | showTimestamp = not bm.showTimestamp } }


updateDeployments : WebData (List Deployment) -> RepoModel -> RepoModel
updateDeployments update rm =
    let
        dm =
            rm.deployments
    in
    { rm | deployments = { dm | deployments = update } }


updateDeploymentsPager : List WebLink -> RepoModel -> RepoModel
updateDeploymentsPager update rm =
    let
        dm =
            rm.deployments
    in
    { rm | deployments = { dm | pager = update } }


updateDeploymentsPage : Maybe Pagination.Page -> RepoModel -> RepoModel
updateDeploymentsPage maybePage rm =
    let
        dm =
            rm.deployments
    in
    { rm | deployments = { dm | maybePage = maybePage } }


updateDeploymentsPerPage : Maybe Pagination.PerPage -> RepoModel -> RepoModel
updateDeploymentsPerPage maybePerPage rm =
    let
        dm =
            rm.deployments
    in
    { rm | deployments = { dm | maybePerPage = maybePerPage } }


updateOrgReposPage : Maybe Pagination.Page -> RepoModel -> RepoModel
updateOrgReposPage maybePage rm =
    let
        orm =
            rm.orgRepos
    in
    { rm | orgRepos = { orm | maybePage = maybePage } }


updateOrgReposPerPage : Maybe Pagination.PerPage -> RepoModel -> RepoModel
updateOrgReposPerPage maybePerPage rm =
    let
        orm =
            rm.orgRepos
    in
    { rm | orgRepos = { orm | maybePerPage = maybePerPage } }


updateOrgReposPager : List WebLink -> RepoModel -> RepoModel
updateOrgReposPager update rm =
    let
        orm =
            rm.orgRepos
    in
    { rm | orgRepos = { orm | pager = update } }


updateBuildsPage : Maybe Pagination.Page -> RepoModel -> RepoModel
updateBuildsPage maybePage rm =
    let
        bm =
            rm.builds
    in
    { rm | builds = { bm | maybePage = maybePage } }


updateBuildsPerPage : Maybe Pagination.PerPage -> RepoModel -> RepoModel
updateBuildsPerPage maybePerPage rm =
    let
        bm =
            rm.builds
    in
    { rm | builds = { bm | maybePerPage = maybePerPage } }


updateBuildsEvent : Maybe Event -> RepoModel -> RepoModel
updateBuildsEvent maybeEvent rm =
    let
        bm =
            rm.builds
    in
    { rm | builds = { bm | maybeEvent = maybeEvent } }


updateBuildSteps : WebData Steps -> RepoModel -> RepoModel
updateBuildSteps update rm =
    let
        b =
            rm.build

        s =
            b.steps
    in
    { rm | build = { b | steps = { s | steps = update } } }


updateBuildGraph : WebData BuildGraph -> RepoModel -> RepoModel
updateBuildGraph update rm =
    let
        b =
            rm.build

        g =
            b.graph
    in
    { rm | build = { b | graph = { g | graph = update } } }


updateBuildGraphShowServices : Bool -> RepoModel -> RepoModel
updateBuildGraphShowServices update rm =
    let
        b =
            rm.build

        g =
            b.graph
    in
    { rm | build = { b | graph = { g | showServices = update } } }


updateBuildGraphShowSteps : Bool -> RepoModel -> RepoModel
updateBuildGraphShowSteps update rm =
    let
        b =
            rm.build

        g =
            b.graph
    in
    { rm | build = { b | graph = { g | showSteps = update } } }


updateBuildGraphFilter : String -> RepoModel -> RepoModel
updateBuildGraphFilter update rm =
    let
        b =
            rm.build

        g =
            b.graph
    in
    { rm | build = { b | graph = { g | filter = update } } }


updateBuildServices : WebData Services -> RepoModel -> RepoModel
updateBuildServices update rm =
    let
        b =
            rm.build

        s =
            b.services
    in
    { rm | build = { b | services = { s | services = update } } }


updateBuildServicesFocusFragment : FocusFragment -> RepoModel -> RepoModel
updateBuildServicesFocusFragment update rm =
    let
        b =
            rm.build

        s =
            b.services
    in
    { rm | build = { b | services = { s | focusFragment = update } } }


updateBuildServicesFollowing : Int -> RepoModel -> RepoModel
updateBuildServicesFollowing update rm =
    let
        b =
            rm.build

        s =
            b.services
    in
    { rm | build = { b | services = { s | followingService = update } } }


updateBuildServicesLogs : Logs -> RepoModel -> RepoModel
updateBuildServicesLogs update rm =
    let
        b =
            rm.build

        s =
            b.services
    in
    { rm | build = { b | services = { s | logs = update } } }


updateBuildPipelineConfig : ( WebData PipelineConfig, Errors.Error ) -> PipelineModel -> PipelineModel
updateBuildPipelineConfig update pipeline =
    { pipeline | config = update }


updateBuildPipelineExpand : Maybe String -> PipelineModel -> PipelineModel
updateBuildPipelineExpand update pipeline =
    { pipeline | expand = update }


updateBuildPipelineLineFocus : LogFocus -> PipelineModel -> PipelineModel
updateBuildPipelineLineFocus update pipeline =
    { pipeline | lineFocus = update }


updateBuildPipelineFocusFragment : FocusFragment -> PipelineModel -> PipelineModel
updateBuildPipelineFocusFragment update pipeline =
    { pipeline | focusFragment = update }


updateHooks : WebData Hooks -> RepoModel -> RepoModel
updateHooks update rm =
    let
        h =
            rm.hooks
    in
    { rm | hooks = { h | hooks = update } }


updateHooksPager : List WebLink -> RepoModel -> RepoModel
updateHooksPager update rm =
    let
        h =
            rm.hooks
    in
    { rm | hooks = { h | pager = update } }


updateHooksPage : Maybe Pagination.Page -> RepoModel -> RepoModel
updateHooksPage maybePage rm =
    let
        h =
            rm.hooks
    in
    { rm | hooks = { h | maybePage = maybePage } }


updateHooksPerPage : Maybe Pagination.PerPage -> RepoModel -> RepoModel
updateHooksPerPage maybePerPage rm =
    let
        h =
            rm.hooks
    in
    { rm | hooks = { h | maybePerPage = maybePerPage } }


type alias KeyValuePair =
    { key : String
    , value : String
    }


type alias Deployment =
    { id : Int
    , repo_id : Int
    , url : String
    , user : String
    , commit : String
    , ref : String
    , task : String
    , target : String
    , description : String
    , payload : Maybe (List KeyValuePair)
    }


type alias Repository =
    { id : Int
    , user_id : Int
    , org : String
    , name : String
    , full_name : String
    , link : String
    , clone : String
    , branch : String
    , limit : Int
    , timeout : Int
    , counter : Int
    , visibility : String
    , approve_build : String
    , private : Bool
    , trusted : Bool
    , active : Bool
    , allow_pull : Bool
    , allow_push : Bool
    , allow_deploy : Bool
    , allow_tag : Bool
    , allow_comment : Bool
    , enabled : Enabled
    , enabling : Enabling
    , inLimit : Maybe Int
    , inTimeout : Maybe Int
    , inCounter : Maybe Int
    , pipeline_type : String
    }


type alias Enabled =
    WebData Bool


type Enabling
    = ConfirmDisable
    | Disabling
    | Disabled
    | Enabling
    | Enabled
    | NotAsked_


decodeRepositories : Decoder (List Repository)
decodeRepositories =
    Json.Decode.list decodeRepository


decodeRepository : Decoder Repository
decodeRepository =
    Json.Decode.succeed Repository
        |> optional "id" int -1
        |> optional "user_id" int -1
        |> required "org" string
        |> required "name" string
        |> optional "full_name" string ""
        |> optional "link" string ""
        |> optional "clone" string ""
        |> optional "branch" string ""
        |> optional "build_limit" int 0
        |> optional "timeout" int 0
        |> optional "counter" int 0
        |> optional "visibility" string ""
        |> optional "approve_build" string ""
        |> optional "private" bool False
        |> optional "trusted" bool False
        |> optional "active" bool False
        |> optional "allow_pull" bool False
        |> optional "allow_push" bool False
        |> optional "allow_deploy" bool False
        |> optional "allow_tag" bool False
        |> optional "allow_comment" bool False
        -- "enabled"
        |> optional "active" enabledDecoder NotAsked
        -- "enabling"
        |> optional "active" enablingDecoder NotAsked_
        -- "inLimit"
        |> hardcoded Nothing
        -- "inTimeout"
        |> hardcoded Nothing
        -- "inCounter"
        |> hardcoded Nothing
        |> optional "pipeline_type" string ""


{-| enabledDecoder : decodes string field "status" to the union type Enabled
-}
enabledDecoder : Decoder Enabled
enabledDecoder =
    bool |> andThen toEnabled


{-| toEnabled : helper to decode string to Enabled
-}
toEnabled : Bool -> Decoder Enabled
toEnabled active =
    if active then
        succeed <| RemoteData.succeed True

    else
        succeed NotAsked


{-| enablingDecoder : decodes string field "status" to the union type Enabling
-}
enablingDecoder : Decoder Enabling
enablingDecoder =
    bool |> andThen toEnabling


{-| toEnabling : helper to decode string to Enabling
-}
toEnabling : Bool -> Decoder Enabling
toEnabling active =
    if active then
        succeed Enabled

    else
        succeed Disabled


{-| enableUpdate : takes repo, enabled status and source repos and sets enabled status of the specified repo
-}
enableUpdate : Repository -> Enabled -> WebData SourceRepositories -> WebData SourceRepositories
enableUpdate repo status sourceRepos =
    case sourceRepos of
        RemoteData.Success repos ->
            case Dict.get repo.org repos of
                Just orgRepos ->
                    RemoteData.succeed <| enableRepoDict repo status repos orgRepos

                _ ->
                    sourceRepos

        _ ->
            sourceRepos


{-| enableRepoDict : update the dictionary containing org source repo lists
-}
enableRepoDict : Repository -> Enabled -> Dict String Repositories -> Repositories -> Dict String Repositories
enableRepoDict repo status repos orgRepos =
    Dict.update repo.org (\_ -> Just <| enableRepoList repo status orgRepos) repos


{-| enableRepoList : list map for updating single repo status by repo name
-}
enableRepoList : Repository -> Enabled -> Repositories -> Repositories
enableRepoList repo status orgRepos =
    List.map
        (\sourceRepo ->
            if sourceRepo.name == repo.name then
                { sourceRepo | enabled = status }

            else
                sourceRepo
        )
        orgRepos


{-| Repositories : type alias for list of enabled repositories
-}
type alias Repositories =
    List Repository


{-| SourceRepositories : type alias for repositories available for creation
-}
type alias SourceRepositories =
    Dict String Repositories


decodeSourceRepositories : Decoder SourceRepositories
decodeSourceRepositories =
    Json.Decode.dict (Json.Decode.list decodeRepository)


encodeEnableRepository : EnableRepositoryPayload -> Json.Encode.Value
encodeEnableRepository repo =
    Json.Encode.object
        [ ( "org", Json.Encode.string <| repo.org )
        , ( "name", Json.Encode.string <| repo.name )
        , ( "full_name", Json.Encode.string <| repo.full_name )
        , ( "link", Json.Encode.string <| repo.link )
        , ( "clone", Json.Encode.string <| repo.clone )
        , ( "private", Json.Encode.bool <| repo.private )
        , ( "trusted", Json.Encode.bool <| repo.trusted )
        , ( "active", Json.Encode.bool <| repo.active )
        , ( "allow_pull", Json.Encode.bool <| repo.allow_pull )
        , ( "allow_push", Json.Encode.bool <| repo.allow_push )
        , ( "allow_deploy", Json.Encode.bool <| repo.allow_deploy )
        , ( "allow_tag", Json.Encode.bool <| repo.allow_tag )
        , ( "allow_comment", Json.Encode.bool <| repo.allow_comment )
        ]


type alias EnableRepositoryPayload =
    { org : String
    , name : String
    , full_name : String
    , link : String
    , clone : String
    , private : Bool
    , trusted : Bool
    , active : Bool
    , allow_pull : Bool
    , allow_push : Bool
    , allow_deploy : Bool
    , allow_tag : Bool
    , allow_comment : Bool
    }


defaultEnableRepositoryPayload : EnableRepositoryPayload
defaultEnableRepositoryPayload =
    EnableRepositoryPayload "" "" "" "" "" False False True False False False False False


{-| buildEnableRepositoryPayload : builds the payload for adding a repository via the api
-}
buildEnableRepositoryPayload : Repository -> EnableRepositoryPayload
buildEnableRepositoryPayload repo =
    { defaultEnableRepositoryPayload
        | org = repo.org
        , name = repo.name
        , full_name = repo.org ++ "/" ++ repo.name
        , link = repo.link
        , clone = repo.clone
    }


type alias UpdateRepositoryPayload =
    { private : Maybe Bool
    , trusted : Maybe Bool
    , active : Maybe Bool
    , allow_pull : Maybe Bool
    , allow_push : Maybe Bool
    , allow_deploy : Maybe Bool
    , allow_tag : Maybe Bool
    , allow_comment : Maybe Bool
    , visibility : Maybe String
    , approve_build : Maybe String
    , limit : Maybe Int
    , timeout : Maybe Int
    , counter : Maybe Int
    , pipeline_type : Maybe String
    }


type alias Field =
    String


defaultUpdateRepositoryPayload : UpdateRepositoryPayload
defaultUpdateRepositoryPayload =
    UpdateRepositoryPayload Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing


encodeUpdateRepository : UpdateRepositoryPayload -> Json.Encode.Value
encodeUpdateRepository repo =
    Json.Encode.object
        [ ( "active", encodeOptional Json.Encode.bool repo.active )
        , ( "private", encodeOptional Json.Encode.bool repo.private )
        , ( "trusted", encodeOptional Json.Encode.bool repo.trusted )
        , ( "allow_pull", encodeOptional Json.Encode.bool repo.allow_pull )
        , ( "allow_push", encodeOptional Json.Encode.bool repo.allow_push )
        , ( "allow_deploy", encodeOptional Json.Encode.bool repo.allow_deploy )
        , ( "allow_tag", encodeOptional Json.Encode.bool repo.allow_tag )
        , ( "allow_comment", encodeOptional Json.Encode.bool repo.allow_comment )
        , ( "visibility", encodeOptional Json.Encode.string repo.visibility )
        , ( "approve_build", encodeOptional Json.Encode.string repo.approve_build )
        , ( "build_limit", encodeOptional Json.Encode.int repo.limit )
        , ( "timeout", encodeOptional Json.Encode.int repo.timeout )
        , ( "counter", encodeOptional Json.Encode.int repo.counter )
        , ( "pipeline_type", encodeOptional Json.Encode.string repo.pipeline_type )
        ]


encodeOptional : (a -> Json.Encode.Value) -> Maybe a -> Json.Encode.Value
encodeOptional encoder value =
    case value of
        Just value_ ->
            encoder value_

        Nothing ->
            Json.Encode.null


encodeOptionalList : (a -> Json.Encode.Value) -> Maybe (List a) -> Json.Encode.Value
encodeOptionalList encoder value =
    case value of
        Just value_ ->
            Json.Encode.list encoder value_

        Nothing ->
            Json.Encode.null


buildUpdateRepoBoolPayload : Field -> Bool -> UpdateRepositoryPayload
buildUpdateRepoBoolPayload field value =
    case field of
        "private" ->
            { defaultUpdateRepositoryPayload | private = Just value }

        "trusted" ->
            { defaultUpdateRepositoryPayload | trusted = Just value }

        "active" ->
            { defaultUpdateRepositoryPayload | active = Just value }

        "allow_pull" ->
            { defaultUpdateRepositoryPayload | allow_pull = Just value }

        "allow_push" ->
            { defaultUpdateRepositoryPayload | allow_push = Just value }

        "allow_deploy" ->
            { defaultUpdateRepositoryPayload | allow_deploy = Just value }

        "allow_tag" ->
            { defaultUpdateRepositoryPayload | allow_tag = Just value }

        "allow_comment" ->
            { defaultUpdateRepositoryPayload | allow_comment = Just value }

        _ ->
            defaultUpdateRepositoryPayload


buildUpdateRepoStringPayload : Field -> String -> UpdateRepositoryPayload
buildUpdateRepoStringPayload field value =
    case field of
        "visibility" ->
            { defaultUpdateRepositoryPayload | visibility = Just value }

        "pipeline_type" ->
            { defaultUpdateRepositoryPayload | pipeline_type = Just value }

        "approve_build" ->
            { defaultUpdateRepositoryPayload | approve_build = Just value }

        _ ->
            defaultUpdateRepositoryPayload


buildUpdateRepoIntPayload : Field -> Int -> UpdateRepositoryPayload
buildUpdateRepoIntPayload field value =
    case field of
        "build_limit" ->
            { defaultUpdateRepositoryPayload | limit = Just value }

        "timeout" ->
            { defaultUpdateRepositoryPayload | timeout = Just value }

        "counter" ->
            { defaultUpdateRepositoryPayload | counter = Just value }

        _ ->
            defaultUpdateRepositoryPayload



-- PIPELINE


type alias PipelineModel =
    { config : ( WebData PipelineConfig, Errors.Error )
    , expanded : Bool
    , expanding : Bool
    , expand : Maybe String
    , lineFocus : LogFocus
    , focusFragment : FocusFragment
    }


defaultPipeline : PipelineModel
defaultPipeline =
    PipelineModel ( NotAsked, "" ) False False Nothing ( Nothing, Nothing ) Nothing


type alias PipelineConfig =
    { rawData : String
    , decodedData : String
    }


type alias PipelineTemplates =
    { data : WebData Templates
    , error : Errors.Error
    , show : Bool
    }


type alias Template =
    { link : String
    , name : String
    , source : String
    , type_ : String
    }


type alias Templates =
    Dict String Template


defaultPipelineTemplates : PipelineTemplates
defaultPipelineTemplates =
    PipelineTemplates NotAsked "" True


decodePipelineConfig : Json.Decode.Decoder PipelineConfig
decodePipelineConfig =
    Json.Decode.succeed
        (\data ->
            PipelineConfig
                data
                -- "decodedData"
                ""
        )
        |> optional "data" string ""


decodePipelineExpand : Json.Decode.Decoder String
decodePipelineExpand =
    Json.Decode.string


decodePipelineTemplates : Json.Decode.Decoder Templates
decodePipelineTemplates =
    Json.Decode.dict decodeTemplate


decodeTemplate : Json.Decode.Decoder Template
decodeTemplate =
    Json.Decode.succeed Template
        |> optional "link" string ""
        |> optional "name" string ""
        |> optional "source" string ""
        |> optional "type" string ""



-- BUILDS


type alias BuildsModel =
    { builds : WebData Builds
    , pager : List WebLink
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    , maybeEvent : Maybe Event
    , showTimestamp : Bool
    }


{-| Build : record type for vela build
-}
type alias Build =
    { id : Int
    , repository_id : Int
    , number : Int
    , parent : Int
    , event : String
    , status : Status
    , error : String
    , enqueued : Int
    , created : Int
    , started : Int
    , finished : Int
    , deploy : String
    , clone : String
    , source : String
    , title : String
    , message : String
    , commit : String
    , sender : String
    , author : String
    , branch : String
    , link : String
    , ref : Ref
    , base_ref : Ref
    , host : String
    , runtime : String
    , distribution : String
    , approved_at : Int
    , approved_by : String
    , deploy_payload : Maybe (List KeyValuePair)
    }


decodeBuild : Decoder Build
decodeBuild =
    Json.Decode.succeed Build
        |> optional "id" int -1
        |> optional "repository_id" int -1
        |> optional "number" int -1
        |> optional "parent" int -1
        |> optional "event" string ""
        |> optional "status" buildStatusDecoder Pending
        |> optional "error" string ""
        |> optional "enqueued" int -1
        |> optional "created" int -1
        |> optional "started" int -1
        |> optional "finished" int -1
        |> optional "deploy" string ""
        |> optional "clone" string ""
        |> optional "source" string ""
        |> optional "title" string ""
        |> optional "message" string ""
        |> optional "commit" string ""
        |> optional "sender" string ""
        |> optional "author" string ""
        |> optional "branch" string ""
        |> optional "link" string ""
        |> optional "ref" string ""
        |> optional "base_ref" string ""
        |> optional "host" string ""
        |> optional "runtime" string ""
        |> optional "distribution" string ""
        |> optional "approved_at" int -1
        |> optional "approved_by" string ""
        |> optional "deploy_payload" decodeDeploymentParameters Nothing


defaultBuildGraphModel : BuildGraphModel
defaultBuildGraphModel =
    BuildGraphModel "" NotAsked DOT.LR "" -1 True True


defaultBuildGraph : BuildGraph
defaultBuildGraph =
    BuildGraph -1 -1 "" "" Dict.empty []


encodeBuildGraphRenderData : BuildGraphRenderInteropData -> Json.Encode.Value
encodeBuildGraphRenderData graphData =
    Json.Encode.object
        [ ( "dot", Json.Encode.string graphData.dot )
        , ( "buildID", Json.Encode.int graphData.buildID )
        , ( "filter", Json.Encode.string graphData.filter )
        , ( "focusedNode", Json.Encode.int graphData.focusedNode )
        , ( "showServices", Json.Encode.bool graphData.showServices )
        , ( "showSteps", Json.Encode.bool graphData.showSteps )
        , ( "freshDraw", Json.Encode.bool graphData.freshDraw )
        ]


type alias BuildGraphRenderInteropData =
    { dot : String
    , buildID : Int
    , filter : String
    , focusedNode : Int
    , showServices : Bool
    , showSteps : Bool
    , freshDraw : Bool
    }


type alias BuildGraphModel =
    { buildNumber : BuildNumber
    , graph : WebData BuildGraph
    , rankdir : DOT.Rankdir
    , filter : String
    , focusedNode : Int
    , showServices : Bool
    , showSteps : Bool
    }


type alias BuildGraph =
    { buildID : Int
    , buildNumber : Int
    , org : Org
    , repo : Repo
    , nodes : Dict Int BuildGraphNode
    , edges : List BuildGraphEdge
    }


type alias BuildGraphNode =
    { cluster : Int
    , id : Int
    , name : String
    , status : String
    , startedAt : Int
    , finishedAt : Int
    , steps : List Step
    , focused : Bool
    }


type alias BuildGraphEdge =
    { cluster : Int
    , source : Int
    , destination : Int
    , status : String
    , focused : Bool
    }


decodeBuildGraph : Decoder BuildGraph
decodeBuildGraph =
    Json.Decode.succeed BuildGraph
        |> required "build_id" int
        |> required "build_number" int
        |> required "org" string
        |> required "repo" string
        |> required "nodes" (dict2 int decodeBuildGraphNode)
        |> optional "edges" (Json.Decode.list decodeEdge) []


decodeBuildGraphNode : Decoder BuildGraphNode
decodeBuildGraphNode =
    Json.Decode.succeed BuildGraphNode
        |> required "cluster" int
        |> required "id" int
        |> required "name" Json.Decode.string
        |> optional "status" string ""
        |> required "started_at" int
        |> required "finished_at" int
        |> optional "steps" decodeSteps []
        -- focused
        |> hardcoded False


decodeEdge : Decoder BuildGraphEdge
decodeEdge =
    Json.Decode.succeed BuildGraphEdge
        |> required "cluster" int
        |> required "source" int
        |> required "destination" int
        |> optional "status" string ""
        -- focused
        |> hardcoded False


type alias BuildGraphInteraction =
    { eventType : String
    , href : String
    , nodeID : String
    }


decodeOnGraphInteraction : (BuildGraphInteraction -> msg) -> msg -> Json.Decode.Value -> msg
decodeOnGraphInteraction msg noop interaction =
    case Json.Decode.decodeValue decodeGraphInteraction interaction of
        Ok interaction_ ->
            msg interaction_

        Err _ ->
            noop


decodeGraphInteraction : Decoder BuildGraphInteraction
decodeGraphInteraction =
    Json.Decode.succeed BuildGraphInteraction
        |> required "eventType" string
        |> optional "href" string ""
        |> optional "nodeID" string "-1"


{-| decodeBuilds : decodes json from vela into list of builds
-}
decodeBuilds : Decoder Builds
decodeBuilds =
    Json.Decode.list decodeBuild


{-| buildStatusDecoder : decodes string field "status" to the union type BuildStatus
-}
buildStatusDecoder : Decoder Status
buildStatusDecoder =
    string |> andThen toStatus


defaultBuilds : BuildsModel
defaultBuilds =
    BuildsModel RemoteData.NotAsked [] Nothing Nothing Nothing False


defaultDeployments : DeploymentsModel
defaultDeployments =
    DeploymentsModel RemoteData.NotAsked [] Nothing Nothing


type alias Builds =
    List Build


{-| Status : type enum to represent the possible statuses a vela object can be in
-}
type Status
    = Pending
    | Running
    | Success
    | Failure
    | Killed
    | Canceled
    | Error
    | PendingApproval


{-| toStatus : helper to decode string to Status
-}
toStatus : String -> Decoder Status
toStatus status =
    case status of
        "pending" ->
            succeed Pending

        "pending approval" ->
            succeed PendingApproval

        "running" ->
            succeed Running

        "success" ->
            succeed Success

        "failure" ->
            succeed Failure

        "killed" ->
            succeed Killed

        "canceled" ->
            succeed Canceled

        "error" ->
            succeed Error

        _ ->
            succeed Error


{-| stringToStatus : helper to convert string to Status
-}
stringToStatus : String -> Status
stringToStatus status =
    case status of
        "pending" ->
            Pending

        "running" ->
            Running

        "success" ->
            Success

        "failure" ->
            Failure

        "killed" ->
            Killed

        "canceled" ->
            Canceled

        "error" ->
            Error

        _ ->
            Error


{-| statusToString : helper to convert Status to string
-}
statusToString : Status -> String
statusToString status =
    case status of
        Pending ->
            "pending"

        PendingApproval ->
            "pending approval"

        Running ->
            "running"

        Success ->
            "success"

        Failure ->
            "failure"

        Killed ->
            "killed"

        Canceled ->
            "canceled"

        Error ->
            "error"


{-| isComplete : helper to determine if status is 'complete'
-}
isComplete : Status -> Bool
isComplete status =
    case status of
        Pending ->
            False

        PendingApproval ->
            False

        Running ->
            False

        Success ->
            True

        Failure ->
            True

        Error ->
            True

        Canceled ->
            True

        Killed ->
            True



-- STEP


type alias Step =
    { id : Int
    , build_id : Int
    , repo_id : Int
    , number : Int
    , name : String
    , stage : String
    , status : Status
    , error : String
    , exit_code : Int
    , created : Int
    , started : Int
    , finished : Int
    , host : String
    , runtime : String
    , distribution : String
    , image : String
    , viewing : Bool
    , logFocus : LogFocus
    }


{-| defaultStep : returns default, empty step
-}
defaultStep : Step
defaultStep =
    Step 0 0 0 0 "" "" Pending "" 0 0 0 0 "" "" "" "" False ( Nothing, Nothing )


{-| decodeStep : decodes json from vela into step
-}
decodeStep : Decoder Step
decodeStep =
    Json.Decode.succeed Step
        |> optional "id" int -1
        |> optional "build_id" int -1
        |> optional "repo_id" int -1
        |> optional "number" int -1
        |> optional "name" string ""
        |> optional "stage" string ""
        |> optional "status" buildStatusDecoder Pending
        |> optional "error" string ""
        |> optional "exit_code" int -1
        |> optional "created" int -1
        |> optional "started" int -1
        |> optional "finished" int -1
        |> optional "host" string ""
        |> optional "runtime" string ""
        |> optional "distribution" string ""
        |> optional "image" string ""
        -- "viewing"
        |> hardcoded False
        -- "logFocus"
        |> hardcoded ( Nothing, Nothing )


decodeSteps : Decoder (List Step)
decodeSteps =
    Json.Decode.list decodeStep


type alias Steps =
    List Step



-- SERVICE


type alias Service =
    { id : Int
    , build_id : Int
    , repo_id : Int
    , number : Int
    , name : String
    , status : Status
    , error : String
    , exit_code : Int
    , created : Int
    , started : Int
    , finished : Int
    , host : String
    , runtime : String
    , distribution : String
    , image : String
    , viewing : Bool
    , logFocus : LogFocus
    }


{-| decodeService : decodes json from vela into service
-}
decodeService : Decoder Service
decodeService =
    Json.Decode.succeed Service
        |> optional "id" int -1
        |> optional "build_id" int -1
        |> optional "repo_id" int -1
        |> optional "number" int -1
        |> optional "name" string ""
        |> optional "status" buildStatusDecoder Pending
        |> optional "error" string ""
        |> optional "exit_code" int -1
        |> optional "created" int -1
        |> optional "started" int -1
        |> optional "finished" int -1
        |> optional "host" string ""
        |> optional "runtime" string ""
        |> optional "distribution" string ""
        |> optional "image" string ""
        -- "viewing"
        |> hardcoded False
        -- "logFocus"
        |> hardcoded ( Nothing, Nothing )


decodeServices : Decoder (List Service)
decodeServices =
    Json.Decode.list decodeService


type alias Services =
    List Service


type alias LogFocus =
    ( Maybe Int, Maybe Int )



-- RESOURCE


type alias Resource a =
    { a
        | id : Int
        , number : Int
        , status : Status
        , viewing : Bool
        , logFocus : LogFocus
        , error : String
    }


type alias Resources a =
    List (Resource a)



-- LOG


type alias Log =
    { id : Int
    , step_id : Int
    , service_id : Int
    , build_id : Int
    , repository_id : Int
    , rawData : String
    , decodedLogs : String
    , size : Int
    }


newStepLog : Int -> Log
newStepLog id =
    Log id -1 -1 -1 -1 "" "" -1


{-| decodeLog : decodes json from vela into log
-}
decodeLog : Decoder Log
decodeLog =
    Json.Decode.succeed
        (\id step_id service_id build_id repository_id data ->
            Log
                id
                step_id
                service_id
                build_id
                repository_id
                data
                -- "decodedLogs"
                ""
                -- "size"
                (Bytes.Encode.getStringWidth data)
        )
        |> optional "id" int -1
        |> optional "step_id" int -1
        |> optional "service_id" int -1
        |> optional "build_id" int -1
        |> optional "repository_id" int -1
        |> optional "data" string ""


type alias Logs =
    List (WebData Log)


type alias FocusFragment =
    Maybe String



-- HOOKS


type alias HooksModel =
    { hooks : WebData Hooks
    , pager : List WebLink
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    }


defaultHooks : HooksModel
defaultHooks =
    HooksModel RemoteData.NotAsked [] Nothing Nothing


{-| Hook : record type for vela repo hooks
-}
type alias Hook =
    { id : Int
    , repo_id : Int
    , build_id : Int
    , source_id : String
    , number : Int
    , created : Int
    , host : String
    , event : String
    , branch : String
    , error : String
    , status : String
    , link : String
    }


decodeHook : Decoder Hook
decodeHook =
    Json.Decode.succeed Hook
        |> optional "id" int -1
        |> optional "repo_id" int -1
        |> optional "build_id" int -1
        |> optional "source_id" string ""
        |> optional "number" int -1
        |> optional "created" int -1
        |> optional "host" string ""
        |> optional "event" string ""
        |> optional "branch" string ""
        |> optional "error" string ""
        |> optional "status" string ""
        |> optional "link" string ""


{-| decodeHooks : decodes json from vela into list of hooks
-}
decodeHooks : Decoder Hooks
decodeHooks =
    Json.Decode.list decodeHook


type alias Hooks =
    List Hook


type alias RepoResourceIdentifier =
    ( Org, Repo, String )



-- SCHEDULES


type alias Schedule =
    { id : Int
    , org : String
    , repo : String
    , name : String
    , entry : String
    , enabled : Bool
    , created_at : Int
    , created_by : String
    , scheduled_at : Int
    , updated_at : Int
    , updated_by : String
    , branch : String
    }


type alias Schedules =
    List Schedule


type alias AddSchedulePayload =
    { id : Int
    , org : String
    , repo : String
    , name : String
    , entry : String
    , enabled : Bool
    , branch : String
    }


type alias UpdateSchedulePayload =
    { org : Maybe Org
    , repo : Maybe Repo
    , name : Maybe Name
    , entry : Maybe String
    , enabled : Maybe Bool
    , branch : Maybe String
    }


buildUpdateSchedulePayload :
    Maybe Org
    -> Maybe Repo
    -> Maybe Name
    -> Maybe String
    -> Maybe Bool
    -> Maybe String
    -> UpdateSchedulePayload
buildUpdateSchedulePayload org repo name entry enabled branch =
    UpdateSchedulePayload org repo name entry enabled branch


decodeSchedule : Decoder Schedule
decodeSchedule =
    Json.Decode.succeed Schedule
        |> optional "id" int -1
        |> optional "repo.org" string ""
        |> optional "repo.repo" string ""
        |> optional "name" string ""
        |> optional "entry" string ""
        |> optional "active" bool False
        |> optional "created_at" int 0
        |> optional "created_by" string ""
        |> optional "scheduled_at" int 0
        |> optional "updated_at" int 0
        |> optional "updated_by" string ""
        |> optional "branch" string ""


decodeSchedules : Decoder Schedules
decodeSchedules =
    Json.Decode.list decodeSchedule


encodeUpdateSchedule : UpdateSchedulePayload -> Json.Encode.Value
encodeUpdateSchedule schedule =
    Json.Encode.object
        [ ( "name", encodeOptional Json.Encode.string schedule.name )
        , ( "entry", encodeOptional Json.Encode.string schedule.entry )
        , ( "active", encodeOptional Json.Encode.bool schedule.enabled )
        , ( "branch", encodeOptional Json.Encode.string schedule.branch )
        ]



-- SECRETS


{-| Secret : record type for vela secrets
-}
type alias Secret =
    { id : Int
    , org : Org
    , repo : Repo
    , team : Key
    , key : String
    , name : String
    , type_ : SecretType
    , images : List String
    , events : List String
    , allowCommand : Bool
    }


type SecretType
    = SharedSecret
    | OrgSecret
    | RepoSecret


defaultSecret : SecretType -> Secret
defaultSecret secretType =
    Secret -1 "" "" "" "" "" secretType [] [ "push" ] True


{-| secretTypeDecoder : decodes string field "type" to the union type SecretType
-}
secretTypeDecoder : Decoder SecretType
secretTypeDecoder =
    string |> andThen toSecretTypeDecoder


{-| toSecretTypeDecoder : helper to decode string to SecretType
-}
toSecretTypeDecoder : String -> Decoder SecretType
toSecretTypeDecoder type_ =
    case type_ of
        "shared" ->
            succeed SharedSecret

        "org" ->
            succeed OrgSecret

        "repo" ->
            succeed RepoSecret

        _ ->
            Json.Decode.fail "unrecognized secret type"


{-| secretTypeToString : helper to convert SecretType to string
-}
secretTypeToString : SecretType -> String
secretTypeToString type_ =
    case type_ of
        SharedSecret ->
            "shared"

        OrgSecret ->
            "org"

        RepoSecret ->
            "repo"


{-| secretsErrorLabel : helper to convert SecretType to string for printing GET secrets resource errors
-}
secretsErrorLabel : SecretType -> Org -> Maybe Key -> String
secretsErrorLabel type_ org key =
    case type_ of
        OrgSecret ->
            "org secrets for " ++ org

        RepoSecret ->
            "repo secrets for " ++ org ++ "/" ++ Maybe.withDefault "" key

        SharedSecret ->
            "shared secrets for " ++ org ++ "/" ++ Maybe.withDefault "" key


{-| maybeSecretTypeToMaybeString : helper to convert Maybe SecretType to Maybe string
-}
maybeSecretTypeToMaybeString : Maybe SecretType -> Maybe String
maybeSecretTypeToMaybeString type_ =
    case type_ of
        Just SharedSecret ->
            Just "shared"

        Just OrgSecret ->
            Just "org"

        Just RepoSecret ->
            Just "repo"

        _ ->
            Nothing


{-| secretToKey : helper to create secret key
-}
secretToKey : Secret -> String
secretToKey secret =
    case secret.type_ of
        SharedSecret ->
            secret.org ++ "/" ++ secret.team ++ "/" ++ secret.name

        OrgSecret ->
            secret.org ++ "/" ++ secret.name

        RepoSecret ->
            secret.org ++ "/" ++ secret.repo ++ "/" ++ secret.name


decodeSecret : Decoder Secret
decodeSecret =
    Json.Decode.succeed Secret
        |> optional "id" int -1
        |> optional "org" string ""
        |> optional "repo" string ""
        |> optional "team" string ""
        |> optional "key" string ""
        |> optional "name" string ""
        |> optional "type" secretTypeDecoder RepoSecret
        |> optional "images" (Json.Decode.list string) []
        |> optional "events" (Json.Decode.list string) []
        |> optional "allow_command" bool False


{-| decodeSecrets : decodes json from vela into list of secrets
-}
decodeSecrets : Decoder Secrets
decodeSecrets =
    Json.Decode.list decodeSecret


type alias Secrets =
    List Secret


type alias SecretPayload =
    { type_ : Maybe SecretType
    , org : Maybe Org
    , repo : Maybe Repo
    , team : Maybe Team
    , name : Maybe Name
    , value : Maybe String
    , events : Maybe (List String)
    , images : Maybe (List String)
    , allowCommand : Maybe Bool
    }


encodeSecretPayload : SecretPayload -> Json.Encode.Value
encodeSecretPayload secret =
    Json.Encode.object
        [ ( "type", encodeOptional Json.Encode.string <| maybeSecretTypeToMaybeString secret.type_ )
        , ( "org", encodeOptional Json.Encode.string secret.org )
        , ( "repo", encodeOptional Json.Encode.string secret.repo )
        , ( "team", encodeOptional Json.Encode.string secret.team )
        , ( "name", encodeOptional Json.Encode.string secret.name )
        , ( "value", encodeOptional Json.Encode.string secret.value )
        , ( "events", encodeOptionalList Json.Encode.string secret.events )
        , ( "images", encodeOptionalList Json.Encode.string secret.images )
        , ( "allow_command", encodeOptional Json.Encode.bool secret.allowCommand )
        ]


buildSecretPayload :
    { type_ : Maybe SecretType
    , org : Maybe String
    , repo : Maybe String
    , team : Maybe String
    , name : Maybe String
    , value : Maybe String
    , events : Maybe (List String)
    , images : Maybe (List String)
    , allowCommands : Maybe Bool
    }
    -> SecretPayload
buildSecretPayload { type_, org, repo, team, name, value, events, images, allowCommands } =
    SecretPayload type_ org repo team name value events images allowCommands



-- DEPLOYMENT


type alias DeploymentsModel =
    { deployments : WebData (List Deployment)
    , pager : List WebLink
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    }


decodeDeployment : Decoder Deployment
decodeDeployment =
    Json.Decode.succeed Deployment
        |> optional "id" int -1
        |> optional "repo_id" int -1
        |> optional "url" string ""
        |> optional "user" string ""
        |> optional "commit" string ""
        |> optional "ref" string ""
        |> optional "task" string ""
        |> optional "target" string ""
        |> optional "description" string ""
        |> optional "payload" decodeDeploymentParameters Nothing


decodeDeployments : Decoder (List Deployment)
decodeDeployments =
    Json.Decode.list decodeDeployment



{- payload -}


encodeKeyValuePair : KeyValuePair -> ( String, Json.Encode.Value )
encodeKeyValuePair kvp =
    ( kvp.key, Json.Encode.string kvp.value )


encodeOptionalKeyValuePairList : Maybe (List KeyValuePair) -> Json.Encode.Value
encodeOptionalKeyValuePairList value =
    case value of
        Just value_ ->
            Json.Encode.object (List.map encodeKeyValuePair value_)

        Nothing ->
            Json.Encode.null


decodeKeyValuePair : ( String, String ) -> KeyValuePair
decodeKeyValuePair ( k, v ) =
    KeyValuePair k v


decodeKeyValuePairs : List ( String, String ) -> Maybe (List KeyValuePair)
decodeKeyValuePairs o =
    if List.isEmpty o then
        Nothing

    else
        Just <| List.map decodeKeyValuePair <| o


decodeDeploymentParameters : Decoder (Maybe (List KeyValuePair))
decodeDeploymentParameters =
    Json.Decode.map decodeKeyValuePairs <| Json.Decode.keyValuePairs Json.Decode.string


type alias DeploymentPayload =
    { org : Maybe String
    , repo : Maybe String
    , commit : Maybe String
    , description : Maybe String
    , ref : Maybe String
    , target : Maybe String
    , task : Maybe String
    , payload : Maybe (List KeyValuePair)
    }


buildDeploymentPayload :
    { org : Maybe String
    , repo : Maybe String
    , commit : Maybe String
    , description : Maybe String
    , ref : Maybe String
    , target : Maybe String
    , task : Maybe String
    , payload : Maybe (List KeyValuePair)
    }
    -> DeploymentPayload
buildDeploymentPayload { org, repo, commit, description, ref, target, task, payload } =
    DeploymentPayload org repo commit description ref target task payload


encodeDeploymentPayload : DeploymentPayload -> Json.Encode.Value
encodeDeploymentPayload deployment =
    Json.Encode.object
        [ ( "org", encodeOptional Json.Encode.string deployment.org )
        , ( "repo", encodeOptional Json.Encode.string deployment.repo )
        , ( "commit", encodeOptional Json.Encode.string deployment.commit )
        , ( "description", encodeOptional Json.Encode.string deployment.description )
        , ( "ref", encodeOptional Json.Encode.string deployment.ref )
        , ( "target", encodeOptional Json.Encode.string deployment.target )
        , ( "task", encodeOptional Json.Encode.string deployment.task )
        , ( "payload", encodeOptionalKeyValuePairList deployment.payload )
        ]
