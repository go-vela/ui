{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.Model exposing
    ( AddScheduleResponse
    , DeleteScheduleResponse
    , DeleteScheduleState(..)
    , Frequency(..)
    , Model
    , Msg(..)
    , MultiSelectConfig
    , MultiSelectMsgs
    , PartialModel
    , ScheduleForm
    , ScheduleResponse
    , SchedulesResponse
    , UpdateScheduleResponse
    , allFrequencyTags
    , defaultScheduleUpdate
    , frequencyToString
    )

import Auth.Session exposing (Session)
import Http
import Http.Detailed
import LinkHeader exposing (WebLink)
import Pages exposing (Page)
import RemoteData exposing (WebData)
import Vela exposing (Org, Repo, Schedule, Schedules)



-- TYPES
-- EDITOR TYPES


type Frequency
    = Minutely
    | Hourly
    | Daily
    | Weekly
    | Monthly


frequencyToString : Frequency -> String
frequencyToString frequency =
    case frequency of
        Hourly ->
            "Hourly"

        Minutely ->
            "Minutely"

        Daily ->
            "Daily"

        Weekly ->
            "Weekly"

        Monthly ->
            "Monthly"


allFrequencyTags : List Frequency
allFrequencyTags =
    [ Minutely, Hourly, Daily, Weekly, Monthly ]


type alias MultiSelectConfig =
    { label : String
    , showOptions : Bool
    , options : List String
    , selected : List String
    , inputValue : String
    }



-- END EDITOR


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
    { id : Int
    , org : Org
    , repo : Repo
    , entry : String
    , enabled : Bool
    , schedule : WebData Schedule
    , schedules : WebData Schedules
    , schedulesPager : List WebLink
    , form : ScheduleForm
    , useEditor : Bool
    , frequency : Maybe Frequency
    , seconds : MultiSelectConfig
    , minutes : MultiSelectConfig
    , hours : MultiSelectConfig
    , scheduleResponse : ScheduleResponse msg
    , addScheduleResponse : AddScheduleResponse msg
    , deleteScheduleResponse : DeleteScheduleResponse msg
    , updateScheduleResponse : AddScheduleResponse msg
    , pager : List WebLink
    , deleteState : DeleteScheduleState
    , focusOn : String -> msg
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
    ScheduleForm "" "" True



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
    | ToggleUseEditor Bool
    | ChangeFrequencySelection Frequency
      -- multiselect
    | MultiSelectOnClickSelect Bool
    | MultiSelectOnClickSelectedOptionsClear
    | MultiSelectOnClickSelectedOptionRemove String
    | MultiSelectOnClickOption String
    | MultiSelectOnKeyDownOption String Int
    | MultiSelectOnInputFilter String
    | MultiSelectOnKeyDownFilter Int


type alias MultiSelectMsgs msg =
    { onClickSelect : Bool -> msg
    , onClickSelectedOptionsClear : msg
    , onClickSelectedOptionRemove : String -> msg
    , onClickOption : String -> msg
    , onKeyDownOption : String -> Int -> msg
    , onInputFilter : String -> msg
    , onKeyDownFilter : Int -> msg
    }


type DeleteScheduleState
    = NotAsked_
    | Confirm
    | Deleting
