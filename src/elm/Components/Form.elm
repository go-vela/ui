{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Form exposing (EditableListForm, handleNumberInputString, viewAllowEvents, viewButton, viewCheckbox, viewCopyButton, viewEditableList, viewInput, viewInputSection, viewNumberInput, viewRadio, viewSubtitle, viewTextarea, viewTextareaSection)

import Components.Loading
import Dict exposing (Dict)
import FeatherIcons
import Html exposing (Html, button, div, h3, input, label, li, section, span, strong, text, textarea, ul)
import Html.Attributes exposing (attribute, checked, class, classList, disabled, for, id, placeholder, rows, type_, value, wrap)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Maybe.Extra
import RemoteData exposing (WebData)
import Shared
import Utils.Helpers as Util
import Vela
import Effect exposing (Effect)
import Json.Decode



-- VIEW


{-| viewInputSection : renders the HTML for an input field in a section.
-}
viewInputSection :
    { id_ : String
    , title : Maybe String
    , subtitle : Maybe (Html msg)
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    , min : Maybe String
    , max : Maybe String
    , required : Bool
    }
    -> Html msg
viewInputSection { id_, title, subtitle, val, placeholder_, classList_, rows_, wrap_, msg, disabled_, min, max, required } =
    let
        target =
            String.join "-" [ "input", id_ ]
    in
    section
        [ class "form-control"
        , class "-stack"
        ]
        [ Maybe.Extra.unwrap (text "")
            (\l ->
                label [ class "form-label", for target ]
                    [ strong [] [ text l ], viewSubtitle subtitle ]
            )
            title
        , input
            [ id target
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Maybe.Extra.unwrap Util.attrNone Html.Attributes.min min
            , Maybe.Extra.unwrap Util.attrNone Html.Attributes.max max
            , Html.Attributes.required required
            , Util.testAttribute target
            ]
            []
        ]


{-| viewInput : renders the HTML for an input field within a section.
-}
viewInput :
    { id_ : String
    , title : Maybe String
    , subtitle : Maybe (Html msg)
    , val : String
    , placeholder_ : String
    , wrapperClassList : List ( String, Bool )
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    , min : Maybe String
    , max : Maybe String
    , required : Bool
    }
    -> Html msg
viewInput { id_, title, subtitle, val, placeholder_, classList_, wrapperClassList, rows_, wrap_, msg, disabled_, min, max, required} =
    let
        target =
            String.join "-" [ "input", id_ ]
    in
    div
        [ class "form-control"
        , classList wrapperClassList
        ]
        [ input
            [ id target
            , value val
            , placeholder placeholder_
            , classList <| classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Maybe.Extra.unwrap Util.attrNone Html.Attributes.min min
            , Maybe.Extra.unwrap Util.attrNone Html.Attributes.max max
            , Html.Attributes.required required
            , Util.testAttribute target
            ]
            []
        ]


{-| handleNumberInputString : returns a value as a number if it can be converted, otherwise returns the current value.
-}
handleNumberInputString : String -> String -> String
handleNumberInputString current val =
    case String.toInt val of
        Just _ ->
            val

        Nothing ->
            if not <| String.isEmpty val then
                current

            else
                ""


{-| viewNumberInput : renders the HTML for an input expected to handle numbers.
-}
viewNumberInput :
    { id_ : String
    , title : Maybe String
    , subtitle : Maybe (Html msg)
    , val : String
    , placeholder_ : String
    , wrapperClassList : List ( String, Bool )
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    , min : Maybe Int
    , max : Maybe Int
    , required : Bool
    }
    -> Html msg
viewNumberInput { id_, title, subtitle, val, placeholder_, wrapperClassList, classList_, rows_, wrap_, msg, disabled_, min, max, required } =
    let
        target =
            String.join "-" [ "input", id_ ]
    in
    div
        [ class "form-control"
        , classList wrapperClassList
        ]
        [ input
            [ id target
            , type_ "number"
            , Maybe.Extra.unwrap Util.attrNone (String.fromInt >> Html.Attributes.min) min
            , Maybe.Extra.unwrap Util.attrNone (String.fromInt >> Html.Attributes.max) max
            , value val
            , placeholder placeholder_
            , classList <| classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Html.Attributes.required required
            , Util.testAttribute target
            ]
            []
        ]


{-| viewTextareaSection : renders the HTML for a textarea within a section.
-}
viewTextareaSection :
    { id_ : String
    , title : Maybe String
    , subtitle : Maybe (Html msg)
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    , focusOutFunc : Maybe msg
    }
    -> Html msg
viewTextareaSection { id_, title, subtitle, val, placeholder_, classList_, rows_, wrap_, msg, disabled_, focusOutFunc } =
    let
        target =
            String.join "-" [ "textarea", id_ ]
    in
    section
        [ class "form-control"
        , class "-stack"
        ]
        [ Maybe.Extra.unwrap (text "")
            (\l ->
                label [ class "form-label", for target ]
                    [ strong [] [ text l ], viewSubtitle subtitle ]
            )
            title
        , textarea
            [ id target
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Maybe.Extra.unwrap Util.attrNone (Html.Events.on "focusout" << Json.Decode.succeed) focusOutFunc
            , Util.testAttribute target
            ]
            []
        ]


{-| viewTextarea : renders a textarea input.
-}
viewTextarea :
    { id_ : String
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewTextarea { id_, val, placeholder_, classList_, rows_, wrap_, msg, disabled_ } =
    let
        target =
            String.join "-" [ "textarea", id_ ]
    in
    div [ class "form-control" ]
        [ textarea
            [ id target
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Util.testAttribute target
            ]
            []
        ]


{-| viewCheckbox : renders the HTML for a checkbox.
-}
viewCheckbox :
    { id_ : String
    , title : String
    , subtitle : Maybe (Html msg)
    , field : String
    , state : Bool
    , wrapperClassList : List ( String, Bool )
    , msg : Bool -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewCheckbox { id_, title, subtitle, field, state, wrapperClassList, msg, disabled_ } =
    let
        target =
            String.join "-" [ "checkbox", id_, field ]
    in
    div
        [ class "form-control"
        , classList wrapperClassList
        , Util.testAttribute target
        ]
        [ input
            [ type_ "checkbox"
            , id target
            , checked state
            , onCheck msg
            , disabled disabled_
            , Util.testAttribute id_
            ]
            []
        , label [ class "form-label", for target ]
            [ text title, viewSubtitle subtitle ]
        ]


{-| viewRadio : renders the HTML for a radio button.
-}
viewRadio :
    { id_ : String
    , title : String
    , subtitle : Maybe (Html msg)
    , value : String
    , field : String
    , msg : msg
    , disabled_ : Bool
    }
    -> Html msg
viewRadio { id_, title, subtitle, value, field, msg, disabled_ } =
    let
        target =
            String.join "-" [ "radio", id_ ]
    in
    div [ class "form-control", Util.testAttribute target ]
        [ input
            [ type_ "radio"
            , id target
            , checked (value == field)
            , onClick msg
            , disabled disabled_
            , Util.testAttribute target
            ]
            []
        , label [ class "form-label", for target ]
            [ strong [] [ text title ], viewSubtitle subtitle ]
        ]


{-| viewButton : renders the HTML for a button.
-}
viewButton : { id_ : String, msg : msg, text_ : String, classList_ : List ( String, Bool ), disabled_ : Bool } -> Html msg
viewButton { id_, msg, text_, classList_, disabled_ } =
    let
        target =
            String.join "-" [ "button", id_ ]
    in
    button
        [ class "button"
        , onClick msg
        , disabled disabled_
        , classList classList_
        , Util.testAttribute target
        ]
        [ text text_ ]


{-| viewCopyButton : renders a copy to clipboard button
-}
viewCopyButton : { id_ : String, msg : String -> msg, text_ : String, classList_ : List ( String, Bool ), disabled_ : Bool, content : String } -> Html msg
viewCopyButton { id_, msg, text_, classList_, disabled_, content } =
    let
        target =
            String.join "-" [ "copy", id_ ]
    in
    div []
        [ button
            [ class "copy-button"
            , attribute "aria-label" ("copy " ++ id_ ++ "content to clipboard")
            , class "button"
            , class "-icon"
            , disabled disabled_
            , classList classList_
            , onClick <| msg content
            , attribute "data-clipboard-text" content
            , Util.testAttribute target
            ]
            [ FeatherIcons.copy
                |> FeatherIcons.withSize 18
                |> FeatherIcons.toHtml []
            ]
        ]


{-| viewSubtitle : renders the HTML for a subtitle.
-}
viewSubtitle : Maybe (Html msg) -> Html msg
viewSubtitle subtitle =
    Maybe.Extra.unwrap (text "")
        (\s -> span [] [ text " ", s ])
        subtitle


{-| viewAllowEvents : takes in allowed events and renders the HTML for events.
-}
viewAllowEvents :
    Shared.Model
    ->
        { msg : { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } -> Bool -> msg
        , allowEvents : Vela.AllowEvents
        , disabled_ : Bool
        }
    -> List (Html msg)
viewAllowEvents shared { msg, allowEvents } =
    [ h3 [ class "settings-subtitle" ] [ text "Push" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Push"
            , subtitle = Nothing
            , field = "allow_push_branch"
            , state = allowEvents.push.branch
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PushBranch }
            , disabled_ = False
            , id_ = "allow-events-push-branch"
            }
        , viewCheckbox
            { title = "Tag"
            , subtitle = Nothing
            , field = "allow_push_tag"
            , state = allowEvents.push.tag
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PushTag }
            , disabled_ = False
            , id_ = "allow-events-push-tag"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Pull Request" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Opened"
            , subtitle = Nothing
            , field = "allow_pull_opened"
            , state = allowEvents.pull.opened
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PullOpened }
            , disabled_ = False
            , id_ = "allow-events-pull-opened"
            }
        , viewCheckbox
            { title = "Synchronize"
            , subtitle = Nothing
            , field = "allow_pull_synchronize"
            , state = allowEvents.pull.synchronize
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PullSynchronize }
            , disabled_ = False
            , id_ = "allow-events-pull-synchronize"
            }
        , viewCheckbox
            { title = "Edited"
            , subtitle = Nothing
            , field = "allow_pull_edited"
            , state = allowEvents.pull.edited
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PullEdited }
            , disabled_ = False
            , id_ = "allow-events-pull-edited"
            }
        , viewCheckbox
            { title = "Reopened"
            , subtitle = Nothing
            , field = "allow_pull_reopened"
            , state = allowEvents.pull.reopened
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PullReopened }
            , disabled_ = False
            , id_ = "allow-events-pull-reopened"
            }
        , viewCheckbox
            { title = "Labeled"
            , subtitle = Nothing
            , field = "allow_pull_labeled"
            , state = allowEvents.pull.labeled
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PullLabeled }
            , disabled_ = False
            , id_ = "allow-events-pull-labeled"
            }
        , viewCheckbox
            { title = "Unlabeled"
            , subtitle = Nothing
            , field = "allow_pull_unlabeled"
            , state = allowEvents.pull.unlabeled
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PullUnlabeled }
            , disabled_ = False
            , id_ = "allow-events-pull-unlabeled"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Deployments" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Created"
            , subtitle = Nothing
            , field = "allow_deploy_created"
            , state = allowEvents.deploy.created
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.DeployCreated }
            , disabled_ = False
            , id_ = "allow-events-deploy-created"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Comment" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Created"
            , subtitle = Nothing
            , field = "allow_comment_created"
            , state = allowEvents.comment.created
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.CommentCreated }
            , disabled_ = False
            , id_ = "allow-events-comment-created"
            }
        , viewCheckbox
            { title = "Edited"
            , subtitle = Nothing
            , field = "allow_comment_edited"
            , state = allowEvents.comment.edited
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.CommentEdited }
            , disabled_ = False
            , id_ = "allow-events-comment-edited"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Delete" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Branch"
            , subtitle = Nothing
            , field = "allow_push_delete_branch"
            , state = allowEvents.push.deleteBranch
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PushDeleteBranch }
            , disabled_ = False
            , id_ = "allow-events-push-delete-branch"
            }
        , viewCheckbox
            { title = "Tag"
            , subtitle = Nothing
            , field = "allow_push_delete_tag"
            , state = allowEvents.push.deleteTag
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.PushDeleteTag }
            , disabled_ = False
            , id_ = "allow-events-push-delete-tag"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Schedule" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Schedule"
            , subtitle = Nothing
            , field = "allow_schedule_run"
            , state = allowEvents.schedule.run
            , wrapperClassList = []
            , msg = msg { allowEvents = allowEvents, event = Vela.ScheduleRun }
            , disabled_ = False
            , id_ = "allow-events-schedule-run"
            }
        ]
    ]


{-| EditableListProps : properties for the editable list component.
-}
type alias EditableListProps a b msg =
    { id_ : String
    , webdata : WebData a
    , toItems : a -> List b
    , toId : b -> String
    , toLabel : b -> String
    , addProps :
        Maybe
            { placeholder_ : String
            , addOnInputMsg : String -> msg
            , addOnClickMsg : String -> msg
            }
    , viewHttpError : Http.Error -> Html msg
    , viewNoItems : Html msg
    , form : EditableListForm
    , itemEditOnClickMsg : { id : String } -> msg
    , itemSaveOnClickMsg : { id : String, val : String } -> msg
    , itemEditOnInputMsg : { id : String } -> String -> msg
    , itemRemoveOnClickMsg : String -> msg
    }


{-| EditableListForm : form values for the editable list component.
-}
type alias EditableListForm =
    { val : String
    , editing : Dict String String
    }


{-| viewEditableList : renders an editable list component with optional add button header.
-}
viewEditableList : EditableListProps a b msg -> Html msg
viewEditableList props =
    let
        target =
            String.join "-" [ "editable-list", props.id_ ]
    in
    div []
        [ case props.addProps of
            Just addProps ->
                div [ class "form-controls" ]
                    [ viewInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = target ++ "-add"
                        , val = props.form.val
                        , placeholder_ = addProps.placeholder_
                        , classList_ = []
                        , wrapperClassList =
                            [ ( "-wide", True )
                            ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = addProps.addOnInputMsg
                        , disabled_ = False
                        , min = Nothing
                        , max = Nothing
                        , required = False
                        }
                    , viewButton
                        { id_ = target ++ "-add"
                        , msg = addProps.addOnClickMsg props.form.val
                        , text_ = "add"
                        , classList_ =
                            [ ( "-outline", True )
                            ]
                        , disabled_ =
                            (String.length props.form.val == 0)
                                || (not <| RemoteData.isSuccess props.webdata)
                        }
                    ]

            _ ->
                text ""
        , div
            [ class "editable-list"
            , Util.testAttribute target
            ]
            [ ul [] <|
                case props.webdata of
                    RemoteData.Success data ->
                        let
                            items =
                                props.toItems data
                        in
                        if List.isEmpty items then
                            [ li [ Util.testAttribute <| target ++ "-no-items" ]
                                [ props.viewNoItems ]
                            ]

                        else
                            List.map (viewEditableListItem props) items

                    RemoteData.Failure error ->
                        [ li []
                            [ span [ Util.testAttribute <| target ++ "-error" ]
                                [ props.viewHttpError error
                                ]
                            ]
                        ]

                    _ ->
                        [ li [] [ Components.Loading.viewSmallLoader ] ]
            ]
        ]


{-| viewEditableListItem : renders an item for the editable list component.
-}
viewEditableListItem : EditableListProps a b msg -> b -> Html msg
viewEditableListItem props item =
    let
        itemId =
            props.toId item

        target =
            String.join "-" [ "editable-list", "item", itemId ]

        editing =
            Maybe.Extra.unwrap Nothing (\e -> Just e) <| Dict.get itemId props.form.editing
    in
    li
        [ Util.testAttribute target
        ]
        [ case editing of
            Just val ->
                viewInput
                    { title = Nothing
                    , subtitle = Nothing
                    , id_ = target
                    , val = val
                    , placeholder_ = props.toLabel item
                    , wrapperClassList = []
                    , classList_ = []
                    , rows_ = Nothing
                    , wrap_ = Nothing
                    , msg = props.itemEditOnInputMsg { id = itemId }
                    , disabled_ = False
                    , min = Nothing
                    , max = Nothing
                    , required = False
                    }

            Nothing ->
                span [] [ text <| props.toLabel item ]
        , span []
            [ case editing of
                Just val ->
                    span []
                        [ button
                            [ class "remove-button"
                            , class "button"
                            , class "-icon"
                            , attribute "aria-label" <| "remove list item " ++ itemId
                            , onClick <| props.itemRemoveOnClickMsg <| itemId
                            , Util.testAttribute <| target ++ "-remove"
                            , id <| target ++ "-remove"
                            ]
                            [ FeatherIcons.minusSquare
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml []
                            ]
                        , button
                            [ class "save-button"
                            , class "button"
                            , class "-icon"
                            , attribute "aria-label" <| "save list item " ++ itemId
                            , onClick <| props.itemSaveOnClickMsg { id = itemId, val = val }
                            , Util.testAttribute <| target ++ "-save"
                            , id <| target ++ "-save"
                            ]
                            [ FeatherIcons.save
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml []
                            ]
                        ]

                _ ->
                    span []
                        [ button
                            [ class "edit-button"
                            , class "button"
                            , class "-icon"
                            , attribute "aria-label" <| "edit list item " ++ itemId
                            , onClick <| props.itemEditOnClickMsg { id = itemId }
                            , Util.testAttribute <| target ++ "-edit"
                            , id <| target ++ "-edit"
                            ]
                            [ FeatherIcons.edit2
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml []
                            ]
                        ]
            ]
        ]
