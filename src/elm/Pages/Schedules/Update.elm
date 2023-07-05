{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.Update exposing
    ( init
    , reinitializeScheduleAdd
    , reinitializeScheduleUpdate
    , update
    )

import Api
import Http
import List.Extra
import Pages.Schedules.Model
    exposing
        ( AddScheduleResponse
        , DeleteScheduleResponse
        , DeleteScheduleState(..)
        , Frequency(..)
        , Model
        , Msg(..)
        , MultiSelectConfig
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
init : ScheduleResponse msg -> AddScheduleResponse msg -> UpdateScheduleResponse msg -> DeleteScheduleResponse msg -> (String -> msg) -> Model msg
init scheduleResponse addScheduleResponse updateScheduleResponse deleteScheduleResponse focusOn =
    Model -1
        ""
        ""
        ""
        False
        NotAsked
        NotAsked
        []
        defaultScheduleUpdate
        False
        (Just Hourly)
        (MultiSelectConfig "Seconds"
            False
            (List.Extra.initialize 60 (\idx -> String.fromInt idx))
            [ "0" ]
            ""
        )
        (MultiSelectConfig "Minutes"
            False
            (List.Extra.initialize 60 (\idx -> String.fromInt idx))
            [ "0" ]
            ""
        )
        (MultiSelectConfig "Hours"
            False
            (List.Extra.initialize 60 (\idx -> String.fromInt idx))
            [ "0" ]
            ""
        )
        scheduleResponse
        addScheduleResponse
        deleteScheduleResponse
        updateScheduleResponse
        []
        NotAsked_
        focusOn



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

        seconds =
            scheduleModel.seconds

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

                Pages.Schedules.Model.ToggleUseEditor value ->
                    ( { scheduleModel
                        | useEditor = value
                      }
                    , Cmd.none
                    )

                Pages.Schedules.Model.ChangeFrequencySelection selected ->
                    ( { scheduleModel
                        | frequency = Just selected
                      }
                    , Cmd.none
                    )

                Pages.Schedules.Model.MultiSelectOnClickSelect show ->
                    let
                        _ =
                            Debug.log "multiselect-showhide" show
                    in
                    ( { scheduleModel | seconds = { seconds | showOptions = show } }
                    , Cmd.none
                    )

                Pages.Schedules.Model.MultiSelectOnClickSelectedOptionRemove value ->
                    let
                        _ =
                            Debug.log "multiselect-remove" value

                        newSeconds =
                            List.Extra.remove value seconds.selected
                    in
                    ( { scheduleModel | seconds = { seconds | selected = newSeconds } }
                    , Cmd.none
                    )

                Pages.Schedules.Model.MultiSelectOnClickOption value ->
                    let
                        _ =
                            Debug.log "multiselect-changeselection" value

                        newSeconds =
                            List.Extra.unique <| List.sortBy (\s -> Maybe.withDefault -1 <| String.toInt s) <| value :: seconds.selected
                    in
                    ( { scheduleModel | seconds = { seconds | selected = newSeconds, showOptions = False, inputValue = "" } }
                    , Util.dispatch <| scheduleModel.focusOn <| "multiselect-inputbox"
                    )

                Pages.Schedules.Model.MultiSelectOnInputFilter value ->
                    let
                        _ =
                            Debug.log "multiselect-changeinput" value

                        -- newSeconds =
                        --     List.Extra.unique <| List.sortBy (\s -> Maybe.withDefault -1 <| String.toInt s) <| value :: scheduleModel.seconds
                    in
                    ( { scheduleModel | seconds = { seconds | inputValue = String.replace " " "" value, showOptions = seconds.inputValue /= value } }
                    , Cmd.none
                    )

                Pages.Schedules.Model.MultiSelectOnClickSelectedOptionsClear ->
                    let
                        _ =
                            Debug.log "multiselect-clear" ""

                        newSeconds =
                            []
                    in
                    ( { scheduleModel | seconds = { seconds | selected = newSeconds } }
                    , Util.dispatch <| scheduleModel.focusOn <| "multiselect-inputbox"
                    )

                Pages.Schedules.Model.MultiSelectOnKeyDownFilter keycode ->
                    let
                        _ =
                            Debug.log "multiselect-input-keydown" keycode

                        ( newSeconds, show, cmd ) =
                            case keycode of
                                8 ->
                                    -- backspace
                                    if String.length seconds.inputValue == 0 then
                                        ( Util.dropRight seconds.selected
                                        , seconds.showOptions
                                        , Util.dispatch <| scheduleModel.focusOn <| "multiselect-inputbox"
                                        )

                                    else
                                        ( seconds.selected
                                        , seconds.showOptions
                                        , Cmd.none
                                        )

                                9 ->
                                    -- tab
                                    ( seconds.selected
                                    , seconds.showOptions
                                      -- try focusing on the first option, if it doesnt exist, focus on the input
                                    , Cmd.batch
                                        [ if seconds.showOptions then
                                            Util.dispatch <| scheduleModel.focusOn <| "select-option-0"

                                          else
                                            Cmd.none
                                        ]
                                    )

                                32 ->
                                    -- spacebar
                                    ( seconds.selected
                                    , not seconds.showOptions
                                      -- try focusing on the first option, if it doesnt exist, focus on the input
                                    , Cmd.batch
                                        -- [ if not seconds.showOptions then Util.dispatch <| scheduleModel.focusOn <| "select-option-0" else Cmd.none
                                        [ Util.dispatch <| scheduleModel.focusOn <| "select-option-0"
                                        ]
                                    )

                                _ ->
                                    ( seconds.selected, seconds.showOptions, Cmd.none )
                    in
                    let
                        _ =
                            Debug.log "setting show to" <| show
                    in
                    ( { scheduleModel | seconds = { seconds | selected = newSeconds, showOptions = show } }
                      -- , Cmd.none
                    , cmd
                    )

                Pages.Schedules.Model.MultiSelectOnKeyDownOption opt keycode ->
                    let
                        _ =
                            Debug.log "multiselect-option-keydown" <| opt ++ "-" ++ String.fromInt keycode

                        ( newModel, cmd ) =
                            case keycode of
                                13 ->
                                    -- return
                                    ( { scheduleModel
                                        | seconds =
                                            { seconds
                                                | showOptions = False
                                                , inputValue = ""
                                                , selected = List.Extra.unique <| List.sortBy (\s -> Maybe.withDefault -1 <| String.toInt s) <| opt :: seconds.selected
                                            }
                                      }
                                    , Util.dispatch <| scheduleModel.focusOn <| "multiselect-inputbox"
                                    )

                                32 ->
                                    -- spacebar
                                    ( { scheduleModel
                                        | seconds =
                                            { seconds
                                                | showOptions = False
                                                , inputValue = ""
                                                , selected = List.Extra.unique <| List.sortBy (\s -> Maybe.withDefault -1 <| String.toInt s) <| opt :: seconds.selected
                                            }
                                      }
                                    , Util.dispatch <| scheduleModel.focusOn <| "multiselect-inputbox"
                                    )

                                _ ->
                                    ( scheduleModel, Cmd.none )
                    in
                    ( newModel
                      -- , Cmd.none
                    , cmd
                    )
    in
    ( { model | schedulesModel = sm }, action )
