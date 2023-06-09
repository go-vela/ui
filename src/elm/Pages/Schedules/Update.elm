{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.Update exposing
    ( init
    , onChangeEnable
    , onChangeStringField
    , reinitializeScheduleAdd
    , reinitializeScheduleUpdate
    , update
    )

import Api
import Http
import Pages.Schedules.Model
    exposing
        ( AddScheduleResponse
        , DeleteScheduleResponse
        , DeleteScheduleState(..)
        , Model
        , Msg(..)
        , PartialModel
        , ScheduleForm
        , ScheduleResponse
        , UpdateScheduleResponse
        , defaultScheduleUpdate
        )
import RemoteData exposing (RemoteData(..))
import Util exposing (stringToMaybe)
import Vela
    exposing
        ( Schedule
        , UpdateSchedulePayload
        , buildUpdateSchedulePayload
        , encodeUpdateSchedule
        )



-- INIT


{-| init : takes msg updates from Main.elm and initializes schedules page input arguments
-}
init : ScheduleResponse msg -> AddScheduleResponse msg -> UpdateScheduleResponse msg -> DeleteScheduleResponse msg -> Model msg
init scheduleResponse addScheduleResponse updateScheduleResponse deleteScheduleResponse =
    Model -1
        ""
        ""
        ""
        False
        NotAsked
        NotAsked
        []
        defaultScheduleUpdate
        scheduleResponse
        addScheduleResponse
        deleteScheduleResponse
        updateScheduleResponse
        []
        NotAsked_



-- HELPERS


{-| reinitializeScheduleAdd : takes an incoming schedule and reinitializes the schdedule page input arguments
-}
reinitializeScheduleAdd : Model msg -> Model msg
reinitializeScheduleAdd schedulesModel =
    { schedulesModel | form = defaultScheduleUpdate, schedule = RemoteData.NotAsked }


{-| reinitializeScheduleUpdate : takes an incoming schedule and reinitializes the schdedule page input arguments
-}
reinitializeScheduleUpdate : Model msg -> Schedule -> Model msg
reinitializeScheduleUpdate scheduleModel schedule =
    { scheduleModel | form = initScheduleUpdate schedule, schedule = RemoteData.succeed schedule }


initScheduleUpdate : Schedule -> ScheduleForm
initScheduleUpdate schedule =
    ScheduleForm schedule.name schedule.entry schedule.enabled


{-| updateScheduleModel : makes an update to the appropriate schedule update
-}
updateScheduleModel : ScheduleForm -> Model msg -> Model msg
updateScheduleModel schedule scheduleModel =
    { scheduleModel | form = schedule }


{-| onChangeStringField : takes field and value and updates the schedule model
-}
onChangeStringField : String -> String -> Model msg -> Model msg
onChangeStringField field value scheduleModel =
    let
        scheduleUpdate =
            Just scheduleModel.form
    in
    case scheduleUpdate of
        Just s ->
            updateScheduleModel (updateScheduleField field value s) scheduleModel

        Nothing ->
            scheduleModel


{-| updateScheduleField : takes field and value and updates the schedule update field
-}
updateScheduleField : String -> String -> ScheduleForm -> ScheduleForm
updateScheduleField field value schedule =
    case field of
        "name" ->
            { schedule | name = value }

        "entry" ->
            { schedule | entry = value }

        _ ->
            schedule


{-| onChangeEnable : updates enabled field on schedule update
-}
onChangeEnable : String -> Model msg -> Model msg
onChangeEnable bool scheduleModel =
    let
        scheduleUpdate =
            Just scheduleModel.form
    in
    case scheduleUpdate of
        Just s ->
            updateScheduleModel { s | enabled = Util.yesNoToBool bool } scheduleModel

        Nothing ->
            scheduleModel


{-| toAddSchedulePayload : builds payload for adding schedule
-}
toAddSchedulePayload : Model msg -> ScheduleForm -> UpdateSchedulePayload
toAddSchedulePayload scheduleModel schedule =
    buildUpdateSchedulePayload
        (Just scheduleModel.org)
        (Just scheduleModel.repo)
        (stringToMaybe schedule.name)
        (stringToMaybe schedule.entry)
        (Just schedule.enabled)


{-| toUpdateSchedulePayload : builds payload for updating schedule
-}
toUpdateSchedulePayload : Model msg -> ScheduleForm -> UpdateSchedulePayload
toUpdateSchedulePayload scheduleModel schedule =
    let
        args =
            { id = scheduleModel.id
            , org = Nothing
            , repo = Nothing
            , name = Nothing
            , entry = stringToMaybe schedule.entry
            , enabled = Just schedule.enabled
            }
    in
    buildUpdateSchedulePayload args.org args.repo args.name args.entry args.enabled



-- UPDATE


update : PartialModel a msg -> Msg -> ( PartialModel a msg, Cmd msg )
update model msg =
    let
        scheduleModel =
            model.schedulesModel

        ( sm, action ) =
            case msg of
                OnChangeStringField field value ->
                    ( onChangeStringField field value scheduleModel, Cmd.none )

                OnChangeEnabled bool ->
                    ( onChangeEnable bool scheduleModel, Cmd.none )

                Pages.Schedules.Model.AddSchedule ->
                    let
                        schedule =
                            scheduleModel.form

                        payload : UpdateSchedulePayload
                        payload =
                            toAddSchedulePayload scheduleModel schedule

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSchedule payload
                    in
                    ( scheduleModel
                    , Api.try scheduleModel.addScheduleResponse <|
                        Api.addSchedule model
                            scheduleModel.org
                            scheduleModel.repo
                            body
                    )

                Pages.Schedules.Model.UpdateSchedule ->
                    let
                        schedule =
                            scheduleModel.form

                        payload : UpdateSchedulePayload
                        payload =
                            toUpdateSchedulePayload scheduleModel schedule

                        body : Http.Body
                        body =
                            Http.jsonBody <| encodeUpdateSchedule payload
                    in
                    ( scheduleModel
                    , Api.try scheduleModel.updateScheduleResponse <|
                        Api.updateSchedule model
                            scheduleModel.org
                            scheduleModel.repo
                            schedule.name
                            body
                    )

                Pages.Schedules.Model.DeleteSchedule ->
                    let
                        schedule =
                            scheduleModel.form

                        updatedModel =
                            case scheduleModel.deleteState of
                                NotAsked_ ->
                                    { scheduleModel
                                        | deleteState = Confirm
                                    }

                                Confirm ->
                                    { scheduleModel
                                        | deleteState = Deleting
                                    }

                                Deleting ->
                                    scheduleModel

                        doAction =
                            case scheduleModel.deleteState of
                                NotAsked_ ->
                                    Cmd.none

                                Confirm ->
                                    Api.tryString scheduleModel.deleteScheduleResponse <|
                                        Api.deleteSchedule model
                                            scheduleModel.org
                                            scheduleModel.repo
                                            schedule.name

                                Deleting ->
                                    Cmd.none
                    in
                    ( updatedModel, doAction )

                Pages.Schedules.Model.CancelDeleteSchedule ->
                    ( { scheduleModel
                        | deleteState = NotAsked_
                      }
                    , Cmd.none
                    )
    in
    ( { model | schedulesModel = sm }, action )
