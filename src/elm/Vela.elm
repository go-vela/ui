{--
SPDX-License-Identifier: Apache-2.0
--}


module Vela exposing
    ( AddSchedulePayload
    , AuthParams
    , Build
    , BuildGraph
    , BuildGraphEdge
    , BuildGraphModel
    , BuildGraphNode
    , BuildModel
    , BuildNumber
    , Builds
    , BuildsModel
    , ChownRepo
    , Copy
    , CurrentUser
    , Deployment
    , DeploymentId
    , DeploymentPayload
    , DeploymentsModel
    , DisableRepo
    , EnableRepo
    , EnableRepos
    , EnableRepositoryPayload
    , Enabled
    , Enabling(..)
    , Engine
    , Event
    , Favicon
    , Favorites
    , Field
    , FocusFragment
    , GraphInteraction
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
    , RepairRepo
    , Repo
    , RepoModel
    , RepoResourceIdentifier
    , RepoSearchFilters
    , Repositories
    , Repository
    , Resource
    , Resources
    , Schedule
    , ScheduleName
    , Schedules
    , SearchFilter
    , Secret
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
    , Theme(..)
    , Type
    , UpdateRepositoryPayload
    , UpdateSchedulePayload
    , UpdateSecretPayload
    , UpdateUserPayload
    , buildDeploymentPayload
    , buildUpdateFavoritesPayload
    , buildUpdateRepoBoolPayload
    , buildUpdateRepoIntPayload
    , buildUpdateRepoStringPayload
    , buildUpdateSchedulePayload
    , buildUpdateSecretPayload
    , decodeBuild
    , decodeBuildGraph
    , decodeBuilds
    , decodeCurrentUser
    , decodeDeployment
    , decodeDeployments
    , decodeGraphInteraction
    , decodeHooks
    , decodeLog
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
    , decodeSourceRepositories
    , decodeStep
    , decodeTheme
    , defaultBuildGraph
    , defaultEnableRepositoryPayload
    , defaultFavicon
    , defaultPipeline
    , defaultPipelineTemplates
    , defaultRepoModel
    , defaultStep
    , encodeBuildGraphRenderData
    , encodeDeploymentPayload
    , encodeEnableRepository
    , encodeTheme
    , encodeUpdateRepository
    , encodeUpdateSchedule
    , encodeUpdateSecret
    , encodeUpdateUser
    , isComplete
    , secretToKey
    , secretTypeToString
    , secretsErrorLabel
    , statusToFavicon
    , statusToString
    , stringToStatus
    , stringToTheme
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
import Errors exposing (Error)
import Json.Decode as Decode exposing (Decoder, andThen, bool, int, string, succeed)
import Json.Decode.Extra exposing (dict2)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as Encode exposing (Value)
import LinkHeader exposing (WebLink)
import RemoteData exposing (RemoteData(..), WebData)
import Url.Builder as UB
import Visualization.DOT as DOT



-- COMMON


type Theme
    = Light
    | Dark


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



-- THEME


stringToTheme : String -> Theme
stringToTheme theme =
    case theme of
        "theme-light" ->
            Light

        _ ->
            Dark


decodeTheme : Decoder Theme
decodeTheme =
    Decode.string
        |> Decode.andThen
            (\str ->
                Decode.succeed <| stringToTheme str
            )


encodeTheme : Theme -> Encode.Value
encodeTheme theme =
    case theme of
        Light ->
            Encode.string "theme-light"

        _ ->
            Encode.string "theme-dark"



-- CURRENTUSER


type alias CurrentUser =
    { id : Int
    , name : String
    , favorites : Favorites
    , active : Bool
    , admin : Bool
    }


type alias Favorites =
    List String


decodeCurrentUser : Decoder CurrentUser
decodeCurrentUser =
    Decode.succeed CurrentUser
        |> required "id" int
        |> required "name" string
        |> optional "favorites" (Decode.list string) []
        |> required "active" bool
        |> required "admin" bool


type alias UpdateUserPayload =
    { name : Maybe String
    , favorites : Maybe Favorites
    }


defaultUpdateUserPayload : UpdateUserPayload
defaultUpdateUserPayload =
    UpdateUserPayload Nothing Nothing


encodeUpdateUser : UpdateUserPayload -> Encode.Value
encodeUpdateUser user =
    Encode.object
        [ ( "favorites", encodeOptionalList Encode.string user.favorites )
        ]


buildUpdateFavoritesPayload : Favorites -> UpdateUserPayload
buildUpdateFavoritesPayload value =
    { defaultUpdateUserPayload | favorites = Just value }



-- AUTH


type alias AuthParams =
    { code : Maybe String
    , state : Maybe String
    }



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


updateBuildPipelineConfig : ( WebData PipelineConfig, Error ) -> PipelineModel -> PipelineModel
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
    Decode.list decodeRepository


decodeRepository : Decoder Repository
decodeRepository =
    Decode.succeed Repository
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


decodeSourceRepositories : Decoder SourceRepositories
decodeSourceRepositories =
    Decode.dict (Decode.list decodeRepository)


{-| Repositories : type alias for list of enabled repositories
-}
type alias Repositories =
    List Repository


{-| SourceRepositories : type alias for repositories available for creation
-}
type alias SourceRepositories =
    Dict String Repositories


encodeEnableRepository : EnableRepositoryPayload -> Encode.Value
encodeEnableRepository repo =
    Encode.object
        [ ( "org", Encode.string <| repo.org )
        , ( "name", Encode.string <| repo.name )
        , ( "full_name", Encode.string <| repo.full_name )
        , ( "link", Encode.string <| repo.link )
        , ( "clone", Encode.string <| repo.clone )
        , ( "private", Encode.bool <| repo.private )
        , ( "trusted", Encode.bool <| repo.trusted )
        , ( "active", Encode.bool <| repo.active )
        , ( "allow_pull", Encode.bool <| repo.allow_pull )
        , ( "allow_push", Encode.bool <| repo.allow_push )
        , ( "allow_deploy", Encode.bool <| repo.allow_deploy )
        , ( "allow_tag", Encode.bool <| repo.allow_tag )
        , ( "allow_comment", Encode.bool <| repo.allow_comment )
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
    , limit : Maybe Int
    , timeout : Maybe Int
    , counter : Maybe Int
    , pipeline_type : Maybe String
    }


type alias Field =
    String


defaultUpdateRepositoryPayload : UpdateRepositoryPayload
defaultUpdateRepositoryPayload =
    UpdateRepositoryPayload Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing


encodeUpdateRepository : UpdateRepositoryPayload -> Encode.Value
encodeUpdateRepository repo =
    Encode.object
        [ ( "active", encodeOptional Encode.bool repo.active )
        , ( "private", encodeOptional Encode.bool repo.private )
        , ( "trusted", encodeOptional Encode.bool repo.trusted )
        , ( "allow_pull", encodeOptional Encode.bool repo.allow_pull )
        , ( "allow_push", encodeOptional Encode.bool repo.allow_push )
        , ( "allow_deploy", encodeOptional Encode.bool repo.allow_deploy )
        , ( "allow_tag", encodeOptional Encode.bool repo.allow_tag )
        , ( "allow_comment", encodeOptional Encode.bool repo.allow_comment )
        , ( "visibility", encodeOptional Encode.string repo.visibility )
        , ( "build_limit", encodeOptional Encode.int repo.limit )
        , ( "timeout", encodeOptional Encode.int repo.timeout )
        , ( "counter", encodeOptional Encode.int repo.counter )
        , ( "pipeline_type", encodeOptional Encode.string repo.pipeline_type )
        ]


encodeOptional : (a -> Encode.Value) -> Maybe a -> Encode.Value
encodeOptional encoder value =
    case value of
        Just value_ ->
            encoder value_

        Nothing ->
            Encode.null


encodeOptionalList : (a -> Encode.Value) -> Maybe (List a) -> Encode.Value
encodeOptionalList encoder value =
    case value of
        Just value_ ->
            Encode.list encoder value_

        Nothing ->
            Encode.null


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
    { config : ( WebData PipelineConfig, Error )
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
    , error : Error
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


decodePipelineConfig : Decode.Decoder PipelineConfig
decodePipelineConfig =
    Decode.succeed
        (\data ->
            PipelineConfig
                data
                -- "decodedData"
                ""
        )
        |> optional "data" string ""


decodePipelineExpand : Decode.Decoder String
decodePipelineExpand =
    Decode.string


decodePipelineTemplates : Decode.Decoder Templates
decodePipelineTemplates =
    Decode.dict decodeTemplate


decodeTemplate : Decode.Decoder Template
decodeTemplate =
    Decode.succeed Template
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
    , deploy_payload : Maybe (List KeyValuePair)
    }


decodeBuild : Decoder Build
decodeBuild =
    Decode.succeed Build
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
        |> optional "deploy_payload" decodeDeploymentParameters Nothing


defaultBuildGraphModel : BuildGraphModel
defaultBuildGraphModel =
    BuildGraphModel "" NotAsked DOT.LR "" -1 True True


defaultBuildGraph : BuildGraph
defaultBuildGraph =
    BuildGraph Dict.empty []


encodeBuildGraphRenderData : BuildGraphRenderInteropData -> Encode.Value
encodeBuildGraphRenderData graphData =
    Encode.object
        [ ( "dot", Encode.string graphData.dot )
        , ( "build_id", Encode.int graphData.buildID )
        , ( "filter", Encode.string graphData.filter )
        , ( "focused_node", Encode.int graphData.focusedNode )
        , ( "show_services", Encode.bool graphData.showServices )
        , ( "show_steps", Encode.bool graphData.showSteps )
        , ( "center_on_draw", Encode.bool graphData.centerOnDraw )
        ]


type alias BuildGraphRenderInteropData =
    { dot : String
    , buildID : Int
    , filter : String
    , focusedNode : Int
    , showServices : Bool
    , showSteps : Bool
    , centerOnDraw : Bool
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
    { nodes : Dict Int BuildGraphNode
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
    Decode.succeed BuildGraph
        |> required "nodes" (dict2 int decodeBuildGraphNode)
        |> optional "edges" (Decode.list decodeEdge) []


decodeBuildGraphNode : Decoder BuildGraphNode
decodeBuildGraphNode =
    Decode.succeed BuildGraphNode
        |> required "cluster" int
        |> required "id" int
        |> required "name" Decode.string
        |> optional "status" string ""
        |> required "started_at" int
        |> required "finished_at" int
        |> optional "steps" (Decode.list decodeStep) []
        -- focused
        |> hardcoded False


decodeEdge : Decoder BuildGraphEdge
decodeEdge =
    Decode.succeed BuildGraphEdge
        |> required "cluster" int
        |> required "source" int
        |> required "destination" int
        |> optional "status" string ""
        -- focused
        |> hardcoded False


type alias GraphInteraction =
    { event_type : String
    , href : String
    , node_id : String
    , step_id : String
    }


decodeGraphInteraction : Decoder GraphInteraction
decodeGraphInteraction =
    Decode.succeed GraphInteraction
        |> required "event_type" string
        |> optional "href" string ""
        |> optional "node_id" string "-1"
        |> optional "step_id" string "-1"


{-| decodeBuilds : decodes json from vela into list of builds
-}
decodeBuilds : Decoder Builds
decodeBuilds =
    Decode.list decodeBuild


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


{-| toStatus : helper to decode string to Status
-}
toStatus : String -> Decoder Status
toStatus status =
    case status of
        "pending" ->
            succeed Pending

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



-- STATUS FAVICONS


type alias Favicon =
    String


{-| statusToFavicon : takes build status and returns absolute path to the appropriate favicon
-}
statusToFavicon : Status -> Favicon
statusToFavicon status =
    let
        fileName =
            "favicon"
                ++ (case status of
                        Pending ->
                            "-pending"

                        Running ->
                            "-running"

                        Success ->
                            "-success"

                        Failure ->
                            "-failure"

                        Killed ->
                            "-failure"

                        Canceled ->
                            "-canceled"

                        Error ->
                            "-failure"
                   )
                ++ ".ico"
    in
    UB.absolute [ "images", fileName ] []


{-| defaultFavicon : returns absolute path to default favicon
-}
defaultFavicon : String
defaultFavicon =
    UB.absolute [ "images", "favicon.ico" ] []



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
    Decode.succeed Step
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
    Decode.succeed Service
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


{-| decodeLog : decodes json from vela into log
-}
decodeLog : Decoder Log
decodeLog =
    Decode.succeed
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
    Decode.succeed Hook
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
    Decode.list decodeHook


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
    Decode.succeed Schedule
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
    Decode.list decodeSchedule


encodeUpdateSchedule : UpdateSchedulePayload -> Encode.Value
encodeUpdateSchedule schedule =
    Encode.object
        [ ( "name", encodeOptional Encode.string schedule.name )
        , ( "entry", encodeOptional Encode.string schedule.entry )
        , ( "active", encodeOptional Encode.bool schedule.enabled )
        , ( "branch", encodeOptional Encode.string schedule.branch )
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
            Decode.fail "unrecognized secret type"


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
    Decode.succeed Secret
        |> optional "id" int -1
        |> optional "org" string ""
        |> optional "repo" string ""
        |> optional "team" string ""
        |> optional "key" string ""
        |> optional "name" string ""
        |> optional "type" secretTypeDecoder RepoSecret
        |> optional "images" (Decode.list string) []
        |> optional "events" (Decode.list string) []
        |> optional "allow_command" bool False


{-| decodeSecrets : decodes json from vela into list of secrets
-}
decodeSecrets : Decoder Secrets
decodeSecrets =
    Decode.list decodeSecret


type alias Secrets =
    List Secret


type alias UpdateSecretPayload =
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


encodeUpdateSecret : UpdateSecretPayload -> Encode.Value
encodeUpdateSecret secret =
    Encode.object
        [ ( "type", encodeOptional Encode.string <| maybeSecretTypeToMaybeString secret.type_ )
        , ( "org", encodeOptional Encode.string secret.org )
        , ( "repo", encodeOptional Encode.string secret.repo )
        , ( "team", encodeOptional Encode.string secret.team )
        , ( "name", encodeOptional Encode.string secret.name )
        , ( "value", encodeOptional Encode.string secret.value )
        , ( "events", encodeOptionalList Encode.string secret.events )
        , ( "images", encodeOptionalList Encode.string secret.images )
        , ( "allow_command", encodeOptional Encode.bool secret.allowCommand )
        ]


buildUpdateSecretPayload :
    Maybe SecretType
    -> Maybe Org
    -> Maybe Repo
    -> Maybe Team
    -> Maybe Name
    -> Maybe String
    -> Maybe (List String)
    -> Maybe (List String)
    -> Maybe Bool
    -> UpdateSecretPayload
buildUpdateSecretPayload type_ org repo team name value events images allowCommand =
    UpdateSecretPayload type_ org repo team name value events images allowCommand



-- DEPLOYMENT


type alias DeploymentsModel =
    { deployments : WebData (List Deployment)
    , pager : List WebLink
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    }


decodeDeployment : Decoder Deployment
decodeDeployment =
    Decode.succeed Deployment
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
    Decode.list decodeDeployment



{- payload -}


encodeKeyValuePair : KeyValuePair -> ( String, Value )
encodeKeyValuePair kvp =
    ( kvp.key, Encode.string kvp.value )


encodeOptionalKeyValuePairList : Maybe (List KeyValuePair) -> Encode.Value
encodeOptionalKeyValuePairList value =
    case value of
        Just value_ ->
            Encode.object (List.map encodeKeyValuePair value_)

        Nothing ->
            Encode.null


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
    Decode.map decodeKeyValuePairs <| Decode.keyValuePairs Decode.string


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


encodeDeploymentPayload : DeploymentPayload -> Encode.Value
encodeDeploymentPayload deployment =
    Encode.object
        [ ( "org", encodeOptional Encode.string deployment.org )
        , ( "repo", encodeOptional Encode.string deployment.repo )
        , ( "commit", encodeOptional Encode.string deployment.commit )
        , ( "description", encodeOptional Encode.string deployment.description )
        , ( "ref", encodeOptional Encode.string deployment.ref )
        , ( "target", encodeOptional Encode.string deployment.target )
        , ( "task", encodeOptional Encode.string deployment.task )
        , ( "payload", encodeOptionalKeyValuePairList deployment.payload )
        ]


buildDeploymentPayload :
    Maybe Org
    -> Maybe Repo
    -> Maybe Commit
    -> Maybe Description
    -> Maybe Ref
    -> Maybe Target
    -> Maybe Task
    -> Maybe Payload
    -> DeploymentPayload
buildDeploymentPayload org rep commit description ref target task payload =
    DeploymentPayload
        org
        rep
        commit
        description
        ref
        target
        task
        payload



-- SEARCH


{-| RepoSearchFilters : type alias for filtering source repos
-}
type alias RepoSearchFilters =
    Dict Org SearchFilter


{-| SearchFilter : type alias for filtering source repos
-}
type alias SearchFilter =
    String



-- UPDATES


{-| Copy : takes a string and notifies the user of copy event
-}
type alias Copy msg =
    String -> msg


{-| DisableRepo : takes repo and disables it on Vela
-}
type alias DisableRepo msg =
    Repository -> msg


{-| EnableRepo : takes repo and enables it on Vela
-}
type alias EnableRepo msg =
    Repository -> msg


{-| EnableRepos : takes repos and enables them on Vela
-}
type alias EnableRepos msg =
    Repositories -> msg


{-| ChownRepo : takes repo and changes ownership on Vela
-}
type alias ChownRepo msg =
    Repository -> msg


{-| RepairRepo : takes repo and re-enables the webhook on it
-}
type alias RepairRepo msg =
    Repository -> msg
