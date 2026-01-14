{--
SPDX-License-Identifier: Apache-2.0
--}


module Vela exposing
    ( AllowEvents
    , AllowEventsField(..)
    , Artifact
    , Build
    , BuildGraph
    , BuildGraphEdge
    , BuildGraphInteraction
    , BuildGraphNode
    , BuildNumber
    , ConfigParameterType(..)
    , Dashboard
    , DashboardRepoCard
    , Deployment
    , DeploymentConfig
    , DeploymentConfigParameter
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
    , PlatformSettings
    , PlatformSettingsFieldUpdate(..)
    , Ref
    , Repo
    , RepoFieldUpdate(..)
    , RepoFieldUpdateResponseConfig
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
    , User
    , Worker
    , allowEventsFilterQueryKeys
    , allowEventsToList
    , buildRepoPayload
    , decodeArtifacts
    , decodeBuild
    , decodeBuildGraph
    , decodeBuilds
    , decodeDashboard
    , decodeDashboards
    , decodeDeployment
    , decodeDeploymentConfig
    , decodeDeploymentConfigParameter
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
    , decodeSettings
    , decodeSourceRepositories
    , decodeStep
    , decodeSteps
    , decodeUser
    , decodeWorkers
    , defaultAllowEvents
    , defaultCompilerPayload
    , defaultDeploymentPayload
    , defaultEnabledAllowEvents
    , defaultPipelineConfig
    , defaultQueuePayload
    , defaultRepoPayload
    , defaultSchedulePayload
    , defaultSecretPayload
    , defaultSettingsPayload
    , defaultUpdateUserPayload
    , enableUpdate
    , encodeBuildGraphRenderData
    , encodeDeploymentPayload
    , encodeEnableRepository
    , encodeRepoPayload
    , encodeSchedulePayload
    , encodeSecretPayload
    , encodeSettingsPayload
    , encodeUpdateUser
    , getAllowEventField
    , platformSettingsFieldUpdateToResponseConfig
    , repoFieldUpdateToResponseConfig
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
import Utils.Warnings as Warnings



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



-- DASHBOARD


type alias Dashboard =
    { dashboard : DashboardItem
    , repos : List DashboardRepoCard
    }


type alias DashboardItem =
    { id : String
    , name : String
    , created_at : Int
    , created_by : String
    , updated_at : Int
    , updated_by : String
    , admins : List User
    , repos : List DashboardRepo
    }


type alias DashboardRepo =
    { id : Int
    , name : String
    , branches : List String
    , events : List String
    }


type alias DashboardRepoCard =
    { org : String
    , name : String
    , counter : Int
    , active : Bool
    , builds : List Build
    }


decodeDashboard : Decoder Dashboard
decodeDashboard =
    Json.Decode.succeed Dashboard
        |> optional "dashboard" decodeDashboardItem (DashboardItem "" "" 0 "" 0 "" [] [])
        |> optional "repos" (Json.Decode.list decodeDashboardRepoCard) []


decodeDashboards : Decoder (List Dashboard)
decodeDashboards =
    Json.Decode.list decodeDashboard


decodeDashboardItem : Decoder DashboardItem
decodeDashboardItem =
    Json.Decode.succeed DashboardItem
        |> optional "id" string ""
        |> optional "name" string ""
        |> optional "created_at" int -1
        |> optional "created_by" string ""
        |> optional "updated_at" int -1
        |> optional "updated_by" string ""
        |> optional "admins" (Json.Decode.list decodeUser) []
        |> optional "repos" (Json.Decode.list decodeDashboardRepo) []


decodeDashboardRepoCard : Decoder DashboardRepoCard
decodeDashboardRepoCard =
    Json.Decode.succeed DashboardRepoCard
        |> optional "org" string ""
        |> optional "name" string ""
        |> optional "counter" int -1
        |> optional "active" bool False
        |> optional "builds" (Json.Decode.list decodeBuild) []


decodeDashboardRepo : Decoder DashboardRepo
decodeDashboardRepo =
    Json.Decode.succeed DashboardRepo
        |> optional "id" int -1
        |> optional "name" string ""
        |> optional "branches" (Json.Decode.list string) []
        |> optional "events" (Json.Decode.list string) []



-- ARTIFACT
--
-- this database stuff is just informational
--
-- database types in server:
--
-- type Artifact struct {
-- 	ID           sql.NullInt64  `sql:"id"`
-- 	BuildID      sql.NullInt64  `sql:"build_id"`
-- 	FileName     sql.NullString `sql:"file_name"`
-- 	ObjectPath   sql.NullString `sql:"object_path"`
-- 	FileSize     sql.NullInt64  `sql:"file_size"`
-- 	FileType     sql.NullString `sql:"file_type"`
-- 	PresignedUrl sql.NullString `sql:"presigned_url"`
-- 	CreatedAt    sql.NullInt64  `sql:"created_at"`
-- 	// References to related objects
-- 	Build *Build `gorm:"foreignKey:BuildID"`
-- }


type alias Artifact =
    { id : Int
    , build_id : Int
    , file_name : String
    , object_path : String
    , file_size : Int
    , file_type : String
    , presigned_url : String
    , created_at : Int
    }


decodeArtifacts : Decoder (List Artifact)
decodeArtifacts =
    Json.Decode.oneOf
        [ Json.Decode.list decodeArtifact
        , Json.Decode.null []
        ]


decodeArtifact : Decoder Artifact
decodeArtifact =
    Json.Decode.succeed Artifact
        |> optional "id" int -1
        |> optional "build_id" int -1
        |> optional "file_name" string ""
        |> optional "object_path" string ""
        |> optional "file_size" int 0
        |> optional "file_type" string ""
        |> optional "presigned_url" string ""
        |> optional "created_at" int -1



-- USER


type alias User =
    { id : Int
    , name : String
    , favorites : List String
    , dashboards : List String
    , active : Bool
    , admin : Bool
    }


decodeUser : Decoder User
decodeUser =
    Json.Decode.succeed User
        |> required "id" int
        |> optional "name" string ""
        |> optional "favorites" (Json.Decode.list string) []
        |> optional "dashboards" (Json.Decode.list string) []
        |> optional "active" bool False
        |> optional "admin" bool False


emptyUser : User
emptyUser =
    { id = -1, name = "", favorites = [], dashboards = [], active = False, admin = False }


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


buildRepoPayload : Repository -> EnableRepoPayload
buildRepoPayload repo =
    EnableRepoPayload
        repo.org
        repo.name
        repo.full_name
        repo.link
        repo.clone
        repo.private
        repo.trusted
        repo.active
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
    , owner : User
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
    , allowEvents : AllowEvents
    , enabled : Enabled
    , pipeline_type : String
    , approval_timeout : Int
    }


emptyRepository : Repository
emptyRepository =
    { id = -1
    , user_id = -1
    , owner = emptyUser
    , org = ""
    , name = ""
    , full_name = ""
    , link = ""
    , clone = ""
    , branch = ""
    , limit = 0
    , timeout = 0
    , counter = 0
    , visibility = ""
    , approve_build = ""
    , private = False
    , trusted = False
    , active = False
    , allowEvents = defaultAllowEvents
    , enabled = Disabled
    , pipeline_type = ""
    , approval_timeout = 0
    }


decodeRepository : Decoder Repository
decodeRepository =
    Json.Decode.succeed Repository
        |> optional "id" int -1
        |> optional "user_id" int -1
        |> optional "owner" decodeUser emptyUser
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
        |> optional "allow_events" decodeAllowEvents defaultAllowEvents
        -- "enabled"
        |> optional "active" enabledDecoder Disabled
        |> optional "pipeline_type" string ""
        |> optional "approval_timeout" int 0


decodeRepositories : Decoder (List Repository)
decodeRepositories =
    Json.Decode.list decodeRepository



-- REPO UPDATES


type alias RepoPayload =
    { private : Maybe Bool
    , trusted : Maybe Bool
    , active : Maybe Bool
    , allowEvents : Maybe AllowEvents
    , visibility : Maybe String
    , approve_build : Maybe String
    , limit : Maybe Int
    , timeout : Maybe Int
    , counter : Maybe Int
    , pipeline_type : Maybe String
    , approval_timeout : Maybe Int
    }


encodeRepoPayload : RepoPayload -> Json.Encode.Value
encodeRepoPayload repo =
    Json.Encode.object
        [ ( "active", encodeOptional Json.Encode.bool repo.active )
        , ( "private", encodeOptional Json.Encode.bool repo.private )
        , ( "trusted", encodeOptional Json.Encode.bool repo.trusted )
        , ( "allow_events", encodeOptional encodeAllowEvents repo.allowEvents )
        , ( "visibility", encodeOptional Json.Encode.string repo.visibility )
        , ( "approve_build", encodeOptional Json.Encode.string repo.approve_build )
        , ( "build_limit", encodeOptional Json.Encode.int repo.limit )
        , ( "timeout", encodeOptional Json.Encode.int repo.timeout )
        , ( "counter", encodeOptional Json.Encode.int repo.counter )
        , ( "pipeline_type", encodeOptional Json.Encode.string repo.pipeline_type )
        , ( "approval_timeout", encodeOptional Json.Encode.int repo.approval_timeout )
        ]


defaultRepoPayload : RepoPayload
defaultRepoPayload =
    { private = Nothing
    , trusted = Nothing
    , active = Nothing
    , allowEvents = Nothing
    , visibility = Nothing
    , approve_build = Nothing
    , limit = Nothing
    , timeout = Nothing
    , counter = Nothing
    , pipeline_type = Nothing
    , approval_timeout = Nothing
    }


type RepoFieldUpdate
    = Private
    | Trusted
    | AllowEvents_ AllowEventsField
    | Visibility
    | ApproveBuild
    | Limit
    | Timeout
    | Counter
    | PipelineType
    | ApprovalTimeout


type alias RepoFieldUpdateResponseConfig =
    { successAlert : Repository -> String
    }


repoFieldUpdateToResponseConfig : RepoFieldUpdate -> RepoFieldUpdateResponseConfig
repoFieldUpdateToResponseConfig field =
    -- apply generic transformations to the repo update
    (\update ->
        { update
          -- replace $ with repo.full_name
            | successAlert = \repo -> update.successAlert repo |> String.replace "$" repo.full_name
        }
    )
    <|
        case field of
            Private ->
                { successAlert =
                    \repo ->
                        "$ privacy set to '"
                            ++ (if repo.private then
                                    "private"

                                else
                                    "any"
                               )
                            ++ "'."
                }

            Trusted ->
                { successAlert =
                    \repo ->
                        "$ set to '"
                            ++ (if repo.trusted then
                                    "trusted"

                                else
                                    "untrusted"
                               )
                            ++ "'."
                }

            AllowEvents_ event ->
                { successAlert =
                    \repo ->
                        let
                            prefix =
                                case event of
                                    PullOpened ->
                                        "Pull opened events for $ "

                                    PullSynchronize ->
                                        "Pull synchronize events for $ "

                                    PullEdited ->
                                        "Pull edited events for $ "

                                    PullReopened ->
                                        "Pull reopened events for $ "

                                    PullLabeled ->
                                        "Pull labeled events for $ "

                                    PullUnlabeled ->
                                        "Pull unlabeled events for $ "

                                    PushBranch ->
                                        "Push branch events for $ "

                                    PushTag ->
                                        "Push tag events for $ "

                                    PushDeleteBranch ->
                                        "Push delete branch events for $ "

                                    PushDeleteTag ->
                                        "Push delete tag events for $ "

                                    DeployCreated ->
                                        "Deploy events for $ "

                                    CommentCreated ->
                                        "Comment created events for $ "

                                    CommentEdited ->
                                        "Comment edited events for $ "

                                    ScheduleRun ->
                                        "Schedule run event for $ "
                        in
                        prefix
                            ++ (if getAllowEventField event repo.allowEvents then
                                    "enabled"

                                else
                                    "disabled"
                               )
                            ++ "."
                }

            Visibility ->
                { successAlert =
                    \repo ->
                        "$ visibility set to '" ++ repo.visibility ++ "'."
                }

            ApproveBuild ->
                { successAlert =
                    \repo ->
                        "$ build approval policy set to '" ++ repo.approve_build ++ "'."
                }

            Limit ->
                { successAlert =
                    \repo ->
                        "$ maximum concurrent build limit set to '" ++ String.fromInt repo.limit ++ "'."
                }

            Timeout ->
                { successAlert =
                    \repo ->
                        "$ maximum build runtime set to " ++ String.fromInt repo.timeout ++ " minute(s)."
                }

            Counter ->
                { successAlert =
                    \repo ->
                        "$ build counter set to " ++ String.fromInt repo.counter ++ "."
                }

            PipelineType ->
                { successAlert =
                    \repo ->
                        "$ pipeline syntax type set to '" ++ repo.pipeline_type ++ "'."
                }

            ApprovalTimeout ->
                { successAlert =
                    \repo ->
                        "$ build approval timeout set to " ++ String.fromInt repo.approval_timeout ++ " day(s)."
                }



-- ALLOW EVENTS


type alias AllowEvents =
    { push : PushActions
    , pull : PullActions
    , deploy : DeployActions
    , comment : CommentActions
    , schedule : ScheduleActions
    }


type alias PushActions =
    { branch : Bool
    , tag : Bool
    , deleteBranch : Bool
    , deleteTag : Bool
    }


type alias PullActions =
    { opened : Bool
    , synchronize : Bool
    , edited : Bool
    , reopened : Bool
    , labeled : Bool
    , unlabeled : Bool
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


defaultAllowEvents : AllowEvents
defaultAllowEvents =
    { push =
        { branch = False
        , tag = False
        , deleteBranch = False
        , deleteTag = False
        }
    , pull =
        { opened = False
        , synchronize = False
        , edited = False
        , reopened = False
        , labeled = False
        , unlabeled = False
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


defaultEnabledAllowEvents : AllowEvents
defaultEnabledAllowEvents =
    { push =
        { branch = True
        , tag = True
        , deleteBranch = False
        , deleteTag = False
        }
    , pull =
        { opened = False
        , synchronize = False
        , edited = False
        , reopened = False
        , labeled = False
        , unlabeled = False
        }
    , deploy =
        { created = True
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
        |> required "delete_branch" bool
        |> required "delete_tag" bool


decodePullActions : Decoder PullActions
decodePullActions =
    Json.Decode.succeed PullActions
        |> required "opened" bool
        |> required "synchronize" bool
        |> required "edited" bool
        |> required "reopened" bool
        |> optional "labeled" bool False
        |> optional "unlabeled" bool False


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
        , ( "delete_branch", Json.Encode.bool <| push.deleteBranch )
        , ( "delete_tag", Json.Encode.bool <| push.deleteTag )
        ]


encodePullActions : PullActions -> Json.Encode.Value
encodePullActions pull =
    Json.Encode.object
        [ ( "opened", Json.Encode.bool <| pull.opened )
        , ( "synchronize", Json.Encode.bool <| pull.synchronize )
        , ( "edited", Json.Encode.bool <| pull.edited )
        , ( "reopened", Json.Encode.bool <| pull.reopened )
        , ( "labeled", Json.Encode.bool <| pull.labeled )
        , ( "unlabeled", Json.Encode.bool <| pull.unlabeled )
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


type AllowEventsField
    = PullOpened
    | PullSynchronize
    | PullEdited
    | PullReopened
    | PullLabeled
    | PullUnlabeled
    | PushBranch
    | PushTag
    | PushDeleteBranch
    | PushDeleteTag
    | DeployCreated
    | CommentCreated
    | CommentEdited
    | ScheduleRun


setAllowEvents :
    { a | allowEvents : AllowEvents }
    -> AllowEventsField
    -> Bool
    -> { a | allowEvents : AllowEvents }
setAllowEvents payload field val =
    let
        events =
            payload.allowEvents

        { push, pull, deploy, comment, schedule } =
            events
    in
    case field of
        PushBranch ->
            { payload
                | allowEvents = { events | push = { push | branch = val } }
            }

        PushTag ->
            { payload
                | allowEvents = { events | push = { push | tag = val } }
            }

        PushDeleteBranch ->
            { payload
                | allowEvents = { events | push = { push | deleteBranch = val } }
            }

        PushDeleteTag ->
            { payload
                | allowEvents = { events | push = { push | deleteTag = val } }
            }

        PullOpened ->
            { payload
                | allowEvents = { events | pull = { pull | opened = val } }
            }

        PullSynchronize ->
            { payload
                | allowEvents = { events | pull = { pull | synchronize = val } }
            }

        PullEdited ->
            { payload
                | allowEvents = { events | pull = { pull | edited = val } }
            }

        PullReopened ->
            { payload
                | allowEvents = { events | pull = { pull | reopened = val } }
            }

        PullLabeled ->
            { payload
                | allowEvents = { events | pull = { pull | labeled = val } }
            }

        PullUnlabeled ->
            { payload
                | allowEvents = { events | pull = { pull | unlabeled = val } }
            }

        DeployCreated ->
            { payload
                | allowEvents = { events | deploy = { deploy | created = val } }
            }

        CommentCreated ->
            { payload
                | allowEvents = { events | comment = { comment | created = val } }
            }

        CommentEdited ->
            { payload
                | allowEvents = { events | comment = { comment | edited = val } }
            }

        ScheduleRun ->
            { payload
                | allowEvents = { events | schedule = { schedule | run = val } }
            }


getAllowEventField :
    AllowEventsField
    -> AllowEvents
    -> Bool
getAllowEventField field events =
    case field of
        PushBranch ->
            events.push.branch

        PushTag ->
            events.push.tag

        PushDeleteBranch ->
            events.push.deleteBranch

        PushDeleteTag ->
            events.push.deleteTag

        PullOpened ->
            events.pull.opened

        PullSynchronize ->
            events.pull.synchronize

        PullEdited ->
            events.pull.edited

        PullReopened ->
            events.pull.reopened

        PullLabeled ->
            events.pull.labeled

        PullUnlabeled ->
            events.pull.unlabeled

        DeployCreated ->
            events.deploy.created

        CommentCreated ->
            events.comment.created

        CommentEdited ->
            events.comment.edited

        ScheduleRun ->
            events.schedule.run


allowEventsToList : AllowEvents -> List ( Bool, String )
allowEventsToList events =
    [ ( events.push.branch, "push" )
    , ( events.push.tag, "tag" )
    , ( events.push.deleteBranch, "delete:branch" )
    , ( events.push.deleteTag, "delete:tag" )
    , ( events.pull.opened, "pull_request:opened" )
    , ( events.pull.synchronize, "pull_request:synchronize" )
    , ( events.pull.edited, "pull_request:edited" )
    , ( events.pull.reopened, "pull_request:reopened" )
    , ( events.pull.labeled, "pull_request:labeled" )
    , ( events.pull.unlabeled, "pull_request:unlabeled" )
    , ( events.deploy.created, "deployment" )
    , ( events.comment.created, "comment:created" )
    , ( events.comment.edited, "comment:edited" )
    , ( events.schedule.run, "schedule" )
    ]


allowEventsFilterQueryKeys : List String
allowEventsFilterQueryKeys =
    [ "all"
    , "push"
    , "pull_request"
    , "tag"
    , "deployment"
    , "schedule"
    , "comment"
    , "delete"
    ]



-- PIPELINE


type alias PipelineConfig =
    { commit : String
    , flavor : String
    , platform : String
    , ref : String
    , type_ : String
    , version : String
    , externalSecrets : Bool
    , internalSecrets : Bool
    , services : Bool
    , stages : Bool
    , steps : Bool
    , templates : Bool
    , warnings : List String

    -- decoded values
    , rawData : String
    , decodedData : String
    , lineWarnings : Dict Int (List String)
    }


defaultPipelineConfig : PipelineConfig
defaultPipelineConfig =
    PipelineConfig "" "" "" "" "" "" False False False False False False [] "" "" Dict.empty


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
        PipelineConfig
        |> optional "commit" string ""
        |> optional "flavor" string ""
        |> optional "platform" string ""
        |> optional "ref" string ""
        |> optional "type" string ""
        |> optional "version" string ""
        |> optional "external_secrets" bool False
        |> optional "internal_secrets" bool False
        |> optional "services" bool False
        |> optional "stages" bool False
        |> optional "steps" bool False
        |> optional "templates" bool False
        |> optional "warnings" (Json.Decode.list string) []
        |> optional "data" string ""
        |> optional "decodedData" string ""
        |> optional "warnings"
            (Json.Decode.list string
                |> Json.Decode.andThen
                    decodeAndCollapsePipelineWarnings
            )
            Dict.empty


decodeAndCollapsePipelineWarnings : List String -> Json.Decode.Decoder (Dict Int (List String))
decodeAndCollapsePipelineWarnings warnings =
    Json.Decode.succeed
        (List.foldl
            (\warning dict ->
                let
                    { maybeLineNumber, content } =
                        Warnings.fromString warning
                in
                case ( maybeLineNumber, content ) of
                    ( Just line, w ) ->
                        Dict.update line
                            (\maybeWarnings ->
                                case maybeWarnings of
                                    Just existingWarnings ->
                                        Just (w :: existingWarnings)

                                    Nothing ->
                                        Just [ w ]
                            )
                            dict

                    _ ->
                        dict
            )
            Dict.empty
            warnings
        )


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
    , route : String
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
        |> optional "route" string ""
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
    , build : Int
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
    , repo : Repository
    , name : String
    , entry : String
    , enabled : Bool
    , created_at : Int
    , created_by : String
    , scheduled_at : Int
    , updated_at : Int
    , updated_by : String
    , branch : String
    , error : String
    , next_run : Int
    }


type alias SchedulePayload =
    { org : Maybe Org
    , repo : Maybe Repo
    , name : Maybe Name
    , entry : Maybe String
    , enabled : Maybe Bool
    , branch : Maybe String
    , error : Maybe String
    }


defaultSchedulePayload : SchedulePayload
defaultSchedulePayload =
    { org = Nothing
    , repo = Nothing
    , name = Nothing
    , entry = Nothing
    , enabled = Nothing
    , branch = Nothing
    , error = Nothing
    }


decodeSchedule : Decoder Schedule
decodeSchedule =
    Json.Decode.succeed Schedule
        |> optional "id" int -1
        |> optional "repo" decodeRepository emptyRepository
        |> optional "name" string ""
        |> optional "entry" string ""
        |> optional "active" bool False
        |> optional "created_at" int 0
        |> optional "created_by" string ""
        |> optional "scheduled_at" int 0
        |> optional "updated_at" int 0
        |> optional "updated_by" string ""
        |> optional "branch" string ""
        |> optional "error" string ""
        |> optional "next_run" int 0


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
    , allowCommand : Bool
    , allowSubstitution : Bool
    , allowEvents : AllowEvents
    , repoAllowlist : List String
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
        |> optional "allow_command" bool False
        |> optional "allow_substitution" bool False
        |> optional "allow_events" decodeAllowEvents defaultAllowEvents
        |> optional "repo_allowlist" (Json.Decode.list string) []


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
    , images : Maybe (List String)
    , allowCommand : Maybe Bool
    , allowSubstitution : Maybe Bool
    , allowEvents : Maybe AllowEvents
    , repoAllowlist : Maybe (List String)
    }


defaultSecretPayload : SecretPayload
defaultSecretPayload =
    { type_ = Nothing
    , org = Nothing
    , repo = Nothing
    , team = Nothing
    , name = Nothing
    , value = Nothing
    , images = Nothing
    , allowCommand = Nothing
    , allowSubstitution = Nothing
    , allowEvents = Nothing
    , repoAllowlist = Nothing
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
        , ( "allow_substitution", encodeOptional Json.Encode.bool secret.allowSubstitution )
        , ( "allow_events", encodeOptional encodeAllowEvents secret.allowEvents )
        , ( "repo_allowlist", encodeOptionalList Json.Encode.string secret.repoAllowlist )
        ]



-- DEPLOYMENT


type alias Deployment =
    { id : Int
    , number : Int
    , repo : Repository
    , url : String
    , created_by : String
    , created_at : Int
    , commit : String
    , ref : String
    , task : String
    , target : String
    , description : String
    , payload : Maybe (List KeyValuePair)
    , builds : List Build
    }


decodeDeployment : Decoder Deployment
decodeDeployment =
    Json.Decode.succeed Deployment
        |> optional "id" int -1
        |> optional "number" int -1
        |> optional "repo" decodeRepository emptyRepository
        |> optional "url" string ""
        |> optional "created_by" string ""
        |> optional "created_at" int 0
        |> optional "commit" string ""
        |> optional "ref" string ""
        |> optional "task" string ""
        |> optional "target" string ""
        |> optional "description" string ""
        |> optional "payload" decodeDeploymentParameters Nothing
        |> optional "builds" decodeBuilds []


decodeDeployments : Decoder (List Deployment)
decodeDeployments =
    Json.Decode.list decodeDeployment


type alias DeploymentPayload =
    { org : Maybe String
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



-- DEPLOYMENT CONFIG


type alias DeploymentConfig =
    { targets : List String
    , parameters : Dict String DeploymentConfigParameter
    }


decodeDeploymentConfig : Decoder DeploymentConfig
decodeDeploymentConfig =
    Json.Decode.succeed DeploymentConfig
        |> optional "targets" (Json.Decode.list Json.Decode.string) []
        |> optional "parameters" (Json.Decode.dict decodeDeploymentConfigParameter) Dict.empty


type ConfigParameterType
    = String_
    | Int_
    | Bool_


deployConfigTypeDecoder : Decoder ConfigParameterType
deployConfigTypeDecoder =
    string |> andThen toDeployConfigTypeDecoder


toDeployConfigTypeDecoder : String -> Decoder ConfigParameterType
toDeployConfigTypeDecoder type_ =
    case type_ of
        "integer" ->
            succeed Int_

        "int" ->
            succeed Int_

        "number" ->
            succeed Int_

        "boolean" ->
            succeed Bool_

        "bool" ->
            succeed Bool_

        "string" ->
            succeed String_

        _ ->
            Json.Decode.fail "unrecognized secret type"


type alias DeploymentConfigParameter =
    { description : String
    , type_ : ConfigParameterType
    , required : Bool
    , options : List String
    , min : Int
    , max : Int
    }


decodeDeploymentConfigParameter : Decoder DeploymentConfigParameter
decodeDeploymentConfigParameter =
    Json.Decode.succeed DeploymentConfigParameter
        |> optional "description" string ""
        |> optional "type" deployConfigTypeDecoder String_
        |> optional "required" bool False
        |> optional "options" (Json.Decode.list Json.Decode.string) []
        |> optional "min" int 0
        |> optional "max" int 0


type alias Worker =
    { id : Int
    , host_name : String
    , address : String
    , routes : List String
    , active : Bool
    , status : String
    , last_status_update : Int
    , running_builds : List Build
    , last_build_started : Int
    , last_build_finished : Int
    , last_checked_in : Int
    , build_limit : Int
    }


decodeWorker : Decoder Worker
decodeWorker =
    Json.Decode.succeed Worker
        |> optional "id" int -1
        |> required "hostname" string
        |> required "address" string
        |> optional "routes" (Json.Decode.list string) []
        |> optional "active" bool False
        |> optional "status" string ""
        |> optional "last_status_update_at" int -1
        |> optional "running_builds" decodeBuilds []
        |> optional "last_build_started_at" int -1
        |> optional "last_build_finished_at" int -1
        |> optional "last_checked_in" int -1
        |> optional "build_limit" int -1


decodeWorkers : Decoder (List Worker)
decodeWorkers =
    Json.Decode.list decodeWorker


type alias PlatformSettings =
    { id : Int
    , compiler : Compiler
    , queue : Queue
    , repoAllowlist : List String
    , scheduleAllowlist : List String
    , maxDashboardRepos : Int
    , queueRestartLimit : Int
    , createdAt : Int
    , updatedAt : Int
    , updatedBy : String
    }


decodeSettings : Decoder PlatformSettings
decodeSettings =
    Json.Decode.succeed PlatformSettings
        |> optional "id" int -1
        |> required "compiler" decodeCompiler
        |> required "queue" decodeQueue
        |> required "repo_allowlist" (Json.Decode.list Json.Decode.string)
        |> required "schedule_allowlist" (Json.Decode.list Json.Decode.string)
        |> required "max_dashboard_repos" int
        |> required "queue_restart_limit" int
        |> required "created_at" int
        |> required "updated_at" int
        |> required "updated_by" string


type alias Compiler =
    { cloneImage : String
    , templateDepth : Int
    , starlarkExecLimit : Int
    }


decodeCompiler : Decoder Compiler
decodeCompiler =
    Json.Decode.succeed Compiler
        |> optional "clone_image" string ""
        |> optional "template_depth" int -1
        |> optional "starlark_exec_limit" int -1


type alias CompilerPayload =
    { cloneImage : Maybe String
    , templateDepth : Maybe Int
    , starlarkExecLimit : Maybe Int
    }


defaultCompilerPayload : CompilerPayload
defaultCompilerPayload =
    { cloneImage = Nothing
    , templateDepth = Nothing
    , starlarkExecLimit = Nothing
    }


encodeCompilerPayload : CompilerPayload -> Json.Encode.Value
encodeCompilerPayload compiler =
    Json.Encode.object
        [ ( "clone_image", encodeOptional Json.Encode.string compiler.cloneImage )
        , ( "template_depth", encodeOptional Json.Encode.int compiler.templateDepth )
        , ( "starlark_exec_limit", encodeOptional Json.Encode.int compiler.starlarkExecLimit )
        ]


type alias Queue =
    { routes : List String
    }


decodeQueue : Decoder Queue
decodeQueue =
    Json.Decode.succeed Queue
        |> optional "routes" (Json.Decode.list Json.Decode.string) []


type alias QueuePayload =
    { routes : Maybe (List String)
    }


defaultQueuePayload : QueuePayload
defaultQueuePayload =
    { routes = Nothing
    }


encodeQueuePayload : QueuePayload -> Json.Encode.Value
encodeQueuePayload queue =
    Json.Encode.object
        [ ( "routes", encodeOptional (Json.Encode.list Json.Encode.string) queue.routes )
        ]


type alias SettingsPayload =
    { compiler : Maybe CompilerPayload
    , queue : Maybe QueuePayload
    , repoAllowlist : Maybe (List String)
    , scheduleAllowlist : Maybe (List String)
    , maxDashboardRepos : Maybe Int
    , queueRestartLimit : Maybe Int
    }


defaultSettingsPayload : SettingsPayload
defaultSettingsPayload =
    { compiler = Nothing
    , queue = Nothing
    , repoAllowlist = Nothing
    , scheduleAllowlist = Nothing
    , maxDashboardRepos = Nothing
    , queueRestartLimit = Nothing
    }


encodeSettingsPayload : SettingsPayload -> Json.Encode.Value
encodeSettingsPayload settings =
    Json.Encode.object
        [ ( "compiler", encodeOptional encodeCompilerPayload settings.compiler )
        , ( "queue", encodeOptional encodeQueuePayload settings.queue )
        , ( "repo_allowlist", encodeOptional (Json.Encode.list Json.Encode.string) settings.repoAllowlist )
        , ( "schedule_allowlist", encodeOptional (Json.Encode.list Json.Encode.string) settings.scheduleAllowlist )
        , ( "max_dashboard_repos", encodeOptional Json.Encode.int settings.maxDashboardRepos )
        , ( "queue_restart_limit", encodeOptional Json.Encode.int settings.queueRestartLimit )
        ]


type PlatformSettingsFieldUpdate
    = CompilerCloneImage
    | CompilerTemplateDepth
    | CompilerStarlarkExecLimit
    | MaxDashboardRepos
    | QueueRestartLimit
    | QueueRouteAdd String
    | QueueRouteUpdate String String
    | QueueRouteRemove String
    | RepoAllowlistAdd String
    | RepoAllowlistUpdate String String
    | RepoAllowlistRemove String
    | ScheduleAllowlistAdd String
    | ScheduleAllowlistUpdate String String
    | ScheduleAllowlistRemove String


type alias PlatformSettingsUpdateResponseConfig =
    { successAlert : PlatformSettings -> String
    }


platformSettingsFieldUpdateToResponseConfig : PlatformSettingsFieldUpdate -> PlatformSettingsUpdateResponseConfig
platformSettingsFieldUpdateToResponseConfig field =
    case field of
        CompilerCloneImage ->
            { successAlert =
                \settings ->
                    "Compiler clone image set to '"
                        ++ settings.compiler.cloneImage
                        ++ "'."
            }

        CompilerTemplateDepth ->
            { successAlert =
                \settings ->
                    "Compiler template depth set to '"
                        ++ String.fromInt settings.compiler.templateDepth
                        ++ "'."
            }

        CompilerStarlarkExecLimit ->
            { successAlert =
                \settings ->
                    "Compiler Starlark exec limit set to '"
                        ++ String.fromInt settings.compiler.starlarkExecLimit
                        ++ "'."
            }

        MaxDashboardRepos ->
            { successAlert =
                \settings ->
                    "Max dashboard repos set to '"
                        ++ String.fromInt settings.maxDashboardRepos
                        ++ "'."
            }

        QueueRestartLimit ->
            { successAlert =
                \settings ->
                    "Queue restart limit set to '"
                        ++ String.fromInt settings.queueRestartLimit
                        ++ "'."
            }

        QueueRouteAdd added ->
            { successAlert =
                \_ ->
                    "Queue route '" ++ added ++ "' added."
            }

        QueueRouteUpdate from to ->
            { successAlert =
                \_ ->
                    "Queue route '" ++ from ++ "' updated to'" ++ to ++ "'."
            }

        QueueRouteRemove route ->
            { successAlert =
                \_ ->
                    "Queue route '" ++ route ++ "' removed."
            }

        RepoAllowlistAdd added ->
            { successAlert =
                \_ ->
                    "Repo '" ++ added ++ "' added to the overall allowlist."
            }

        RepoAllowlistUpdate from to ->
            { successAlert =
                \_ ->
                    "Repo '" ++ from ++ "' updated to'" ++ to ++ "' in the overall allowlist."
            }

        RepoAllowlistRemove route ->
            { successAlert =
                \_ ->
                    "Repo '" ++ route ++ "' removed from the overall allowlist."
            }

        ScheduleAllowlistAdd added ->
            { successAlert =
                \_ ->
                    "Repo '" ++ added ++ "' added to the schedules allowlist."
            }

        ScheduleAllowlistUpdate from to ->
            { successAlert =
                \_ ->
                    "Repo '" ++ from ++ "' updated to'" ++ to ++ "' in the schedules allowlist."
            }

        ScheduleAllowlistRemove route ->
            { successAlert =
                \_ ->
                    "Repo '" ++ route ++ "' removed from the schedules allowlist."
            }


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
