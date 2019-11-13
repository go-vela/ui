{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Vela exposing
    ( AddRepositoryPayload
    , AuthParams
    , Build
    , BuildNumber
    , Builds
    , BuildsModel
    , Log
    , Logs
    , Org
    , Repo
    , Repositories
    , Repository
    , Session
    , SourceRepoUpdateFunction
    , SourceRepositories
    , Status(..)
    , Step
    , StepNumber
    , Steps
    , User
    , decodeBuild
    , decodeBuilds
    , decodeLog
    , decodeRepositories
    , decodeRepository
    , decodeSession
    , decodeSourceRepositories
    , decodeStep
    , decodeSteps
    , decodeUser
    , defaultAddRepositoryPayload
    , defaultBuilds
    , defaultRepository
    , defaultSession
    , defaultUser
    , encodeAddRepository
    , encodeSession
    )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, andThen, bool, dict, int, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as Encode
import RemoteData exposing (RemoteData(..), WebData)



-- COMMON


type alias Org =
    String


type alias Repo =
    String


type alias BuildNumber =
    String


type alias StepNumber =
    String



-- SESSION


type alias Session =
    { username : String
    , token : String
    , entrypoint : String
    }


defaultSession : Session
defaultSession =
    Session "" "" ""


decodeSession : Decoder Session
decodeSession =
    Decode.succeed Session
        |> required "username" string
        |> required "token" string
        |> required "entrypoint" string


encodeSession : Session -> Encode.Value
encodeSession session =
    Encode.object
        [ ( "username", Encode.string <| session.username )
        , ( "token", Encode.string <| session.token )
        , ( "entrypoint", Encode.string <| session.entrypoint )
        ]



-- USER


type alias User =
    { username : String
    , token : String
    }


defaultUser : User
defaultUser =
    User "" ""


decodeUser : Decoder User
decodeUser =
    Decode.succeed User
        |> required "username" string
        |> required "token" string



-- AUTH


type alias AuthParams =
    { code : Maybe String
    , state : Maybe String
    }



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
    , timeout : Int
    , visibility : String
    , private : Bool
    , trusted : Bool
    , active : Bool
    , allow_pr : Bool
    , allow_push : Bool
    , allow_deploy : Bool
    , allow_tag : Bool
    , added : WebData Bool
    , removed : WebData Bool
    }


defaultRepository : Repository
defaultRepository =
    Repository -1 -1 "" "" "" "" "" "" -1 "" False False False False False False False NotAsked NotAsked


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
        |> optional "timeout" int -1
        |> optional "visibility" string ""
        |> optional "private" bool False
        |> optional "trusted" bool False
        |> optional "active" bool False
        |> optional "allow_pr" bool False
        |> optional "allow_push" bool False
        |> optional "allow_deploy" bool False
        |> optional "allow_tag" bool False
        -- "added"
        |> hardcoded NotAsked
        -- "removed"
        |> hardcoded NotAsked


decodeRepositories : Decoder Repositories
decodeRepositories =
    Decode.list decodeRepository


decodeSourceRepositories : Decoder SourceRepositories
decodeSourceRepositories =
    Decode.dict (Decode.list decodeRepository)


{-| Repositories : type alias for list of added repositories
-}
type alias Repositories =
    List Repository


{-| SourceRepositories : type alias for repositories available for creation
-}
type alias SourceRepositories =
    Dict String Repositories


{-| SourceRepoUpdateFunction : function alias for updating source repositories via org or repo name
-}
type alias SourceRepoUpdateFunction =
    Repository -> WebData Bool -> Repositories -> Repositories


encodeAddRepository : AddRepositoryPayload -> Encode.Value
encodeAddRepository repo =
    Encode.object
        [ ( "org", Encode.string <| repo.org )
        , ( "name", Encode.string <| repo.name )
        , ( "full_name", Encode.string <| repo.full_name )
        , ( "link", Encode.string <| repo.link )
        , ( "clone", Encode.string <| repo.clone )
        , ( "timeout", Encode.int <| repo.timeout )
        , ( "private", Encode.bool <| repo.private )
        , ( "trusted", Encode.bool <| repo.trusted )
        , ( "active", Encode.bool <| repo.active )
        , ( "allow_pull", Encode.bool <| repo.allow_pull )
        , ( "allow_push", Encode.bool <| repo.allow_push )
        , ( "allow_deploy", Encode.bool <| repo.allow_deploy )
        , ( "allow_tag", Encode.bool <| repo.allow_tag )
        ]


type alias AddRepositoryPayload =
    { org : String
    , name : String
    , full_name : String
    , link : String
    , clone : String
    , timeout : Int
    , private : Bool
    , trusted : Bool
    , active : Bool
    , allow_pull : Bool
    , allow_push : Bool
    , allow_deploy : Bool
    , allow_tag : Bool
    }


defaultAddRepositoryPayload : AddRepositoryPayload
defaultAddRepositoryPayload =
    AddRepositoryPayload "" "" "" "" "" 60 False True True True True False False



-- BUILDS


type alias BuildsModel =
    { org : Org
    , repo : Repo
    , builds : WebData Builds
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
    , ref : String
    , base_ref : String
    , host : String
    , runtime : String
    , distribution : String
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
        |> optional "ref" string ""
        |> optional "base_ref" string ""
        |> optional "host" string ""
        |> optional "runtime" string ""
        |> optional "distribution" string ""


{-| toBuildStatus : decodes json from vela into list of builds
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
    BuildsModel "" "" RemoteData.NotAsked


type alias Builds =
    List Build


{-| Status : type enum to represent the possible statuses a vela object can be in
-}
type Status
    = Pending
    | Running
    | Success
    | Failure
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

        "error" ->
            succeed Error

        _ ->
            succeed Error



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
    }


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


{-| decodeSteps : decodes json from vela into list of steps
-}
decodeSteps : Decoder Steps
decodeSteps =
    Decode.list decodeStep


type alias Steps =
    List Step



-- LOG


type alias Log =
    { id : Int
    , step_id : Int
    , build_id : Int
    , repository_id : Int
    , data : String
    }


{-| decodeLog : decodes json from vela into log
-}
decodeLog : Decoder Log
decodeLog =
    Decode.succeed Log
        |> optional "id" int -1
        |> optional "step_id" int -1
        |> optional "build_id" int -1
        |> optional "repository_id" int -1
        |> optional "data" string ""


type alias Logs =
    List Log
