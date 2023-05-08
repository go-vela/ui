{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.Form exposing
    ( viewEnabledCheckbox
    , viewHelp
    , viewInput
    , viewNameInput
    , viewSubmitButtons
    , viewValueInput
    )

import Html
    exposing
        ( Html
        , a
        , button
        , code
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
import Pages.Schedules.Model exposing (DeleteScheduleState(..), Model, Msg(..), ScheduleForm)
import Util
import Vela exposing (Field)


{-| viewHelp : renders help msg pointing to Vela docs
-}
viewHelp : Html Msg
viewHelp =
    div [ class "help" ] [ text "Need help? Visit our ", a [ href schedulesDocsURL, target "_blank" ] [ text "docs" ], text "!" ]


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
            , class "schedule-name"
            , placeholder "Schedule Name"
            , id "schedule-name"
            ]
            []
        ]


{-| viewInput : renders value input box
-}
viewInput : String -> String -> String -> Html Msg
viewInput name val placeholder_ =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| name ] [ strong [] [ text name ] ]
        , input
            [ value val
            , onInput <| OnChangeStringField name
            , class "schedule-name"
            , placeholder placeholder_
            , id name
            ]
            []
        ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> Html Msg
viewValueInput val placeholder_ =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "schedule-entry" ] [ strong [] [ text "Entry" ] ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField "entry"
            , class "schedule-entry"
            , class "form-control"
            , placeholder placeholder_
            , id "schedule-entry"
            ]
            []
        ]


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
                    , em [] [ text "Disabled schdules will not be run" ]
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


viewSubmitButtons : Model msg -> Html Msg
viewSubmitButtons schedulesModel =
    div [ class "buttons" ]
        [ viewUpdateButton schedulesModel
        , viewCancelButton schedulesModel
        , viewDeleteButton schedulesModel
        ]


viewUpdateButton : Model msg -> Html Msg
viewUpdateButton schedulesModel =
    button
        [ class "button"
        , onClick <| Pages.Schedules.Model.UpdateSchedule
        ]
        [ text "Update" ]


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


{-| eventEnabled : takes event and returns if it is enabled
-}
eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event


schedulesDocsURL : String
schedulesDocsURL =
    "#TODO"
