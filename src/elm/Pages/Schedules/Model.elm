{--
SPDX-License-Identifier: Apache-2.0
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

import Shared
import Api.Pagination as Pagination
import Auth.Session exposing (Session)
import Http
import Http.Detailed
import LinkHeader exposing (WebLink)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Time exposing (Posix, Zone)
import Vela exposing (Org, Repo, Schedule, Schedules)



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a msg =
    { a
        | shared: Shared.Model
        , page : Page
        , time : Posix
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
    , branch : String
    }


defaultScheduleUpdate : ScheduleForm
defaultScheduleUpdate =
    ScheduleForm "" "" True ""



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
