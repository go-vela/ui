{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Schedules.Form exposing
    ( viewEditor
    , viewEditorToggle
    , viewEnabledCheckbox
    , viewHelp
    , viewNameInput
    , viewSubmitButtons
    , viewValueInput
    )

import Dict
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , em
        , input
        , label
        , option
        , section
        , span
        , strong
        , text
        , textarea
        )
import Html.Attributes
    exposing
        ( attribute
        , checked
        , class
        , disabled
        , for
        , href
        , id
        , placeholder
        , selected
        , size
        , tabindex
        , target
        , type_
        , value
        )
import Html.Events
    exposing
        ( on
        , onCheck
        , onClick
        , onInput
        , targetValue
        )
import Html.Keyed as Keyed
import Json.Decode as Json
import Pages.Schedules.Model
    exposing
        ( DeleteScheduleState(..)
        , Frequency(..)
        , Model
        , Msg(..)
        , MultiSelectConfig
        , MultiSelectMsgs
        , ScheduleForm
        , allFrequencyTags
        , frequencyToString
        )
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


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> Bool -> Html Msg
viewValueInput val placeholder_ isDisabled =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "schedule-entry" ]
            [ strong [] [ text "Cron Expression " ]
            , a [ href "https://crontab.guru/", target "_blank" ] [ text "(help)" ]
            ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField "entry"
            , class "schedule-entry"
            , class "form-control"
            , placeholder placeholder_
            , disabled isDisabled
            , id "schedule-entry"
            ]
            []
        ]


{-| viewEditorToggle : renders checkbox inputs for selecting enabled
-}
viewEditorToggle : Model msg -> Html Msg
viewEditorToggle scheduleModel =
    section [ class "settings", Util.testAttribute "repo-settings-events" ]
        [ div [ class "form-controls", class "-stack" ]
            [ checkbox "Use Editor"
                "use_editor"
                scheduleModel.useEditor
                ToggleUseEditor
            ]
        ]


{-| checkbox : takes field name, id, state and click action, and renders an input checkbox.
-}
checkbox : String -> Field -> Bool -> (Bool -> msg) -> Html msg
checkbox name field state msg =
    div [ class "form-control", Util.testAttribute <| "repo-checkbox-" ++ field ]
        [ input
            [ type_ "checkbox"
            , id <| "checkbox-" ++ field
            , checked state
            , onCheck msg
            ]
            []
        , label [ class "form-label", for <| "checkbox-" ++ field ] [ strong [] [ text name ] ]
        ]


{-| viewEditor : renders a fancy editor for schedules
-}
viewEditor : Model msg -> Html Msg
viewEditor scheduleModel =
    div [ class "schedules-editor" ]
        [ section [ class "form-control", class "-stack" ]
            [ label [ class "form-label", for <| "schedule-entry" ]
                [ strong [] [ text "Frequency" ]
                ]
            , frequencySelect (SelectTagConfig ChangeFrequencySelection frequencyToString scheduleModel.frequency allFrequencyTags)
            ]
        , viewMultiSelect scheduleModel.seconds
            (MultiSelectMsgs MultiSelectOnClickSelect
                MultiSelectOnClickSelectedOptionsClear
                MultiSelectOnClickSelectedOptionRemove
                MultiSelectOnClickOption
                MultiSelectOnKeyDownOption
                MultiSelectOnInputFilter
                MultiSelectOnKeyDownFilter
            )

        -- , viewMultiSelect scheduleModel.minutes
        --     (MultiSelectMsgs MultiSelectOnClickSelect
        --         MultiSelectOnClickSelectedOptionsClear
        --         MultiSelectOnClickSelectedOptionRemove
        --         MultiSelectOnClickOption
        --         MultiSelectOnKeyDownOption
        --         MultiSelectOnInputFilter
        --         MultiSelectOnKeyDownFilter
        --     )
        -- , viewMultiSelect scheduleModel.hours
        --     (MultiSelectMsgs MultiSelectOnClickSelect
        --         MultiSelectOnClickSelectedOptionsClear
        --         MultiSelectOnClickSelectedOptionRemove
        --         MultiSelectOnClickOption
        --         MultiSelectOnKeyDownOption
        --         MultiSelectOnInputFilter
        --         MultiSelectOnKeyDownFilter
        --     )
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


viewSubmitButtons : Model msg -> Html Msg
viewSubmitButtons schedulesModel =
    div [ class "buttons" ]
        [ viewUpdateButton
        , viewCancelButton schedulesModel
        , viewDeleteButton schedulesModel
        ]


viewUpdateButton : Html Msg
viewUpdateButton =
    button
        [ class "button"
        , onClick <| Pages.Schedules.Model.UpdateSchedule
        , Util.testAttribute "schedule-update-button"
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


schedulesDocsURL : String
schedulesDocsURL =
    "https://go-vela.github.io/docs/usage/schedules/"


viewMultiSelect : MultiSelectConfig -> MultiSelectMsgs msg -> Html msg
viewMultiSelect cfg { onClickSelect, onClickSelectedOptionsClear, onClickSelectedOptionRemove, onClickOption, onKeyDownOption, onInputFilter, onKeyDownFilter } =
    let
        selectOptionsPrefilter =
            List.filter (\opt -> not <| List.member opt cfg.selected) cfg.options

        selectOptions =
            List.filter (\opt -> String.contains cfg.inputValue opt) selectOptionsPrefilter

        selectedOptions =
            cfg.selected

        selectBoxBackdrop =
            button
                [ class "multiselect-fakeselect"
                , value ""
                , tabindex -1
                , onClick (onClickSelect <| not cfg.showOptions)
                ]
                []

        selectBoxOptions =
            if cfg.showOptions then
                div [ class "multiselect-fakeoptions-container" ]
                    [ div
                        [ class "multiselect-fakeoptions"
                        , tabindex -1
                        ]
                      <|
                        if List.length selectOptions > 0 then
                            -- set focus on the first one when using filtering?
                            List.indexedMap (\idx opt -> multiSelectOption idx opt opt onClickOption onKeyDownOption) selectOptions

                        else
                            [ multiSelectOptionEmpty ]
                    ]

            else
                div [] []

        ph =
            if List.length selectedOptions > 0 then
                ""

            else
                "None selected will run on every second of the minute"

        shortcutInput =
            div
                [ class "form-control"
                , attribute "data-value" cfg.inputValue
                ]
                [ input
                    [ id "multiselect-inputbox"
                    , class "multiselect-shortcut-input"
                    , type_ "multiselect-filter"
                    , placeholder ph
                    , value cfg.inputValue
                    , size <| max 1 <| String.length cfg.inputValue
                    , onInput onInputFilter
                    , onClick (onClickSelect <| not cfg.showOptions)
                    , Util.onKeyDown onKeyDownFilter
                    ]
                    []
                ]

        selectedChips =
            (if List.length selectedOptions > 0 then
                List.map (\opt -> multiSelectSelectedOption opt opt onClickSelectedOptionRemove) selectedOptions

             else
                []
            )
                ++ [ shortcutInput ]

        clearButton =
            button
                [ class "button"
                , class "-icon"
                , onClick <| onClickSelectedOptionsClear
                , tabindex -1
                ]
                [ FeatherIcons.x
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml []
                ]

        arrow =
            div
                [ class "multiselect-arrow"
                ]
                [ FeatherIcons.chevronDown
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml []
                ]
    in
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "schedule-entry" ]
            [ strong [] [ text cfg.label ]
            ]
        , div
            [ class "multiselect"
            , class <|
                if cfg.showOptions then
                    "-active"

                else
                    ""
            ]
            [ div
                [ class "multiselect-input"
                ]
                [ selectBoxBackdrop
                , div
                    [ class "left-container-for-chips"
                    ]
                    selectedChips
                , div [ class "right-container-for-clearall" ] [ clearButton ]
                , div [ class "right-container-for-arrow" ] [ arrow ]
                ]
            , selectBoxOptions
            ]
        ]


multiSelectOption : Int -> String -> String -> (String -> msg) -> (String -> Int -> msg) -> Html msg
multiSelectOption idx label value_ onChange onKeyDown_ =
    div
        [ tabindex <| idx + 1
        , class "select-option"
        , value value_
        , onClick (onChange value_)
        , id <| "select-option-" ++ String.fromInt idx
        , Util.onKeyDown (onKeyDown_ value_)
        ]
        [ text label ]


multiSelectOptionEmpty : Html msg
multiSelectOptionEmpty =
    div [ class "select-option-none" ] [ text "No options" ]


multiSelectSelectedOption : String -> String -> (String -> msg) -> Html msg
multiSelectSelectedOption label value_ onClickRemove =
    div [ class "multiselect-selected-option" ]
        [ span [ class "value" ] [ text label ]
        , span []
            [ button
                [ class "button"
                , class "-icon"
                , onClick <| onClickRemove value_

                -- avoid tabbing to selected options
                , tabindex -1
                ]
                [ FeatherIcons.x
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml []
                ]
            ]
        ]


type alias SelectTagConfig a msg =
    { onSelect : a -> msg
    , toString : a -> String
    , selected : Maybe a
    , tags : List a
    }


frequencySelect : SelectTagConfig a msg -> Html msg
frequencySelect cfg =
    let
        options =
            List.map
                (\tag ->
                    ( cfg.toString tag
                    , option
                        [ value (cfg.toString tag)
                        , selected (Just (cfg.toString tag) == Maybe.map cfg.toString cfg.selected)
                        ]
                        [ text (cfg.toString tag) ]
                    )
                )
                cfg.tags

        addEmpty opts =
            case cfg.selected of
                Nothing ->
                    ( "default option", option [ disabled True, selected True ] [ text "Please select a value" ] ) :: opts

                Just _ ->
                    opts

        tagsDict =
            List.map (\tag -> ( cfg.toString tag, tag )) cfg.tags |> Dict.fromList

        decoder =
            targetValue
                |> Json.andThen
                    (\val ->
                        case Dict.get val tagsDict of
                            Nothing ->
                                Json.fail ""

                            Just tag ->
                                Json.succeed tag
                    )
                |> Json.map cfg.onSelect
    in
    Keyed.node "select" [ class "frequency-select", on "change" decoder ] (addEmpty options)
