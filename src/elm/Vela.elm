{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Vela exposing
    ( ActivateRepo
    , ActivateRepos
    , ActivateRepositoryPayload
    , ActivationStatus(..)
    , AuthParams
    , Build
    , BuildIdentifier
    , BuildNumber
    , Builds
    , BuildsModel
    , Field
    , Hook
    , HookBuilds
    , Hooks
    , HooksModel
    , LineFocus
    , Log
    , Logs
    , Org
    , Repo
    , RepoSearchFilters
    , Repositories
    , Repository
    , Search
    , SearchFilter
    , Session
    , SourceRepositories
    , Status(..)
    , Step
    , StepNumber
    , Steps
    , Theme(..)
    , UpdateRepositoryPayload
    , User
    , Viewing
    , buildUpdateRepoBoolPayload
    , buildUpdateRepoIntPayload
    , buildUpdateRepoStringPayload
    , decodeBuild
    , decodeBuilds
    , decodeHook
    , decodeHooks
    , decodeLog
    , decodeRepositories
    , decodeRepository
    , decodeSession
    , decodeSourceRepositories
    , decodeStep
    , decodeSteps
    , decodeTheme
    , decodeUser
    , defaultActivateRepositoryPayload
    , defaultBuilds
    , defaultHooks
    , defaultRepository
    , defaultSession
    , defaultUpdateRepositoryPayload
    , defaultUser
    , encodeActivateRepository
    , encodeSession
    , encodeTheme
    , encodeUpdateRepository
    , stringToTheme
    )

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, andThen, bool, dict, int, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as Encode
import LinkHeader exposing (WebLink)
import RemoteData exposing (RemoteData(..), WebData)



-- COMMON


type Theme
    = Light
    | Dark


type alias Org =
    String


type alias Repo =
    String


type alias BuildNumber =
    String


type alias StepNumber =
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
    , allow_pull : Bool
    , allow_push : Bool
    , allow_deploy : Bool
    , allow_tag : Bool
    , added : WebData Bool
    , removed : ActivationStatus
    }


type ActivationStatus
    = ConfirmDeactivation
    | Deactivating
    | Deactivated
    | Activating
    | Activated
    | NotAsked_


defaultRepository : Repository
defaultRepository =
    Repository -1 -1 "" "" "" "" "" "" 0 "" False False False False False False False NotAsked NotAsked_


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
        |> optional "timeout" int 0
        |> optional "visibility" string ""
        |> optional "private" bool False
        |> optional "trusted" bool False
        |> optional "active" bool False
        |> optional "allow_pull" bool False
        |> optional "allow_push" bool False
        |> optional "allow_deploy" bool False
        |> optional "allow_tag" bool False
        -- "added"
        |> hardcoded NotAsked
        -- "removed"
        |> optional "active" activationStatusDecoder NotAsked_


{-| activationStatusDecoder : decodes string field "status" to the union type BuildStatus
-}
activationStatusDecoder : Decoder ActivationStatus
activationStatusDecoder =
    bool |> andThen toActivationStatus


{-| toActivationStatus : helper to decode string to ActivationStatus
-}
toActivationStatus : Bool -> Decoder ActivationStatus
toActivationStatus active =
    if active then
        succeed Activated

    else
        succeed Deactivated


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


encodeActivateRepository : ActivateRepositoryPayload -> Encode.Value
encodeActivateRepository repo =
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
        ]


type alias ActivateRepositoryPayload =
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
    }


defaultActivateRepositoryPayload : ActivateRepositoryPayload
defaultActivateRepositoryPayload =
    ActivateRepositoryPayload "" "" "" "" "" False True True True True False False


type alias UpdateRepositoryPayload =
    { private : Maybe Bool
    , trusted : Maybe Bool
    , active : Maybe Bool
    , allow_pull : Maybe Bool
    , allow_push : Maybe Bool
    , allow_deploy : Maybe Bool
    , allow_tag : Maybe Bool
    , visibility : Maybe String
    , timeout : Maybe Int
    }


type alias Field =
    String


defaultUpdateRepositoryPayload : UpdateRepositoryPayload
defaultUpdateRepositoryPayload =
    UpdateRepositoryPayload Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing


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
        , ( "visibility", encodeOptional Encode.string repo.visibility )
        , ( "timeout", encodeOptional Encode.int repo.timeout )
        ]


encodeOptional : (a -> Encode.Value) -> Maybe a -> Encode.Value
encodeOptional encoder value =
    case value of
        Just value_ ->
            encoder value_

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

        _ ->
            defaultUpdateRepositoryPayload


buildUpdateRepoStringPayload : Field -> String -> UpdateRepositoryPayload
buildUpdateRepoStringPayload field value =
    case field of
        "visibility" ->
            { defaultUpdateRepositoryPayload | visibility = Just value }

        _ ->
            defaultUpdateRepositoryPayload


buildUpdateRepoIntPayload : Field -> Int -> UpdateRepositoryPayload
buildUpdateRepoIntPayload field value =
    case field of
        "timeout" ->
            { defaultUpdateRepositoryPayload | timeout = Just value }

        _ ->
            defaultUpdateRepositoryPayload



-- BUILDS


type alias BuildsModel =
    { org : Org
    , repo : Repo
    , builds : WebData Builds
    , pager : List WebLink
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
    BuildsModel "" "" RemoteData.NotAsked []


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
    , viewing : Bool
    , lineFocus : Maybe Int
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
        -- "viewing"
        |> hardcoded False
        -- "lineFocus"
        |> hardcoded Nothing


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
    List (WebData Log)


type alias LineFocus =
    Maybe String



-- HOOKS


type alias HooksModel =
    { hooks : WebData Hooks
    , pager : List WebLink
    }


defaultHooks : HooksModel
defaultHooks =
    HooksModel RemoteData.NotAsked []


{-| Hook : record type for vela repo hooks
-}
type alias Hook =
    { id : Int
    , repo_id : Int
    , build_id : Int
    , source_id : String
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


type alias Viewing =
    Bool


type alias HookBuilds =
    Dict BuildIdentifier ( WebData Build, Viewing )


type alias BuildIdentifier =
    ( Org, Repo, BuildNumber )



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


{-| ActivateRepo : takes repo and activates it on Vela
-}
type alias ActivateRepo msg =
    Repository -> msg


{-| ActivateRepos : takes repos and activates them on Vela
-}
type alias ActivateRepos msg =
    Repositories -> msg


{-| Search : takes org and repo and searches/filters based on user input
-}
type alias Search msg =
    Org -> String -> msg
