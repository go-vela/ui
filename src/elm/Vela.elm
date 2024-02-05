{--
SPDX-License-Identifier: Apache-2.0
--}


module Vela exposing
    ( AllowEvents
    , Build
    , BuildGraph
    , BuildGraphEdge
    , BuildGraphInteraction
    , BuildGraphNode
    , BuildNumber
    , CurrentUser
    , Deployment
    , DeploymentPayload
    , EnableRepoPayload
    , Enabled(..)
    , Engine
    , Event
    , Hook
    , HookNumber
    , Key
    , KeyValuePair
    , Log
    , Name
    , Org
    , PipelineConfig
    , Ref
    , Repo
    , RepoPayload
    , Repository
    , Schedule
    , SchedulePayload
    , Secret
    , SecretPayload
    , SecretType(..)
    , Service
    , ServiceNumber
    , SourceRepositories
    , Status(..)
    , Step
    , StepNumber
    , Template
    , Templates
    , Type
    , buildEnableRepoPayload
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
    , decodeServices
    , decodeSourceRepositories
    , decodeSteps
    , defaultAllowEvents
    , defaultDeploymentPayload
    , defaultRepoPayload
    , defaultSchedulePayload
    , defaultSecretPayload
    , defaultUpdateUserPayload
    , enableUpdate
    , encodeBuildGraphRenderData
    , encodeDeploymentPayload
    , encodeEnableRepository
    , encodeRepoPayload
    , encodeSchedulePayload
    , encodeSecretPayload
    , encodeUpdateUser
    , secretToKey
    , secretTypeToString
    , setAllowEvents
    , statusToString
    )

import Bytes.Encode
import Dict exposing (Dict)
import Json.Decode exposing (Decoder, andThen, bool, int, string, succeed)
import Json.Decode.Extra exposing (dict2)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode
import RemoteData exposing (WebData)



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



-- USER


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



-- SOURCE REPOS


type alias SourceRepositories =
    Dict String (List Repository)


buildEnableRepoPayload : Repository -> EnableRepoPayload
buildEnableRepoPayload repo =
    EnableRepoPayload
        repo.org
        repo.name
        repo.full_name
        repo.link
        repo.clone
        repo.private
        repo.trusted
        repo.active
        repo.allow_pull
        repo.allow_push
        repo.allow_deploy
        repo.allow_tag
        repo.allow_comment
        repo.allowEvents


encodeEnableRepository : EnableRepoPayload -> Json.Encode.Value
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
        , ( "allow_events", encodeAllowEvents repo.allowEvents )
        ]


decodeSourceRepositories : Decoder SourceRepositories
decodeSourceRepositories =
    Json.Decode.dict (Json.Decode.list decodeRepository)


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


enableRepoDict : Repository -> Enabled -> Dict String (List Repository) -> List Repository -> Dict String (List Repository)
enableRepoDict repo status repos orgRepos =
    Dict.update repo.org (\_ -> Just <| enableRepoList repo status orgRepos) repos


enableRepoList : Repository -> Enabled -> List Repository -> List Repository
enableRepoList repo status orgRepos =
    let
        active =
            case status of
                Enabled ->
                    True

                Disabled ->
                    False

                _ ->
                    repo.active
    in
    List.map
        (\sourceRepo ->
            if sourceRepo.name == repo.name then
                { sourceRepo | active = active, enabled = status }

            else
                sourceRepo
        )
        orgRepos


type alias EnableRepoPayload =
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
    , allowEvents : AllowEvents
    }


type Enabled
    = ConfirmDisable
    | Disabling
    | Disabled
    | Enabling
    | Enabled
    | Failed


enabledDecoder : Decoder Enabled
enabledDecoder =
    bool |> andThen toEnabled


toEnabled : Bool -> Decoder Enabled
toEnabled active =
    if active then
        succeed Enabled

    else
        succeed Disabled



-- REPOSITORY


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
    , allowEvents : AllowEvents
    , enabled : Enabled
    , pipeline_type : String
    }


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
        |> optional "allow_events" decodeAllowEvents defaultAllowEvents
        -- "enabled"
        |> optional "active" enabledDecoder Disabled
        |> optional "pipeline_type" string ""


decodeRepositories : Decoder (List Repository)
decodeRepositories =
    Json.Decode.list decodeRepository


type alias RepoPayload =
    { private : Maybe Bool
    , trusted : Maybe Bool
    , active : Maybe Bool
    , allow_pull : Maybe Bool
    , allow_push : Maybe Bool
    , allow_deploy : Maybe Bool
    , allow_tag : Maybe Bool
    , allow_comment : Maybe Bool
    , allowEvents : Maybe AllowEvents
    , visibility : Maybe String
    , approve_build : Maybe String
    , limit : Maybe Int
    , timeout : Maybe Int
    , counter : Maybe Int
    , pipeline_type : Maybe String
    }


encodeRepoPayload : RepoPayload -> Json.Encode.Value
encodeRepoPayload repo =
    Json.Encode.object
        [ ( "active", encodeOptional Json.Encode.bool repo.active )
        , ( "private", encodeOptional Json.Encode.bool repo.private )
        , ( "trusted", encodeOptional Json.Encode.bool repo.trusted )
        , ( "allow_pull", encodeOptional Json.Encode.bool repo.allow_pull )
        , ( "allow_push", encodeOptional Json.Encode.bool repo.allow_push )
        , ( "allow_deploy", encodeOptional Json.Encode.bool repo.allow_deploy )
        , ( "allow_tag", encodeOptional Json.Encode.bool repo.allow_tag )
        , ( "allow_comment", encodeOptional Json.Encode.bool repo.allow_comment )
        , ( "allow_events", encodeOptional encodeAllowEvents repo.allowEvents )
        , ( "visibility", encodeOptional Json.Encode.string repo.visibility )
        , ( "approve_build", encodeOptional Json.Encode.string repo.approve_build )
        , ( "build_limit", encodeOptional Json.Encode.int repo.limit )
        , ( "timeout", encodeOptional Json.Encode.int repo.timeout )
        , ( "counter", encodeOptional Json.Encode.int repo.counter )
        , ( "pipeline_type", encodeOptional Json.Encode.string repo.pipeline_type )
        ]


defaultRepoPayload : RepoPayload
defaultRepoPayload =
    { private = Nothing
    , trusted = Nothing
    , active = Nothing
    , allow_pull = Nothing
    , allow_push = Nothing
    , allow_deploy = Nothing
    , allow_tag = Nothing
    , allow_comment = Nothing
    , allowEvents = Nothing
    , visibility = Nothing
    , approve_build = Nothing
    , limit = Nothing
    , timeout = Nothing
    , counter = Nothing
    , pipeline_type = Nothing
    }


type alias PushActions =
    { branch : Bool
    , tag : Bool
    }


type alias PullActions =
    { opened : Bool
    , synchronize : Bool
    , edited : Bool
    , reopened : Bool
    }


type alias DeployActions =
    { created : Bool
    }


type alias CommentActions =
    { created : Bool
    , edited : Bool
    }


type alias ScheduleActions =
    { run : Bool
    }


type alias AllowEvents =
    { push : PushActions
    , pull : PullActions
    , deploy : DeployActions
    , comment : CommentActions
    , schedule : ScheduleActions
    }


defaultAllowEvents : AllowEvents
defaultAllowEvents =
    { push =
        { branch = False
        , tag = False
        }
    , pull =
        { opened = False
        , synchronize = False
        , edited = False
        , reopened = False
        }
    , deploy =
        { created = False
        }
    , comment =
        { created = False
        , edited = False
        }
    , schedule =
        { run = False
        }
    }


decodePushActions : Decoder PushActions
decodePushActions =
    Json.Decode.succeed PushActions
        |> required "branch" bool
        |> required "tag" bool


decodePullActions : Decoder PullActions
decodePullActions =
    Json.Decode.succeed PullActions
        |> required "opened" bool
        |> required "synchronize" bool
        |> required "edited" bool
        |> required "reopened" bool


decodeDeployActions : Decoder DeployActions
decodeDeployActions =
    Json.Decode.succeed DeployActions
        |> required "created" bool


decodeCommentActions : Decoder CommentActions
decodeCommentActions =
    Json.Decode.succeed CommentActions
        |> required "created" bool
        |> required "edited" bool


decodeScheduleActions : Decoder ScheduleActions
decodeScheduleActions =
    Json.Decode.succeed ScheduleActions
        |> required "run" bool


decodeAllowEvents : Decoder AllowEvents
decodeAllowEvents =
    Json.Decode.succeed AllowEvents
        |> required "push" decodePushActions
        |> required "pull_request" decodePullActions
        |> required "deployment" decodeDeployActions
        |> required "comment" decodeCommentActions
        |> required "schedule" decodeScheduleActions


encodeAllowEvents : AllowEvents -> Json.Encode.Value
encodeAllowEvents events =
    Json.Encode.object
        [ ( "push", encodePushActions events.push )
        , ( "pull_request", encodePullActions events.pull )
        , ( "deployment", encodeDeployActions events.deploy )
        , ( "comment", encodeCommentActions events.comment )
        , ( "schedule", encodeScheduleActions events.schedule )
        ]


encodePushActions : PushActions -> Json.Encode.Value
encodePushActions push =
    Json.Encode.object
        [ ( "branch", Json.Encode.bool <| push.branch )
        , ( "tag", Json.Encode.bool <| push.tag )
        ]


encodePullActions : PullActions -> Json.Encode.Value
encodePullActions pull =
    Json.Encode.object
        [ ( "opened", Json.Encode.bool <| pull.opened )
        , ( "synchronize", Json.Encode.bool <| pull.synchronize )
        , ( "edited", Json.Encode.bool <| pull.edited )
        , ( "reopened", Json.Encode.bool <| pull.reopened )
        ]


encodeDeployActions : DeployActions -> Json.Encode.Value
encodeDeployActions deploy =
    Json.Encode.object
        [ ( "created", Json.Encode.bool <| deploy.created )
        ]


encodeCommentActions : CommentActions -> Json.Encode.Value
encodeCommentActions comment =
    Json.Encode.object
        [ ( "created", Json.Encode.bool <| comment.created )
        , ( "edited", Json.Encode.bool <| comment.edited )
        ]


encodeScheduleActions : ScheduleActions -> Json.Encode.Value
encodeScheduleActions schedule =
    Json.Encode.object
        [ ( "run", Json.Encode.bool <| schedule.run )
        ]


setAllowEvents :
    { a | allowEvents : AllowEvents }
    -> String
    -> Bool
    -> { a | allowEvents : AllowEvents }
setAllowEvents payload field val =
    let
        events =
            payload.allowEvents

        { push, pull, deploy, comment } =
            events
    in
    case field of
        "allow_push_branch" ->
            { payload
                | allowEvents = { events | push = { push | branch = val } }
            }

        "allow_push_tag" ->
            { payload
                | allowEvents = { events | push = { push | tag = val } }
            }

        "allow_pull_opened" ->
            { payload
                | allowEvents = { events | pull = { pull | opened = val } }
            }

        "allow_pull_synchronize" ->
            { payload
                | allowEvents = { events | pull = { pull | synchronize = val } }
            }

        "allow_pull_edited" ->
            { payload
                | allowEvents = { events | pull = { pull | edited = val } }
            }

        "allow_pull_reopened" ->
            { payload
                | allowEvents = { events | pull = { pull | reopened = val } }
            }

        "allow_deploy_created" ->
            { payload
                | allowEvents = { events | deploy = { deploy | created = val } }
            }

        "allow_comment_created" ->
            { payload
                | allowEvents = { events | comment = { comment | created = val } }
            }

        "allow_comment_edited" ->
            { payload
                | allowEvents = { events | comment = { comment | edited = val } }
            }

        _ ->
            payload



-- PIPELINE


type alias PipelineConfig =
    { rawData : String
    , decodedData : String
    }


type alias Template =
    { link : String
    , name : String
    , source : String
    , type_ : String
    }


type alias Templates =
    Dict String Template


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



-- GRAPH


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


type alias BuildGraph =
    { buildID : Int
    , buildNumber : Int
    , org : Org
    , repo : Repo
    , nodes : Dict Int BuildGraphNode
    , edges : List BuildGraphEdge
    }


type alias BuildGraphRenderInteropData =
    { dot : String
    , buildID : Int
    , filter : String
    , focusedNode : Int
    , showServices : Bool
    , showSteps : Bool
    , freshDraw : Bool
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


type alias BuildGraphEdge =
    { cluster : Int
    , source : Int
    , destination : Int
    , status : String
    , focused : Bool
    }


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


decodeBuilds : Decoder (List Build)
decodeBuilds =
    Json.Decode.list decodeBuild


buildStatusDecoder : Decoder Status
buildStatusDecoder =
    string |> andThen toStatus


type Status
    = Pending
    | Running
    | Success
    | Failure
    | Killed
    | Canceled
    | Error
    | PendingApproval


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
    }


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


decodeSteps : Decoder (List Step)
decodeSteps =
    Json.Decode.list decodeStep



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
    }


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


decodeServices : Decoder (List Service)
decodeServices =
    Json.Decode.list decodeService



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



-- HOOKS


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


decodeHooks : Decoder (List Hook)
decodeHooks =
    Json.Decode.list decodeHook



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


type alias SchedulePayload =
    { org : Maybe Org
    , repo : Maybe Repo
    , name : Maybe Name
    , entry : Maybe String
    , enabled : Maybe Bool
    , branch : Maybe String
    }


defaultSchedulePayload : SchedulePayload
defaultSchedulePayload =
    { org = Nothing
    , repo = Nothing
    , name = Nothing
    , entry = Nothing
    , enabled = Nothing
    , branch = Nothing
    }


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


decodeSchedules : Decoder (List Schedule)
decodeSchedules =
    Json.Decode.list decodeSchedule


encodeSchedulePayload : SchedulePayload -> Json.Encode.Value
encodeSchedulePayload schedule =
    Json.Encode.object
        [ ( "name", encodeOptional Json.Encode.string schedule.name )
        , ( "entry", encodeOptional Json.Encode.string schedule.entry )
        , ( "active", encodeOptional Json.Encode.bool schedule.enabled )
        , ( "branch", encodeOptional Json.Encode.string schedule.branch )
        ]



-- SECRETS


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
    , allowEvents : AllowEvents
    }


type SecretType
    = SharedSecret
    | OrgSecret
    | RepoSecret


secretTypeDecoder : Decoder SecretType
secretTypeDecoder =
    string |> andThen toSecretTypeDecoder


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


secretTypeToString : SecretType -> String
secretTypeToString type_ =
    case type_ of
        SharedSecret ->
            "shared"

        OrgSecret ->
            "org"

        RepoSecret ->
            "repo"


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
        |> optional "allow_events" decodeAllowEvents defaultAllowEvents


decodeSecrets : Decoder (List Secret)
decodeSecrets =
    Json.Decode.list decodeSecret


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
    , allowEvents : Maybe AllowEvents
    }


defaultSecretPayload : SecretPayload
defaultSecretPayload =
    { type_ = Nothing
    , org = Nothing
    , repo = Nothing
    , team = Nothing
    , name = Nothing
    , value = Nothing
    , events = Nothing
    , images = Nothing
    , allowCommand = Nothing
    , allowEvents = Nothing
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
        , ( "images", encodeOptionalList Json.Encode.string secret.images )
        , ( "allow_command", encodeOptional Json.Encode.bool secret.allowCommand )
        , ( "allow_events", encodeOptional encodeAllowEvents secret.allowEvents )
        ]



-- DEPLOYMENT


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


defaultDeploymentPayload : DeploymentPayload
defaultDeploymentPayload =
    { org = Nothing
    , repo = Nothing
    , commit = Nothing
    , description = Nothing
    , ref = Nothing
    , target = Nothing
    , task = Nothing
    , payload = Nothing
    }


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


decodeDeploymentParameters : Decoder (Maybe (List KeyValuePair))
decodeDeploymentParameters =
    Json.Decode.map decodeKeyValuePairs <| Json.Decode.keyValuePairs Json.Decode.string


type alias KeyValuePair =
    { key : String
    , value : String
    }


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
