{--
SPDX-License-Identifier: Apache-2.0
--}


module Vela exposing
    ( AddSchedulePayload
    , Build
    , BuildGraph
    , BuildGraphEdge
    , BuildGraphInteraction
    , BuildGraphNode
    , BuildNumber
    , CurrentUser
    , Deployment
    , DeploymentPayload
    , EnableRepositoryPayload
    , Enabled
    , Enabling(..)
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
    , Repository
    , Schedule
    , Secret
    , SecretPayload
    , SecretType(..)
    , Service
    , ServiceNumber
    , SourceRepositories
    , Status(..)
    , Step
    , StepNumber
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
    , defaultEnableRepositoryPayload
    , defaultSecret
    , defaultStep
    , enableRepoList
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


buildUpdateFavoritesPayload : List String -> UpdateUserPayload
buildUpdateFavoritesPayload value =
    { defaultUpdateUserPayload | favorites = Just value }



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
    , allow_events : Maybe AllowEvents
    , enabled : Enabled
    , enabling : Enabling
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
        |> optional "allow_events" (Json.Decode.maybe decodeAllowEvents) Nothing
        -- "enabled"
        |> optional "active" enabledDecoder RemoteData.NotAsked
        -- "enabling"
        |> optional "active" enablingDecoder NotAsked_
        |> optional "pipeline_type" string ""


decodeRepositories : Decoder (List Repository)
decodeRepositories =
    Json.Decode.list decodeRepository


type Enabling
    = ConfirmDisable
    | Disabling
    | Disabled
    | Enabling
    | Enabled
    | NotAsked_


type alias Enabled =
    WebData Bool


enabledDecoder : Decoder Enabled
enabledDecoder =
    bool |> andThen toEnabled


toEnabled : Bool -> Decoder Enabled
toEnabled active =
    if active then
        succeed <| RemoteData.succeed True

    else
        succeed RemoteData.NotAsked


enablingDecoder : Decoder Enabling
enablingDecoder =
    bool |> andThen toEnabling


toEnabling : Bool -> Decoder Enabling
toEnabling active =
    if active then
        succeed Enabled

    else
        succeed Disabled


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


type alias AllowEvents =
    { push : PushActions
    , pull : PullActions
    , deploy : DeployActions
    , comment : CommentActions
    }


type alias AllowEventsPayload =
    { push : PushActionsPayload
    , pull : PullActionsPayload
    , deploy : DeployActionsPayload
    , comment : CommentActionsPayload
    }


type alias PushActionsPayload =
    { branch : Bool
    , tag : Bool
    }


type alias PullActionsPayload =
    { opened : Bool
    , synchronize : Bool
    , edited : Bool
    , reopened : Bool
    }


type alias DeployActionsPayload =
    { created : Bool
    }


type alias CommentActionsPayload =
    { created : Bool
    , edited : Bool
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


decodeAllowEvents : Decoder AllowEvents
decodeAllowEvents =
    Json.Decode.succeed AllowEvents
        |> required "push" decodePushActions
        |> required "pull_request" decodePullActions
        |> required "deployment" decodeDeployActions
        |> required "comment" decodeCommentActions


encodeAllowEvents : AllowEventsPayload -> Json.Encode.Value
encodeAllowEvents events =
    Json.Encode.object
        [ ( "push", encodePushActions events.push )
        , ( "pull_request", encodePullActions events.pull )
        , ( "deployment", encodeDeployActions events.deploy )
        , ( "comment", encodeCommentActions events.comment )
        ]


encodePushActions : PushActionsPayload -> Json.Encode.Value
encodePushActions push =
    Json.Encode.object
        [ ( "branch", Json.Encode.bool <| push.branch )
        , ( "tag", Json.Encode.bool <| push.tag )
        ]


encodePullActions : PullActionsPayload -> Json.Encode.Value
encodePullActions pull =
    Json.Encode.object
        [ ( "opened", Json.Encode.bool <| pull.opened )
        , ( "synchronize", Json.Encode.bool <| pull.synchronize )
        , ( "edited", Json.Encode.bool <| pull.edited )
        , ( "reopened", Json.Encode.bool <| pull.reopened )
        ]


encodeDeployActions : DeployActionsPayload -> Json.Encode.Value
encodeDeployActions deploy =
    Json.Encode.object
        [ ( "created", Json.Encode.bool <| deploy.created )
        ]


encodeCommentActions : CommentActionsPayload -> Json.Encode.Value
encodeCommentActions comment =
    Json.Encode.object
        [ ( "created", Json.Encode.bool <| comment.created )
        , ( "edited", Json.Encode.bool <| comment.edited )
        ]


type alias SourceRepositories =
    Dict String (List Repository)


buildEnableRepositoryPayload : Repository -> EnableRepositoryPayload
buildEnableRepositoryPayload repo =
    EnableRepositoryPayload repo.org repo.name repo.full_name repo.link repo.clone repo.private repo.trusted repo.active repo.allow_pull repo.allow_push repo.allow_deploy repo.allow_tag repo.allow_comment repo.allow_events


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
        , ( "allow_events", encodeOptional encodeAllowEvents repo.allow_events )
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
    List.map
        (\sourceRepo ->
            if sourceRepo.name == repo.name then
                { sourceRepo | enabled = status }

            else
                sourceRepo
        )
        orgRepos


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
    , allow_events : Maybe AllowEventsPayload
    }


defaultEnableRepositoryPayload : EnableRepositoryPayload
defaultEnableRepositoryPayload =
    EnableRepositoryPayload "" "" "" "" "" False False True False False False False False Nothing


type alias UpdateRepositoryPayload =
    { private : Maybe Bool
    , trusted : Maybe Bool
    , active : Maybe Bool
    , allow_pull : Maybe Bool
    , allow_push : Maybe Bool
    , allow_deploy : Maybe Bool
    , allow_tag : Maybe Bool
    , allow_comment : Maybe Bool
    , allow_events : Maybe AllowEventsPayload
    , visibility : Maybe String
    , approve_build : Maybe String
    , limit : Maybe Int
    , timeout : Maybe Int
    , counter : Maybe Int
    , pipeline_type : Maybe String
    }


defaultUpdateRepositoryPayload : UpdateRepositoryPayload
defaultUpdateRepositoryPayload =
    UpdateRepositoryPayload Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing


defaultAllowEventsPayload : Repository -> AllowEventsPayload
defaultAllowEventsPayload repository =
    case repository.allow_events of
        Nothing ->
            AllowEventsPayload (defaultPushActionsPayload Nothing) (defaultPullActionsPayload Nothing) (defaultDeployActionsPayload Nothing) (defaultCommentActionsPayload Nothing)

        Just events ->
            AllowEventsPayload (defaultPushActionsPayload (Just events.push)) (defaultPullActionsPayload (Just events.pull)) (defaultDeployActionsPayload (Just events.deploy)) (defaultCommentActionsPayload (Just events.comment))


defaultPushActionsPayload : Maybe PushActions -> PushActionsPayload
defaultPushActionsPayload pushActions =
    case pushActions of
        Nothing ->
            PushActionsPayload False False

        Just push ->
            PushActionsPayload push.branch push.tag


defaultPullActionsPayload : Maybe PullActions -> PullActionsPayload
defaultPullActionsPayload pullActions =
    case pullActions of
        Nothing ->
            PullActionsPayload False False False False

        Just pull ->
            PullActionsPayload pull.opened pull.synchronize pull.edited pull.reopened


defaultDeployActionsPayload : Maybe DeployActions -> DeployActionsPayload
defaultDeployActionsPayload deployActions =
    case deployActions of
        Nothing ->
            DeployActionsPayload False

        Just deploy ->
            DeployActionsPayload deploy.created


defaultCommentActionsPayload : Maybe CommentActions -> CommentActionsPayload
defaultCommentActionsPayload commentActions =
    case commentActions of
        Nothing ->
            CommentActionsPayload False False

        Just comment ->
            CommentActionsPayload comment.created comment.edited


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
        , ( "allow_events", encodeOptional encodeAllowEvents repo.allow_events )
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


buildUpdateRepoEventsPayload : Repository -> String -> Bool -> UpdateRepositoryPayload
buildUpdateRepoEventsPayload repository field value =
    let
        events =
            defaultAllowEventsPayload repository

        pushActions =
            events.push

        pullActions =
            events.pull

        deployActions =
            events.deploy

        commentActions =
            events.comment
    in
    case field of
        "allow_push_branch" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | push = { pushActions | branch = value } } }

        "allow_push_tag" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | push = { pushActions | tag = value } } }

        "allow_pull_opened" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | pull = { pullActions | opened = value } } }

        "allow_pull_synchronize" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | pull = { pullActions | synchronize = value } } }

        "allow_pull_edited" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | pull = { pullActions | edited = value } } }

        "allow_pull_reopened" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | pull = { pullActions | reopened = value } } }

        "allow_deploy_created" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | deploy = { deployActions | created = value } } }

        "allow_comment_created" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | comment = { commentActions | created = value } } }

        "allow_comment_edited" ->
            { defaultUpdateRepositoryPayload | allow_events = Just { events | comment = { commentActions | edited = value } } }

        _ ->
            defaultUpdateRepositoryPayload


buildUpdateRepoBoolPayload : String -> Bool -> UpdateRepositoryPayload
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


buildUpdateRepoStringPayload : String -> String -> UpdateRepositoryPayload
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


buildUpdateRepoIntPayload : String -> Int -> UpdateRepositoryPayload
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
    }


defaultStep : Step
defaultStep =
    Step 0 0 0 0 "" "" Pending "" 0 0 0 0 "" "" "" "" False


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


newStepLog : Int -> Log
newStepLog id =
    Log id -1 -1 -1 -1 "" "" -1


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


decodeSchedules : Decoder (List Schedule)
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


secretsErrorLabel : SecretType -> Org -> Maybe Key -> String
secretsErrorLabel type_ org key =
    case type_ of
        OrgSecret ->
            "org secrets for " ++ org

        RepoSecret ->
            "repo secrets for " ++ org ++ "/" ++ Maybe.withDefault "" key

        SharedSecret ->
            "shared secrets for " ++ org ++ "/" ++ Maybe.withDefault "" key


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


decodeDeploymentParameters : Decoder (Maybe (List KeyValuePair))
decodeDeploymentParameters =
    Json.Decode.map decodeKeyValuePairs <| Json.Decode.keyValuePairs Json.Decode.string
