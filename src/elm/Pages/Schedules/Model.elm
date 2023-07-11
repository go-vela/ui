{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.Model exposing
    ( AddScheduleResponse
    , DeleteScheduleResponse
    , DeleteScheduleState(..)
    , Model
    , Msg(..)
    , PartialModel
    , ScheduleForm
    , ScheduleResponse
    , SchedulesResponse
    , UpdateScheduleResponse
    , defaultScheduleUpdate
    )

import Api.Pagination as Pagination
import Auth.Session exposing (Session)
import Http
import Http.Detailed
import LinkHeader exposing (WebLink)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Time exposing (Zone)
import Vela exposing (Org, Repo, Schedule, Schedules)



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | velaAPI : String
        , velaScheduleAllowlist : List ( Org, Repo )
        , session : Session
        , page : Page
        , zone : Zone
        , schedulesModel : Model msg
    }


{-| Model : record to hold page input arguments
-}
type alias Model msg =
    { org : Org
    , repo : Repo
    , schedule : WebData Schedule
    , schedules : WebData Schedules
    , pager : List WebLink
    , maybePage : Maybe Pagination.Page
    , maybePerPage : Maybe Pagination.PerPage
    , form : ScheduleForm
    , scheduleResponse : ScheduleResponse msg
    , addScheduleResponse : AddScheduleResponse msg
    , deleteScheduleResponse : DeleteScheduleResponse msg
    , updateScheduleResponse : AddScheduleResponse msg
    , deleteState : DeleteScheduleState
    }


{-| ScheduleForm : record to hold potential add/update fields
-}
type alias ScheduleForm =
    { name : String
    , entry : String
    , enabled : Bool
    }


defaultScheduleUpdate : ScheduleForm
defaultScheduleUpdate =
    ScheduleForm "" "0 0 * * *" True



-- MSG


type alias ScheduleResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ) -> msg


type alias SchedulesResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Schedules ) -> msg


type alias AddScheduleResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ) -> msg


type alias UpdateScheduleResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, Schedule ) -> msg


type alias DeleteScheduleResponse msg =
    Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg


type Msg
    = OnChangeStringField String String
    | OnChangeEnabled String
    | AddSchedule
    | UpdateSchedule
    | DeleteSchedule
    | CancelDeleteSchedule


type DeleteScheduleState
    = NotAsked_
    | Confirm
    | Deleting
