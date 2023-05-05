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

import Auth.Session exposing (Session)
import Http
import Http.Detailed
import LinkHeader exposing (WebLink)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Vela exposing (Org, Repo, Schedule, Schedules, Team)



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | velaAPI : String
        , session : Session
        , page : Page
        , schedulesModel : Model msg
    }


{-| Model : record to hold page input arguments
-}
type alias Model msg =
    { id: Int
    , org : Org
    , repo : Repo
    , entry : String
    , enabled : Bool
    , schedule: WebData Schedule
    , schedules: WebData Schedules
    , schedulesPager : List WebLink
    , form : ScheduleForm
    , scheduleResponse : ScheduleResponse msg
    , addScheduleResponse : AddScheduleResponse msg
    , deleteScheduleResponse : DeleteScheduleResponse msg
    , updateScheduleResponse : AddScheduleResponse msg
    , pager : List WebLink
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
    ScheduleForm "Daily" "0 0 * * *" True


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
