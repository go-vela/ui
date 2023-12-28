{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Schedules.Form exposing
    ( viewAddForm
    , viewEditForm
    )

import Html
    exposing
        ( Html
        , a
        , button
        , div
        , em
        , input
        , label
        , section
        , span
        , strong
        , text
        , textarea
        )
import Html.Attributes
    exposing
        ( checked
        , class
        , disabled
        , for
        , href
        , id
        , placeholder
        , target
        , type_
        , value
        )
import Html.Events exposing (onClick, onInput)
import Pages.Schedules.Model exposing (DeleteScheduleState(..), Model, Msg(..), PartialModel, ScheduleForm)
import Util
import Vela exposing (Field)


{-| viewAddForm : renders schedule update form for adding a new schedule
-}
viewAddForm : PartialModel a msg -> Html Msg
viewAddForm model =
    let
        sm =
            model.schedulesModel
    in
    div [ class "schedule-form" ]
        [ viewNameInput sm.form.name False
        , viewValueInput sm.form.entry "0 0 * * * (runs at 12:00 AM in UTC)" (Util.toUtcString model.shared.time)
        , viewEnabledCheckbox sm.form
        , viewBranchNameInput sm.form.branch False
        , viewHelp
        , viewAddButton
        ]


{-| viewEditForm : renders schedule update form for updating a preexisting schedule
-}
viewEditForm : PartialModel a msg -> Html Msg
viewEditForm model =
    let
        sm =
            model.schedulesModel
    in
    div [ class "schedule-form", class "edit-form" ]
        [ viewNameInput sm.form.name True
        , viewValueInput sm.form.entry "0 0 * * * (runs at 12:00 AM in UTC)" (Util.toUtcString model.shared.time)
        , viewEnabledCheckbox sm.form
        , viewBranchNameInput sm.form.branch False
        , viewHelp
        , viewEditFormSubmitButtons sm
        ]


{-| viewNameInput : renders name input box
-}
viewNameInput : String -> Bool -> Html Msg
viewNameInput val disable =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "schedule-name" ] [ strong [] [ text "Name" ] ]
        , input
            [ disabled disable
            , value val
            , onInput <|
                OnChangeStringField "name"
            , placeholder "Schedule Name"
            , id "schedule-name"
            , Util.testAttribute "schedule-name"
            ]
            []
        ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> String -> Html Msg
viewValueInput val placeholder_ time =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "schedule-entry" ]
            [ strong [] [ text "Cron Expression " ]
            , viewCronHelpLink
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text <| "Expressions are evaluated in UTC, time now is " ++ time ]
                , text " )"
                ]
            ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField "entry"
            , class "form-control"
            , placeholder placeholder_
            , id "schedule-entry"
            , Util.testAttribute "schedule-entry"
            ]
            []
        ]


{-| viewCronHelpLink : renders cron help link
-}
viewCronHelpLink : Html msg
viewCronHelpLink =
    a [ class "field-help-link", href "https://crontab.guru/", target "_blank" ] [ text "help" ]


{-| radio : takes current value, field id, title for label, and click action and renders an input radio.
-}
radio : String -> String -> Field -> msg -> Html msg
radio value field title msg =
    div [ class "form-control", Util.testAttribute <| "schedule-radio-" ++ field ]
        [ input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick msg
            ]
            []
        , label [ class "form-label", for <| "radio-" ++ field ] [ strong [] [ text title ] ]
        ]


{-| viewEnabledCheckbox : renders checkbox inputs for selecting enabled
-}
viewEnabledCheckbox : ScheduleForm -> Html Msg
viewEnabledCheckbox enableUpdate =
    section [ Util.testAttribute "" ]
        [ div [ class "form-control" ]
            [ strong []
                [ text "State"
                , span [ class "field-description" ]
                    [ text "( "
                    , em [] [ text "Disabled schedules will not be run" ]
                    , text " )"
                    ]
                ]
            ]
        , div
            [ class "form-controls", class "-stack" ]
            [ radio (Util.boolToYesNo enableUpdate.enabled) "yes" "Enabled" <| OnChangeEnabled "yes"
            , radio (Util.boolToYesNo enableUpdate.enabled) "no" "Disabled" <| OnChangeEnabled "no"
            ]
        ]


{-| viewBranchNameInput : renders branch input box
-}
viewBranchNameInput : String -> Bool -> Html Msg
viewBranchNameInput val disable =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "schedule-branch-name" ]
            [ strong [] [ text "Branch" ]
            , span
                [ class "field-description" ]
                [ em [] [ text "(Leave blank to use default branch)" ]
                ]
            ]
        , input
            [ disabled disable
            , value val
            , onInput <|
                OnChangeStringField "branch"
            , placeholder "Branch Name"
            , id "schedule-branch-name"
            , Util.testAttribute "schedule-branch-name"
            ]
            []
        ]


{-| viewHelp : renders help msg pointing to Vela docs
-}
viewHelp : Html Msg
viewHelp =
    div [ class "help" ] [ text "Need help? Visit our ", a [ href schedulesDocsURL, target "_blank" ] [ text "docs" ], text "!" ]


{-| viewAddButton : renders submit button for adding a schedule
-}
viewAddButton : Html Msg
viewAddButton =
    div [ class "form-action" ]
        [ button
            [ class "button"
            , class "-outline"
            , onClick <| Pages.Schedules.Model.AddSchedule
            , Util.testAttribute "schedule-add-button"
            ]
            [ text "Add" ]
        ]


{-| viewEditFormSubmitButtons : renders all submit buttons for view/edit schedule
-}
viewEditFormSubmitButtons : Model msg -> Html Msg
viewEditFormSubmitButtons schedulesModel =
    div [ class "buttons" ]
        [ viewUpdateButton
        , viewCancelButton schedulesModel
        , viewDeleteButton schedulesModel
        ]


{-| viewUpdateButton : renders submit button for updating a schedule
-}
viewUpdateButton : Html Msg
viewUpdateButton =
    button
        [ class "button"
        , onClick <| Pages.Schedules.Model.UpdateSchedule
        , Util.testAttribute "schedule-update-button"
        ]
        [ text "Update" ]


{-| viewDeleteButton : renders submit button for deleting a schedule
-}
viewDeleteButton : Model msg -> Html Msg
viewDeleteButton schedulesModel =
    let
        scheduleDeleteConfirm =
            "-schedule-delete-confirm"

        scheduleDeleteLoading =
            "-loading"

        ( deleteButtonText, deleteButtonClass ) =
            case schedulesModel.deleteState of
                NotAsked_ ->
                    ( "Remove", "" )

                Confirm ->
                    ( "Confirm", scheduleDeleteConfirm )

                Deleting ->
                    ( "Removing", scheduleDeleteLoading )
    in
    button
        [ class "button"
        , class "-outline"
        , class deleteButtonClass
        , Util.testAttribute "schedule-delete-button"
        , onClick <| Pages.Schedules.Model.DeleteSchedule
        ]
        [ text deleteButtonText ]


{-| viewCancelButton : renders submit button for canceling a schedule deletion
-}
viewCancelButton : Model msg -> Html Msg
viewCancelButton schedulesModel =
    case schedulesModel.deleteState of
        NotAsked_ ->
            text ""

        Confirm ->
            button
                [ class "button"
                , class "-outline"
                , Util.testAttribute "schedule-cancel-button"
                , onClick <| Pages.Schedules.Model.CancelDeleteSchedule
                ]
                [ text "Cancel" ]

        Deleting ->
            text ""



-- HELPERS


{-| schedulesDocsURL : returns the Vela docs URL for schedules
-}
schedulesDocsURL : String
schedulesDocsURL =
    "https://go-vela.github.io/docs/usage/schedule_build/"
