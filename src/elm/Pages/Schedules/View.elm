{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.View exposing
    ( addSchedule
    , editSchedule
    , viewRepoSchedules
    )

import Errors exposing (viewResourceError)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , h2
        , span
        , td
        , text
        , tr
        )
import Html.Attributes exposing (attribute, class, scope)
import Html.Events exposing (onClick)
import Http
import Pages.Schedules.Form
    exposing
        ( viewEnabledCheckbox
        , viewHelp
        , viewNameInput
        , viewSubmitButtons
        , viewValueInput
        )
import Pages.Schedules.Model exposing (Model, Msg, PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import Svg.Attributes
import Table
import Time exposing (Zone)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Org
        , Repo
        , Schedule
        , Schedules
        )


{-| viewRepoSchedules : takes schedules model and renders table for viewing repo schedules
-}
viewRepoSchedules : PartialModel a msg -> Org -> Repo -> Html msg
viewRepoSchedules model org repo =
    let
        schedulesAllowed =
            Util.checkScheduleAllowlist org repo model.velaScheduleAllowlist

        actions =
            if schedulesAllowed then
                Just <|
                    div [ class "buttons" ]
                        [ a
                            [ class "button"
                            , class "button-with-icon"
                            , class "-outline"
                            , Util.testAttribute "add-repo-schedule"
                            , Routes.href <|
                                Routes.AddSchedule org repo
                            ]
                            [ text <| "Add Schedule"
                            , FeatherIcons.plus
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                            ]
                        ]

            else
                Nothing

        ( noRowsView, rows ) =
            if schedulesAllowed then
                case model.schedulesModel.schedules of
                    Success s ->
                        ( text "No schedules found for this repo"
                        , schedulesToRows model.zone org repo s
                        )

                    Failure error ->
                        ( span [ Util.testAttribute "repo-schedule-error" ]
                            [ text <|
                                case error of
                                    Http.BadStatus statusCode ->
                                        case statusCode of
                                            401 ->
                                                "No schedules found for this repo, most likely due to not being an admin of the source control repo"

                                            _ ->
                                                "No schedules found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                    _ ->
                                        "No schedules found for this repo, there was an error with the server"
                            ]
                        , []
                        )

                    _ ->
                        ( largeLoader, [] )

            else
                ( viewSchedulesNotAllowedSpan
                , []
                )

        cfg =
            Table.Config
                "Repo Schedules"
                "repo-schedules"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Table.view cfg ]


{-| schedulesToRows : takes list of schedules and produces list of Table rows
-}
schedulesToRows : Zone -> Org -> Repo -> Schedules -> Table.Rows Schedule msg
schedulesToRows zone org repo schedules =
    List.map (\s -> Table.Row (addKey s) (renderSchedule zone org repo)) schedules


{-| tableHeaders : returns table headers for schedules table
-}
tableHeaders : Table.Columns
tableHeaders =
    [ ( Nothing, "name" )
    , ( Nothing, "entry" )
    , ( Nothing, "enabled" )
    , ( Nothing, "last scheduled at" )
    , ( Nothing, "updated by" )
    , ( Nothing, "updated at" )
    ]


{-| renderSchedule : takes schedule and renders a table row
-}
renderSchedule : Zone -> Org -> Repo -> Schedule -> Html msg
renderSchedule zone org repo schedule =
    tr [ Util.testAttribute <| "schedules-row" ]
        [ td
            [ attribute "data-label" "name"
            , scope "row"
            , class "break-word"
            , class "name"
            , Util.testAttribute <| "schedules-row-name"
            ]
            [ a [ updateScheduleHref org repo schedule ] [ text schedule.name ] ]
        , td
            [ attribute "data-label" "cron expression"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "schedules-row-key"
            ]
            [ text <| schedule.entry ]
        , td
            [ attribute "data-label" "enabled"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.boolToYesNo schedule.enabled ]
        , td
            [ attribute "data-label" "scheduled at"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.humanReadableWithDefault zone schedule.scheduled_at ]
        , td
            [ attribute "data-label" "updated by"
            , scope "row"
            , class "break-word"
            ]
            [ text <| schedule.updated_by ]
        , td
            [ attribute "data-label" "updated at"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.humanReadableWithDefault zone schedule.updated_at ]
        ]


{-| updateScheduleHref : takes schedule and returns href link for routing to view/edit schedule page
-}
updateScheduleHref : Org -> Repo -> Schedule -> Html.Attribute msg
updateScheduleHref org repo s =
    Routes.href <|
        Routes.Schedule org repo s.name


{-| addSchedule : takes partial model and renders the Add schedule form
-}
addSchedule : PartialModel a msg -> Html Msg
addSchedule model =
    div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
        [ div []
            [ h2 [] [ text "Add Schedule" ]
            , if Util.checkScheduleAllowlist model.schedulesModel.org model.schedulesModel.repo model.velaScheduleAllowlist then
                addForm model.schedulesModel

              else
                viewSchedulesNotAllowedSpan
            ]
        ]


{-| addForm : renders schedule update form for adding a new schedule
-}
addForm : Model msg -> Html Msg
addForm scheduleModel =
    let
        s =
            scheduleModel.form
    in
    div [ class "schedule-form" ]
        [ viewNameInput s.name False
        , viewValueInput s.entry "cron expression (0 0 * * *)"
        , viewEnabledCheckbox s
        , viewHelp
        , div [ class "form-action" ]
            [ button
                [ class "button"
                , class "-outline"
                , onClick <| Pages.Schedules.Model.AddSchedule
                , Util.testAttribute "schedule-add-button"
                ]
                [ text "Add" ]
            ]
        ]


{-| addKey : helper to create Schedule key
-}
addKey : Schedule -> Schedule
addKey schedule =
    { schedule | org = schedule.org ++ "/" ++ schedule.repo ++ "/" ++ schedule.name }


{-| editSchedule : takes partial model and renders schedule update form for editing a schedule
-}
editSchedule : PartialModel a msg -> Html Msg
editSchedule model =
    div [ class "manage-schedule", Util.testAttribute "manage-schedule" ]
        [ div []
            [ h2 [] [ text "View/Edit Schedule" ]
            , if Util.checkScheduleAllowlist model.schedulesModel.org model.schedulesModel.repo model.velaScheduleAllowlist then
                case model.schedulesModel.schedule of
                    Success _ ->
                        editForm model.schedulesModel

                    Failure _ ->
                        viewResourceError { resourceLabel = "schedule", testLabel = "schedule" }

                    _ ->
                        text ""

              else
                viewSchedulesNotAllowedSpan
            ]
        ]


{-| editForm : renders schedule update form for updating a preexisting schedule
-}
editForm : Model msg -> Html Msg
editForm scheduleModel =
    let
        scheduleUpdate =
            scheduleModel.form
    in
    div [ class "schedule-form", class "edit-form" ]
        [ viewNameInput scheduleUpdate.name True
        , viewValueInput scheduleUpdate.entry "cron expression (0 0 * * *)"
        , viewEnabledCheckbox scheduleUpdate
        , viewHelp
        , viewSubmitButtons scheduleModel
        ]


{-| viewSchedulesNotAllowedSpan : renders a warning that schedules have not been enabled for the current repository.
-}
viewSchedulesNotAllowedSpan : Html msg
viewSchedulesNotAllowedSpan =
    span [ class "not-allowed", Util.testAttribute "repo-schedule-not-allowed" ]
        [ text "Sorry, Administrators have not enabled Schedules for this repository."
        ]
